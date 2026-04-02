import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

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
  static const schemaVersion = 4;
  static const fileExtension = '.mylifeos_backup';
  static const appId = 'com.mylifeos.personal';

  final int version;
  final String appId_;
  final DateTime createdAt;
  final int dbSizeBytes;

  const BackupMetadata({
    required this.version,
    required this.appId_,
    required this.createdAt,
    required this.dbSizeBytes,
  });

  Map<String, dynamic> toJson() => {
        'version': version,
        'app_id': appId_,
        'created_at': createdAt.toIso8601String(),
        'db_size_bytes': dbSizeBytes,
        'schema_version': schemaVersion,
      };

  static BackupMetadata fromJson(Map<String, dynamic> json) => BackupMetadata(
        version: json['version'] as int,
        appId_: json['app_id'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        dbSizeBytes: json['db_size_bytes'] as int,
      );
}

/// Servicio de backup/restore de la base de datos SQLite.
/// Empaqueta el archivo .sqlite en un zip con metadatos para validar integridad.
class BackupService {
  // ── Exportar ─────────────────────────────────────────────────────────────────
  Future<BackupResult> exportBackup() async {
    try {
      final dbFile = await _getDbFile();
      if (!dbFile.existsSync()) {
        return const BackupFailure('No se encontró la base de datos.');
      }

      final dbBytes = await dbFile.readAsBytes();
      final metadata = BackupMetadata(
        version: 1,
        appId_: BackupMetadata.appId,
        createdAt: DateTime.now(),
        dbSizeBytes: dbBytes.length,
      );

      // Buildear archivo zip en memoria
      final archive = Archive();
      archive.addFile(ArchiveFile(
        'mylifeos.sqlite',
        dbBytes.length,
        dbBytes,
      ));
      final metaBytes =
          utf8.encode(jsonEncode(metadata.toJson()));
      archive.addFile(ArchiveFile('metadata.json', metaBytes.length, metaBytes));

      final zipEncoder = ZipEncoder();
      final zipBytes = zipEncoder.encode(archive);
      if (zipBytes == null) {
        return const BackupFailure('Error al comprimir el backup.');
      }

      // Guardar a disco temporalmente
      final tempDir = await getTemporaryDirectory();
      final ts = DateTime.now();
      final filename =
          'mylifeos_backup_${ts.year}${_pad(ts.month)}${_pad(ts.day)}_${_pad(ts.hour)}${_pad(ts.minute)}${BackupMetadata.fileExtension}';
      final backupFile = File(p.join(tempDir.path, filename));
      await backupFile.writeAsBytes(zipBytes);

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
      final metaJson =
          jsonDecode(utf8.decode(metaEntry.content as List<int>))
              as Map<String, dynamic>;
      final meta = BackupMetadata.fromJson(metaJson);

      if (meta.appId_ != BackupMetadata.appId) {
        return const BackupFailure(
            'Este backup no pertenece a MyLifeOS. No se puede restaurar.');
      }

      final dbBytes = dbEntry.content as List<int>;
      if (dbBytes.length != meta.dbSizeBytes) {
        return const BackupFailure(
            'El archivo de backup está corrupto (tamaño de DB no coincide).');
      }

      // Reemplazar la base de datos actual con la del backup
      final dbFile = await _getDbFile();
      await dbFile.writeAsBytes(dbBytes);

      return const RestoreSuccess(tablesRestored: BackupMetadata.schemaVersion);
    } catch (e) {
      return BackupFailure('Error al importar: $e');
    }
  }

  // ── Utilidades ────────────────────────────────────────────────────────────────
  Future<File> _getDbFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, 'mylifeos.sqlite'));
  }

  Future<int> getDbSizeBytes() async {
    final file = await _getDbFile();
    return file.existsSync() ? file.lengthSync() : 0;
  }

  Future<DateTime?> getLastBackupDate() async {
    // Simple heurística: Fecha de modificación del archivo de DB
    final file = await _getDbFile();
    if (!file.existsSync()) return null;
    return file.lastModifiedSync();
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
}
