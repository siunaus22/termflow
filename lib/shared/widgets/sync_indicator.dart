import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/gemini_tokens.dart';
import '../providers/app_providers.dart';
import 'gemini_components.dart';

/// Gemini 毛玻璃胶囊同步状态指示器（同步时触发四角星芒旋转微动效）
class SyncIndicator extends ConsumerWidget {
  const SyncIndicator({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncControllerProvider);
    final authState = ref.watch(supabaseManagerProvider);
    final pendingCount = ref.watch(pendingChangeCountProvider).valueOrNull ?? 0;
    final tokens = GeminiTokens.of(context);

    final bool isSyncing = syncState.phase == SyncUiPhase.syncing;
    final Color statusColor;
    final IconData statusIcon;
    final String label;

    if (!authState.isLoggedIn) {
      statusColor = tokens.textSecondary;
      statusIcon = Icons.cloud_off_outlined;
      label = pendingCount > 0 ? '离线缓存 ($pendingCount)' : '离线就绪';
    } else {
      switch (syncState.phase) {
        case SyncUiPhase.syncing:
          statusColor = GeminiTokens.cobaltViolet;
          statusIcon = Icons.sync_rounded;
          label = '云端同步中...';
        case SyncUiPhase.error:
          statusColor = GeminiTokens.roseAccent;
          statusIcon = Icons.error_outline_rounded;
          label = '同步异常 · 点此重试';
        case SyncUiPhase.success:
        case SyncUiPhase.idle:
          statusColor = pendingCount > 0
              ? GeminiTokens.cyanAccent
              : GeminiTokens.mintSuccess;
          statusIcon = pendingCount > 0
              ? Icons.cloud_upload_outlined
              : Icons.cloud_done_outlined;
          label = pendingCount > 0 ? '$pendingCount 项待同步' : '云端已同步';
        case SyncUiPhase.offline:
          statusColor = tokens.textSecondary;
          statusIcon = Icons.cloud_off_outlined;
          label = '离线就绪';
      }
    }

    if (compact) {
      return Tooltip(
        message: syncState.errorMessage ?? syncState.lastSummary ?? label,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: isSyncing
              ? null
              : () => ref.read(syncControllerProvider.notifier).syncNow(),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: tokens.glassPill,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isSyncing
                    ? tokens.glassHighlightBorder
                    : tokens.glassBorder,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSyncing)
                  const GeminiSparkleIcon(size: 15, spin: true, animate: true)
                else
                  Icon(statusIcon, size: 16, color: statusColor),
                if (pendingCount > 0) ...[
                  const SizedBox(width: 5),
                  Text(
                    '$pendingCount',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return GeminiGlassCard(
      borderRadius: BorderRadius.circular(999),
      blurSigma: 18,
      isHighlighted: isSyncing,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      onTap: isSyncing
          ? null
          : () => ref.read(syncControllerProvider.notifier).syncNow(),
      child: Row(
        children: [
          if (isSyncing)
            const GeminiSparkleIcon(size: 17, spin: true, animate: true)
          else
            Icon(statusIcon, size: 18, color: statusColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: tokens.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(
            Icons.refresh_rounded,
            size: 16,
            color: tokens.textSecondary,
          ),
        ],
      ),
    );
  }
}
