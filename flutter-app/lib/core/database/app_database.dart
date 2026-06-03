import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tables/reports_table.dart';
import 'tables/sync_queue_table.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [LocalReports, SyncQueue])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // LocalReports DAOs
  Future<List<LocalReport>> getAllReports() => select(localReports).get();

  Future<LocalReport?> getReportByDate(DateTime date) {
    return (select(localReports)
          ..where((t) => t.reportDate.equals(date)))
        .getSingleOrNull();
  }

  Future<int> upsertReport(LocalReportsCompanion entry) =>
      into(localReports).insertOnConflictUpdate(entry);

  // SyncQueue DAOs
  Future<List<SyncQueueData>> getPendingSync() =>
      (select(syncQueue)..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();

  Future<int> enqueueSyncItem(SyncQueueCompanion entry) =>
      into(syncQueue).insert(entry);

  Future<void> deleteSyncItem(int id) =>
      (delete(syncQueue)..where((t) => t.id.equals(id))).go();

  Future<void> incrementSyncRetry(int id) async {
    final item = await (select(syncQueue)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (item != null) {
      await (update(syncQueue)..where((t) => t.id.equals(id)))
          .write(SyncQueueCompanion(retryCount: Value(item.retryCount + 1)));
    }
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'agent_report.db'));
    return NativeDatabase.createInBackground(file);
  });
}

final dbProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
