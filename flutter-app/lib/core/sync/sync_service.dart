import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../network/api_client.dart';

class SyncService {
  final AppDatabase _db;
  final ApiClient _api;

  SyncService(this._db, this._api);

  Future<void> enqueue(String endpoint, Map<String, dynamic> payload) async {
    await _db.enqueueSyncItem(SyncQueueCompanion.insert(
      endpoint: endpoint,
      payload: jsonEncode(payload),
    ));
  }

  Future<void> processPendingQueue() async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) return;

    final pending = await _db.getPendingSync();
    for (final item in pending) {
      try {
        final payload = jsonDecode(item.payload) as Map<String, dynamic>;
        await _api.submitReport(payload); // endpoint별 분기 필요 시 확장
        await _db.deleteSyncItem(item.id);
      } catch (_) {
        // Exponential backoff: 최대 5회 재시도
        if (item.retryCount < 5) {
          await _db.incrementSyncRetry(item.id);
        } else {
          await _db.deleteSyncItem(item.id); // 포기
        }
      }
    }
  }
}

final syncServiceProvider = Provider<SyncService>((ref) {
  final db = ref.watch(dbProvider);
  final api = ref.watch(apiClientProvider);
  return SyncService(db, api);
});
