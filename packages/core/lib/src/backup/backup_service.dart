import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/wallet_cloud_service.dart';

/// Resultado de una operación de backup/restore.
sealed class BackupResult {
  const BackupResult();
}

class BackupSuccess extends BackupResult {
  final String filePath;
  final int sizeBytes;
  final int photosCount;
  final int prefsCount;
  const BackupSuccess({
    required this.filePath,
    required this.sizeBytes,
    this.photosCount = 0,
    this.prefsCount = 0,
  });
}

class BackupFailure extends BackupResult {
  final String message;
  const BackupFailure(this.message);
}

class RestoreSuccess extends BackupResult {
  final int tablesRestored;
  final int prefsRestored;
  final int photosRestored;
  const RestoreSuccess({
    required this.tablesRestored,
    this.prefsRestored = 0,
    this.photosRestored = 0,
  });
}

class CloudBackupOperationResult {
  final bool success;
  final String message;
  final bool hasConflict;
  final MyLifeOSCloudBackupMeta? serverBackup;
  final int sizeBytes;
  final int photosCount;

  const CloudBackupOperationResult({
    required this.success,
    required this.message,
    this.hasConflict = false,
    this.serverBackup,
    this.sizeBytes = 0,
    this.photosCount = 0,
  });
}

/// Cabecera del archivo de backup para validación de integridad (V1 y V2).
class BackupMetadata {
  static const schemaVersion = 16;
  static const fileExtension = '.mylifeos_backup';
  static const appId = 'com.mylifeos.personal';

  final int version;
  final String appId_;
  final DateTime createdAt;
  final int dbSizeBytes;
  final int schemaVersion_;
  final bool includesPhotos;
  final int photosCount;
  final int preferencesCount;

  const BackupMetadata({
    required this.version,
    required this.appId_,
    required this.createdAt,
    required this.dbSizeBytes,
    this.schemaVersion_ = schemaVersion,
    this.includesPhotos = false,
    this.photosCount = 0,
    this.preferencesCount = 0,
  });

  Map<String, dynamic> toJson() => {
        'version': version,
        'app_id': appId_,
        'created_at': createdAt.toIso8601String(),
        'db_size_bytes': dbSizeBytes,
        'schema_version': schemaVersion_,
        'includes_photos': includesPhotos,
        'photos_count': photosCount,
        'preferences_count': preferencesCount,
      };

  static BackupMetadata fromJson(Map<String, dynamic> json) => BackupMetadata(
        version: (json['version'] as num?)?.toInt() ?? 1,
        appId_: json['app_id'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        dbSizeBytes: (json['db_size_bytes'] as num).toInt(),
        schemaVersion_: (json['schema_version'] as num?)?.toInt() ?? 4,
        includesPhotos: json['includes_photos'] == true,
        photosCount: (json['photos_count'] as num?)?.toInt() ?? 0,
        preferencesCount: (json['preferences_count'] as num?)?.toInt() ?? 0,
      );
}

/// Servicio de backup/restore unificado V2 de MyLifeOS:
/// Empaqueta `mylifeos.sqlite` + `preferences.json` (perfil, metas, equivalencias,
/// precios, notificaciones, comidas guardadas, tema) + opcionalmente fotos del Armario/FoodCoach.
class BackupService {
  static const _lastBackupPrefKey = 'mylifeos_last_backup_at';
  static const _maxCloudPhotoTotalBytes = 28 * 1024 * 1024; // 28 MB seguro para Render

  static const Set<String> _excludedPrefKeys = {
    'mylifeos_cloud_device_id',
    'mylifeos_cloud_backup_updated_at',
    'mylifeos_cloud_backup_last_synced',
  };

  static const Set<String> _photoExtensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
  };

  final Future<Directory> Function() _getDocumentsDir;
  final Future<void> Function()? _checkpointDb;
  final Future<void> Function()? _closeDb;

  BackupService({
    Future<Directory> Function()? getDocumentsDirectoryFn,
    Future<void> Function()? checkpointDbFn,
    Future<void> Function()? closeDbFn,
  })  : _getDocumentsDir =
            getDocumentsDirectoryFn ?? getApplicationDocumentsDirectory,
        _checkpointDb = checkpointDbFn,
        _closeDb = closeDbFn;

