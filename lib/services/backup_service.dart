import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/encryption_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

const _storage = FlutterSecureStorage();
const _deviceIdKey = 'teacheros_device_id';

// ─── DEVICE BACKUP KEY ────────────────────────────────────────────────────────
Future<String> _getDeviceBackupKey() async {
  String? deviceId = await _storage.read(key: _deviceIdKey);
  if (deviceId == null) {
    deviceId = const Uuid().v4();
    await _storage.write(key: _deviceIdKey, value: deviceId);
  }
  return 'backup_$deviceId.db';
}

Future<bool> hasExistingBackup() async {
  final deviceId = await _storage.read(key: _deviceIdKey);
  return deviceId != null;
}

// ─── AUTO SYNC ────────────────────────────────────────────────────────────────
Future<void> autoSyncIfBackupExists() async {
  try {
    final exists = await hasExistingBackup();
    if (!exists) return;

    debugPrint('Auto-sync: backup detected, syncing to cloud...');
    final url = await exportAndGetUniqueLink();
    if (url != null) {
      debugPrint('Auto-sync: success → $url');
    } else {
      debugPrint('Auto-sync: failed silently (no internet?)');
    }
  } catch (e) {
    debugPrint('Auto-sync error (non-fatal): $e');
  }
}

// ─── EXPORT ──────────────────────────────────────────────────────────────────
// Strategy: decrypt to a plain temp file using Python-style ATTACH/export,
// but since that's unreliable, we use a pure Dart row-by-row copy instead.
Future<String?> exportAndGetUniqueLink() async {
  try {
    final dbDir = await getApplicationDocumentsDirectory();
    final exportPath = join(dbDir.path, 'teacher_os_export.db');

    // Clean up any leftover export file
    final exportFile = File(exportPath);
    if (await exportFile.exists()) await exportFile.delete();

    // ✅ Use the singleton — never open a second raw connection to the source
    final sourceDb = await DatabaseService.instance.database;

    // Open destination as plain SQLite
    final destDb = await openDatabase(exportPath, password: '', version: 1);

    // Get all table names from source
    final tables = await sourceDb.rawQuery(
      "SELECT name, sql FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_%'",
    );

    // Recreate schema and copy data table by table
    for (final table in tables) {
      final tableName = table['name'] as String;
      final createSql = table['sql'] as String;
      await destDb.execute(createSql);
      final rows = await sourceDb.query(tableName);
      for (final row in rows) {
        await destDb.insert(tableName, row);
      }
    }

    // ✅ Only close the DESTINATION — NEVER close the source singleton
    await destDb.close();

    if (!await exportFile.exists()) return null;

    // Upload plain file to Supabase
    final supabase = Supabase.instance.client;
    final fileName = await _getDeviceBackupKey();

    await supabase.storage
        .from('backups_teachos')
        .upload(
          fileName,
          exportFile,
          fileOptions: const FileOptions(upsert: true),
        );

    await exportFile.delete();

    return supabase.storage.from('backups_teachos').getPublicUrl(fileName);
  } catch (e) {
    debugPrint('Export failed: $e');
    return null;
  }
}

// ─── RESTORE ─────────────────────────────────────────────────────────────────
Future<bool> restoreDatabaseFromBytes(Uint8List downloadedBytes) async {
  try {
    final dbDir = await getApplicationDocumentsDirectory();
    final dbPath = join(dbDir.path, 'teacher_os.db');
    final tempPath = join(dbDir.path, 'teacher_os_plain_temp.db');
    final newEncPath = join(dbDir.path, 'teacher_os_new.db');

    // 1. Close the singleton
    await DatabaseService.instance.close();

    // 2. Write the downloaded plain SQLite to a temp file
    final tempFile = File(tempPath);
    await tempFile.writeAsBytes(downloadedBytes, flush: true);

    // 3. Clean up target paths
    final newEncFile = File(newEncPath);
    if (await newEncFile.exists()) await newEncFile.delete();

    // 4. Open the plain temp db
    final plainDb = await openDatabase(tempPath, password: '');

    // 5. Get this device's password and create a new encrypted db
    final password = await EncryptionService.getDatabasePassword();
    final encDb = await openDatabase(newEncPath, password: password);

    // 6. Copy schema and data from plain → encrypted
    final tables = await plainDb.rawQuery(
      "SELECT name, sql FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_%'",
    );

    for (final table in tables) {
      final tableName = table['name'] as String;
      final createSql = table['sql'] as String;

      await encDb.execute(createSql);

      final rows = await plainDb.query(tableName);
      for (final row in rows) {
        await encDb.insert(tableName, row);
      }
    }

    await encDb.execute('PRAGMA user_version = 2;');
    await plainDb.close();
    await encDb.close();

    // 7. Replace the real db with the new encrypted one
    await tempFile.delete();
    final dbFile = File(dbPath);
    if (await dbFile.exists()) await dbFile.delete();
    await newEncFile.rename(dbPath);

    // 8. Reinitialize
    await DatabaseService.instance.resetAndReinit();

    debugPrint('Database restored and re-encrypted successfully.');
    return true;
  } catch (e) {
    debugPrint('Critical failure during database restoration: $e');
    return false;
  }
}

// ─── IMPORT ──────────────────────────────────────────────────────────────────
Future<bool> importFromLink(String url) async {
  try {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      return await restoreDatabaseFromBytes(response.bodyBytes);
    }
    debugPrint('Download failed with status: ${response.statusCode}');
    return false;
  } catch (e) {
    debugPrint('Import failed: $e');
    return false;
  }
}
