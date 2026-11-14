import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Resultado de una operación de backup/restore.
sealed class BackupResult {
  const BackupResult();
}

class BackupSuccess extends BackupResult {
  final String filePath;
  final int sizeBytes;
  const BackupSuccess({required this.filePath, required this.sizeBytes});
}

class BackupFailure extends BackupResult {
  final String message;
  const BackupFailure(this.message);
}

class RestoreSuccess extends BackupResult {
  final int tablesRestored;
  const RestoreSuccess({required this.tablesRestored});
}

/// Cabecera del archivo de backup para validación de integridad.
class BackupMetadata {
  static const schemaVersion = 16;
  static const fileExtension = '.mylifeos_backup';
  static const appId = 'com.mylifeos.personal';

  final int version;
  final String appId_;
  final DateTime createdAt;
  final int dbSizeBytes;
  final int schemaVersion_;

  const BackupMetadata({
    required this.version,
    required this.appId_,
    required this.createdAt,
    required this.dbSizeBytes,
    this.schemaVersion_ = schemaVersion,
  });

  Map<String, dynamic> toJson() => {
        'version': version,
        'app_id': appId_,
        'created_at': createdAt.toIso8601String(),
        'db_size_bytes': dbSizeBytes,
        'schema_version': schemaVersion_,
      };

  static BackupMetadata fromJson(Map<String, dynamic> json) => BackupMetadata(
        version: (json['version'] as num?)?.toInt() ?? 1,
        appId_: json['app_id'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        dbSizeBytes: (json['db_size_bytes'] as num).toInt(),
        schemaVersion_: (json['schema_version'] as num?)?.toInt() ?? 4,
      );
}

/// Servicio de backup/restore de la base de datos SQLite.
/// Empaqueta el archivo .sqlite en un zip con metadatos para validar integridad.
class BackupService {
  static const _lastBackupPrefKey = 'mylifeos_last_backup_at';

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

  // ── Exportar ─────────────────────────────────────────────────────────────────
  Future<BackupResult> exportBackup() async {
    try {
      if (_checkpointDb != null) {
        await _checkpointDb();
      }
      final dbFile = await _getDbFile();
      if (!dbFile.existsSync()) {
        return const BackupFailure('No se encontró la base de datos.');
      }

      final dbBytes = await dbFile.readAsBytes();
      final ts = DateTime.now();
      final metadata = BackupMetadata(
        version: 1,
        appId_: BackupMetadata.appId,
        createdAt: ts,
        dbSizeBytes: dbBytes.length,
        schemaVersion_: BackupMetadata.schemaVersion,
      );

      // Buildear archivo zip en memoria
      final archive = Archive();
      archive.addFile(ArchiveFile(
        'mylifeos.sqlite',
        dbBytes.length,
        dbBytes,
      ));
      final metaBytes = utf8.encode(jsonEncode(metadata.toJson()));
      archive
          .addFile(ArchiveFile('metadata.json', metaBytes.length, metaBytes));

      final zipEncoder = ZipEncoder();
      final zipBytes = zipEncoder.encode(archive);

      // Guardar a disco temporalmente
      final tempDir = await getTemporaryDirectory();
      final filename =
          'mylifeos_backup_${ts.year}${_pad(ts.month)}${_pad(ts.day)}_${_pad(ts.hour)}${_pad(ts.minute)}${BackupMetadata.fileExtension}';
      final backupFile = File(p.join(tempDir.path, filename));
      await backupFile.writeAsBytes(zipBytes);

      await _recordLastBackupDate(ts);

      // Compartir vía share sheet
      await Share.shareXFiles(
        [XFile(backupFile.path, mimeType: 'application/zip')],
        subject: 'Backup de MyLifeOS',
        text: 'Backup creado el ${ts.day}/${ts.month}/${ts.year}',
      );

      return BackupSuccess(
        filePath: backupFile.path,
        sizeBytes: zipBytes.length,
      );
    } catch (e) {
      return BackupFailure('Error al exportar: $e');
    }
  }

  // ── Importar ─────────────────────────────────────────────────────────────────
  Future<BackupResult> importBackup(String backupFilePath) async {
    try {
      final backupFile = File(backupFilePath);
      if (!backupFile.existsSync()) {
        return const BackupFailure('El archivo de backup no existe.');
      }

      final zipBytes = await backupFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(zipBytes);

      // Validar que el archivo tiene los dos componentes esperados
      final metaEntry = archive.findFile('metadata.json');
      final dbEntry = archive.findFile('mylifeos.sqlite');

      if (metaEntry == null || dbEntry == null) {
        return const BackupFailure(
            'Archivo de backup inválido: faltan componentes internos.');
      }

      // Validar metadatos
      final metaJson = jsonDecode(utf8.decode(metaEntry.content as List<int>))
          as Map<String, dynamic>;
      final meta = BackupMetadata.fromJson(metaJson);

      if (meta.appId_ != BackupMetadata.appId) {
        return const BackupFailure(
            'Este backup no pertenece a MyLifeOS. No se puede restaurar.');
      }

      if (meta.schemaVersion_ > BackupMetadata.schemaVersion) {
        return BackupFailure(
            'Este backup requiere una versión más reciente (schema v${meta.schemaVersion_}).');
      }

      final dbBytes = dbEntry.content as List<int>;
      if (dbBytes.length != meta.dbSizeBytes) {
        return const BackupFailure(
            'El archivo de backup está corrupto (tamaño de DB no coincide).');
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

      // Reemplazar la base de datos actual con la del backup
      await dbFile.writeAsBytes(dbBytes, flush: true);

      return RestoreSuccess(tablesRestored: meta.schemaVersion_);
    } catch (e) {
      return BackupFailure('Error al importar: $e');
    }
  }

  // ── Utilidades ────────────────────────────────────────────────────────────────
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