  /// Construye el paquete ZIP V2 completo en memoria.
  Future<
      ({
        Uint8List bytes,
        BackupMetadata metadata,
        int photosCount,
        int prefsCount,
      })> buildBackupPackageBytes({
    bool includePhotos = false,
    int? maxPhotoTotalBytes,
  }) async {
    if (_checkpointDb != null) {
      await _checkpointDb();
    }
    final dbFile = await _getDbFile();
    if (!dbFile.existsSync()) {
      throw StateError('No se encontró la base de datos.');
    }

    final dbBytes = await dbFile.readAsBytes();
    final archive = Archive();
    archive.addFile(ArchiveFile('mylifeos.sqlite', dbBytes.length, dbBytes));

    // Exportar preferencias no sensibles de SharedPreferences
    final prefsExport = await _exportPreferencesMap();
    final prefsBytes = utf8.encode(jsonEncode(prefsExport));
    archive.addFile(
      ArchiveFile('preferences.json', prefsBytes.length, prefsBytes),
    );

    // Exportar fotos del directorio de documentos (Armario, FoodCoach, etc.) si se solicita
    int photosCount = 0;
    if (includePhotos) {
      final docsDir = await _getDocumentsDir();
      int accumulated = 0;
      final cap = maxPhotoTotalBytes ?? _maxCloudPhotoTotalBytes;
      if (docsDir.existsSync()) {
        await for (final entity
            in docsDir.list(recursive: true, followLinks: false)) {
          if (entity is! File) continue;
          final ext = p.extension(entity.path).toLowerCase();
          if (!_photoExtensions.contains(ext)) continue;
          final rel = p
              .relative(entity.path, from: docsDir.path)
              .replaceAll('\\', '/');
          if (rel.startsWith('auto_backups/') || rel.contains('..')) continue;
          final stat = await entity.stat();
          if (stat.size <= 0) continue;
          if (accumulated + stat.size > cap) continue;
          final fileBytes = await entity.readAsBytes();
          archive.addFile(
            ArchiveFile('photos/$rel', fileBytes.length, fileBytes),
          );
          accumulated += fileBytes.length;
          photosCount++;
        }
      }
    }

    final ts = DateTime.now();
    final metadata = BackupMetadata(
      version: 2,
      appId_: BackupMetadata.appId,
      createdAt: ts,
      dbSizeBytes: dbBytes.length,
      schemaVersion_: BackupMetadata.schemaVersion,
      includesPhotos: includePhotos && photosCount > 0,
      photosCount: photosCount,
      preferencesCount: prefsExport.length,
    );
    final metaBytes = utf8.encode(jsonEncode(metadata.toJson()));
    archive.addFile(ArchiveFile('metadata.json', metaBytes.length, metaBytes));

    final encoded = ZipEncoder().encode(archive);
    return (
      bytes: Uint8List.fromList(encoded),
      metadata: metadata,
      photosCount: photosCount,
      prefsCount: prefsExport.length,
    );
  }

