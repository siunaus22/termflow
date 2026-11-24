import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../providers/app_providers.dart';

/// Google Material You 胶囊风格云端同步指示器
class SyncIndicator extends ConsumerWidget {
  const SyncIndicator({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncControllerProvider);
    final authState = ref.watch(supabaseManagerProvider);
    final pendingCount = ref.watch(pendingChangeCountProvider).valueOrNull ?? 0;

    final Color accentColor;
    final IconData statusIcon;
    final String label;

    if (!authState.isLoggedIn) {
      accentColor = pendingCount > 0 ? AppTheme.googleBlue : AppTheme.googleTeal;
      statusIcon = Icons.cloud_off_rounded;
      label = pendingCount > 0 ? '本地离线 ($pendingCount)' : '离线就绪';
    } else {
      switch (syncState.phase) {
        case SyncUiPhase.syncing:
          accentColor = AppTheme.googleYellow;
          statusIcon = Icons.sync_rounded;
          label = '正在云端同步...';
        case SyncUiPhase.error:
          accentColor = AppTheme.googleRed;
          statusIcon = Icons.error_outline_rounded;
          label = '同步失败 · 点此重试';
        case SyncUiPhase.success:
        case SyncUiPhase.idle:
          accentColor =
              pendingCount > 0 ? AppTheme.googleYellow : AppTheme.googleGreen;
          statusIcon = pendingCount > 0
              ? Icons.cloud_upload_outlined
              : Icons.cloud_done_rounded;
          label = pendingCount > 0 ? '$pendingCount 项待上传' : '云端实时已同步';
        case SyncUiPhase.offline:
          accentColor = AppTheme.googleTeal;
          statusIcon = Icons.cloud_off_rounded;
          label = '离线就绪';
      }
    }

    if (compact) {
      return Tooltip(
        message: syncState.errorMessage ?? syncState.lastSummary ?? label,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: syncState.phase == SyncUiPhase.syncing
                ? null
                : () => ref.read(syncControllerProvider.notifier).syncNow(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: accentColor.withAlpha(28),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (syncState.phase == SyncUiPhase.syncing)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: accentColor,
                      ),
                    )
                  else
                    Icon(statusIcon, size: 16, color: accentColor),
                  if (pendingCount > 0) ...[
                    const SizedBox(width: 4),
                    Text(
                      '$pendingCount',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: accentColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Material(
      color: AppTheme.tonalContainer(context, accentColor, lightAlpha: 28),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: syncState.phase == SyncUiPhase.syncing
            ? null
            : () => ref.read(syncControllerProvider.notifier).syncNow(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              if (syncState.phase == SyncUiPhase.syncing)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: accentColor,
                  ),
                )
              else
                Icon(statusIcon, size: 18, color: accentColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: accentColor,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.refresh_rounded, size: 16, color: accentColor),
            ],
          ),
        ),
      ),
    );
  }
}
