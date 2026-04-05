import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BackupService', () {
    late BackupService backupService;

    setUp(() {
      backupService = BackupService();
    });

    group('BackupMetadata', () {
      test('should serialize and deserialize metadata correctly', () {
        final metadata = BackupMetadata(
          version: 1,
          appId_: BackupMetadata.appId,
          createdAt: DateTime(2026, 4, 5, 10, 30),
          dbSizeBytes: 1024,
        );

        final json = metadata.toJson();
        final restored = BackupMetadata.fromJson(json);

        expect(restored.version, metadata.version);
        expect(restored.appId_, metadata.appId_);
        expect(restored.createdAt, metadata.createdAt);
        expect(restored.dbSizeBytes, metadata.dbSizeBytes);
      });

      test('should have correct schema version', () {
        expect(BackupMetadata.schemaVersion, 4);
      });

      test('should have correct app id', () {
        expect(BackupMetadata.appId, 'com.mylifeos.personal');
      });

      test('should have correct file extension', () {
        expect(BackupMetadata.fileExtension, '.mylifeos_backup');
      });
    });

    group('exportBackup', () {
      test('should return failure when database file does not exist', () async {
        // This test will fail because the DB doesn't exist in test environment
        final result = await backupService.exportBackup();
        expect(result, isA<BackupFailure>());
      });
    });

    group('importBackup', () {
      test('should return failure when backup file does not exist', () async {
        final result =
            await backupService.importBackup('/nonexistent/file.zip');
        expect(result, isA<BackupFailure>());
      });

      test('should return failure for invalid backup file', () async {
        // Create a temporary invalid file
        final tempFile =
            File('${Directory.systemTemp.path}/invalid_backup.zip');
        await tempFile.writeAsBytes([1, 2, 3, 4, 5]);

        final result = await backupService.importBackup(tempFile.path);
        expect(result, isA<BackupFailure>());

        // Cleanup
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      });
    });

    group('utility methods', () {
      test('getDbSizeBytes should return 0 when database does not exist',
          () async {
        final size = await backupService.getDbSizeBytes();
        expect(size, 0);
      });

      test('getLastBackupDate should return null when database does not exist',
          () async {
        final date = await backupService.getLastBackupDate();
        expect(date, isNull);
      });
    });
  });

  group('BackupResult types', () {
    test('BackupSuccess should hold file path and size', () {
      const success =
          BackupSuccess(filePath: '/path/to/backup.zip', sizeBytes: 1024);
      expect(success.filePath, '/path/to/backup.zip');
      expect(success.sizeBytes, 1024);
    });

    test('BackupFailure should hold error message', () {
      const failure = BackupFailure('Test error message');
      expect(failure.message, 'Test error message');
    });

    test('RestoreSuccess should hold tables restored count', () {
      const success = RestoreSuccess(tablesRestored: 4);
      expect(success.tablesRestored, 4);
    });
  });
}