  /// Restaura un paquete ZIP V1 o V2 desde memoria.
  Future<BackupResult> restoreFromPackageBytes(List<int> zipBytes) async {
    try {
      final archive = ZipDecoder().decodeBytes(zipBytes);

      final metaEntry = archive.findFile('metadata.json');
      final dbEntry = archive.findFile('mylifeos.sqlite');

      if (metaEntry == null || dbEntry == null) {
        return const BackupFailure(
          'Archivo de backup inválido: faltan componentes internos.',
        );
      }

      final metaJson = jsonDecode(utf8.decode(metaEntry.content as List<int>))
          as Map<String, dynamic>;
      final meta = BackupMetadata.fromJson(metaJson);

      if (meta.appId_ != BackupMetadata.appId) {
        return const BackupFailure(
          'Este backup no pertenece a MyLifeOS. No se puede restaurar.',
        );
      }

      if (meta.schemaVersion_ > BackupMetadata.schemaVersion) {
        return BackupFailure(
          'Este backup requiere una versión más reciente (schema v${meta.schemaVersion_}).',
        );
      }

      final dbBytes = dbEntry.content as List<int>;
      if (dbBytes.length != meta.dbSizeBytes) {
        return const BackupFailure(
          'El archivo de backup está corrupto (tamaño de DB no coincide).',
        );
      }

      // Cerrar DB abierta y limpiar archivos WAL/SHM antes de reemplazar
      if (_closeDb != null) {
        await _closeDb();
      }
      final dbFile = await _getDbFile();
      for (final suffix in ['-wal', '-shm']) {
        final sidecar = File('${dbFile.path}$suffix');
        if (sidecar.existsSync()) {
          await sidecar.delete();
        }
      }

      await dbFile.writeAsBytes(dbBytes, flush: true);

      // Restaurar preferencias V2 si vienen incluidas
      int prefsRestored = 0;
      final prefsEntry = archive.findFile('preferences.json');
      if (prefsEntry != null) {
        try {
          final decoded =
              jsonDecode(utf8.decode(prefsEntry.content as List<int>));
          if (decoded is Map<String, dynamic>) {
            prefsRestored = await _restorePreferencesMap(decoded);
          }
        } catch (_) {}
      }

      // Restaurar fotos V2 si vienen incluidas
      int photosRestored = 0;
      final docsDir = await _getDocumentsDir();
      for (final entry in archive.files) {
        if (!entry.isFile) continue;
        final name = entry.name.replaceAll('\\', '/');
        if (!name.startsWith('photos/')) continue;
        final rel = name.substring('photos/'.length);
        if (rel.isEmpty || rel.contains('..') || rel.startsWith('/')) continue;
        final outFile = File(p.join(docsDir.path, rel));
        await outFile.parent.create(recursive: true);
        await outFile.writeAsBytes(entry.content as List<int>, flush: true);
        photosRestored++;
      }

      return RestoreSuccess(
        tablesRestored: meta.schemaVersion_,
        prefsRestored: prefsRestored,
        photosRestored: photosRestored,
      );
    } catch (e) {
      return BackupFailure('Error al restaurar: $e');
    }
  }

  // ── Exportar archivo local y compartir ────────────────────────────────────
  Future<BackupResult> exportBackup({bool includePhotos = false}) async {
    try {
      final pkg = await buildBackupPackageBytes(
        includePhotos: includePhotos,
        maxPhotoTotalBytes: 80 * 1024 * 1024,
      );
      final ts = pkg.metadata.createdAt;
      final tempDir = await getTemporaryDirectory();
      final filename =
          'mylifeos_backup_${ts.year}${_pad(ts.month)}${_pad(ts.day)}_${_pad(ts.hour)}${_pad(ts.minute)}${BackupMetadata.fileExtension}';
      final backupFile = File(p.join(tempDir.path, filename));
      await backupFile.writeAsBytes(pkg.bytes);

      await _recordLastBackupDate(ts);

      await Share.shareXFiles(
        [XFile(backupFile.path, mimeType: 'application/zip')],
        subject: 'Backup de MyLifeOS',
        text: 'Backup creado el ${ts.day}/${ts.month}/${ts.year}',
      );

      return BackupSuccess(
        filePath: backupFile.path,
        sizeBytes: pkg.bytes.length,
        photosCount: pkg.photosCount,
        prefsCount: pkg.prefsCount,
      );
    } catch (e) {
      return BackupFailure('Error al exportar: $e');
    }
  }

