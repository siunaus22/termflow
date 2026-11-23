import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// 监听 Supabase Realtime 数据变更，防抖后自动触发双向增量同步
class RealtimeSyncListener {
  RealtimeSyncListener({required this.onRemoteChange});

  final Future<void> Function() onRemoteChange;

  RealtimeChannel? _channel;
  Timer? _debounce;

  static const _tables = [
    'semesters',
    'goals',
    'tasks',
    'tags',
    'task_tags',
  ];

  void start(SupabaseClient client, String userId) {
    stop(client);

    final channel = client.channel('termflow_sync_$userId');
    for (final table in _tables) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: userId,
        ),
        callback: (_) => _scheduleSync(),
      );
    }

    channel.subscribe();
    _channel = channel;
  }

  void _scheduleSync() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () {
      onRemoteChange();
    });
  }

  Future<void> stop(SupabaseClient? client) async {
    _debounce?.cancel();
    _debounce = null;
    if (_channel != null && client != null) {
      await client.removeChannel(_channel!);
    }
    _channel = null;
  }

  void dispose(SupabaseClient? client) {
    stop(client);
  }
}
