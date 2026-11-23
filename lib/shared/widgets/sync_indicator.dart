import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';

/// 同步状态指示灯 + 待推送角标 + 点击立即同步
class SyncIndicator extends ConsumerWidget {
  const SyncIndicator({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncControllerProvider);
    final authState = ref.watch(supabaseManagerProvider);
    final pendingCount = ref.watch(pendingChangeCountProvider).valueOrNull ?? 0;

    final Color dotColor;
    final String label;
    if (!authState.isLoggedIn) {
      dotColor = Colors.grey;
      label = pendingCount > 0 ? '离线 ($pendingCount 待同步)' : '离线模式';
    } else {
      switch (syncState.phase) {
        case SyncUiPhase.syncing:
          dotColor = Colors.amber;
          label = '同步中...';
        case SyncUiPhase.error:
          dotColor = Colors.redAccent;
          label = '同步失败，点击重试';
        case SyncUiPhase.success:
        case SyncUiPhase.idle:
          dotColor = pendingCount > 0 ? Colors.orange : Colors.green;
          label = pendingCount > 0 ? '$pendingCount 项待上传' : '云端已同步';
        case SyncUiPhase.offline:
          dotColor = Colors.grey;
          label = '离线模式';
      }
    }

    if (compact) {
      return Tooltip(
        message: syncState.errorMessage ?? syncState.lastSummary ?? label,
        child: IconButton(
          onPressed: syncState.phase == SyncUiPhase.syncing
              ? null
              : () => ref.read(syncControllerProvider.notifier).syncNow(),
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              syncState.phase == SyncUiPhase.syncing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_sync_outlined, size: 22),
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: syncState.phase == SyncUiPhase.syncing
          ? null
          : () => ref.read(syncControllerProvider.notifier).syncNow(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          children: [
            if (syncState.phase == SyncUiPhase.syncing)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.refresh_rounded, size: 16),
          ],
        ),
      ),
    );
  }
}