  /// Guarda una copia automática local persistente (mantiene las últimas 3).
  Future<BackupResult> saveLocalAutoBackup({bool includePhotos = false}) async {
    try {
      final pkg = await buildBackupPackageBytes(includePhotos: includePhotos);
      final docsDir = await _getDocumentsDir();
      final autoDir = Directory(p.join(docsDir.path, 'auto_backups'));
      if (!autoDir.existsSync()) {
        await autoDir.create(recursive: true);
      }
      final ts = pkg.metadata.createdAt;
      final filename =
          'mylifeos_auto_${ts.year}${_pad(ts.month)}${_pad(ts.day)}_${_pad(ts.hour)}${_pad(ts.minute)}${BackupMetadata.fileExtension}';
      final outFile = File(p.join(autoDir.path, filename));
      await outFile.writeAsBytes(pkg.bytes, flush: true);

      // Rotación: conservar solo las 3 copias locales automáticas más recientes
      final existing = autoDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith(BackupMetadata.fileExtension))
          .toList()
        ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      if (existing.length > 3) {
        for (final old in existing.sublist(3)) {
          try {
            await old.delete();
          } catch (_) {}
        }
      }

      await _recordLastBackupDate(ts);
      return BackupSuccess(
        filePath: outFile.path,
        sizeBytes: pkg.bytes.length,
        photosCount: pkg.photosCount,
        prefsCount: pkg.prefsCount,
      );
    } catch (e) {
      return BackupFailure('Error guardando copia local: $e');
    }
  }

  // ── Importar desde archivo local ──────────────────────────────────────────
  Future<BackupResult> importBackup(String backupFilePath) async {
    try {
      final backupFile = File(backupFilePath);
      if (!backupFile.existsSync()) {
        return const BackupFailure('El archivo de backup no existe.');
      }
      final zipBytes = await backupFile.readAsBytes();
      return restoreFromPackageBytes(zipBytes);
    } catch (e) {
      return BackupFailure('Error al importar: $e');
    }
  }

  // ── Backup en la Nube (Cuenta del Ecosistema) ─────────────────────────────
  Future<CloudBackupOperationResult> uploadToCloud({
    bool includePhotos = false,
    bool force = false,
  }) async {
    try {
      final pkg = await buildBackupPackageBytes(
        includePhotos: includePhotos,
        maxPhotoTotalBytes: _maxCloudPhotoTotalBytes,
      );
      final res = await WalletCloudService.uploadMyLifeOSBackup(
        zipBytes: pkg.bytes,
        schemaVersion: pkg.metadata.schemaVersion_,
        includesPhotos: pkg.metadata.includesPhotos,
        force: force,
      );
      if (res.success) {
        await _recordLastBackupDate(DateTime.now());
      }
      return CloudBackupOperationResult(
        success: res.success,
        message: res.message,
        hasConflict: res.hasConflict,
        serverBackup: res.serverBackup,
        sizeBytes: pkg.bytes.length,
        photosCount: pkg.photosCount,
      );
    } catch (e) {
      return CloudBackupOperationResult(
        success: false,
        message: 'Error empaquetando copia para la nube: $e',
      );
    }
  }

  Future<BackupResult> restoreFromCloud() async {
    final dl = await WalletCloudService.downloadMyLifeOSBackup();
    if (!dl.success || dl.zipBytes == null) {
      return BackupFailure(dl.message);
    }
    return restoreFromPackageBytes(dl.zipBytes!);
  }

  // ── Utilidades ────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> _exportPreferencesMap() async {
    final result = <String, dynamic>{};
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys()) {
        if (_excludedPrefKeys.contains(key)) continue;
        final val = prefs.get(key);
        if (val is String) {
          result[key] = {'t': 's', 'v': val};
        } else if (val is int) {
          result[key] = {'t': 'i', 'v': val};
        } else if (val is double) {
          result[key] = {'t': 'd', 'v': val};
        } else if (val is bool) {
          result[key] = {'t': 'b', 'v': val};
        } else if (val is List<String>) {
          result[key] = {'t': 'sl', 'v': val};
        }
      }
    } catch (_) {}
    return result;
  }

  Future<int> _restorePreferencesMap(Map<String, dynamic> map) async {
    final prefs = await SharedPreferences.getInstance();
    int restored = 0;
    for (final entry in map.entries) {
      if (_excludedPrefKeys.contains(entry.key)) continue;
      final item = entry.value;
      if (item is! Map) continue;
      final type = item['t'];
      final val = item['v'];
      if (type == 's' && val is String) {
        await prefs.setString(entry.key, val);
        restored++;
      } else if (type == 'i' && val is num) {
        await prefs.setInt(entry.key, val.toInt());
        restored++;
      } else if (type == 'd' && val is num) {
        await prefs.setDouble(entry.key, val.toDouble());
        restored++;
      } else if (type == 'b' && val is bool) {
        await prefs.setBool(entry.key, val);
        restored++;
      } else if (type == 'sl' && val is List) {
        await prefs.setStringList(
          entry.key,
          val.map((e) => e.toString()).toList(),
        );
        restored++;
      }
    }
    return restored;
  }

  Future<File> _getDbFile() async {
    final dir = await _getDocumentsDir();
    return File(p.join(dir.path, 'mylifeos.sqlite'));
  }

  Future<int> getDbSizeBytes() async {
    final file = await _getDbFile();
    return file.existsSync() ? file.lengthSync() : 0;
  }

  Future<void> _recordLastBackupDate(DateTime date) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastBackupPrefKey, date.toIso8601String());
    } catch (_) {}
  }

  Future<DateTime?> getLastBackupDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final iso = prefs.getString(_lastBackupPrefKey);
      if (iso != null) {
        final parsed = DateTime.tryParse(iso);
        if (parsed != null) return parsed;
      }
    } catch (_) {}
    return null;
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
}
