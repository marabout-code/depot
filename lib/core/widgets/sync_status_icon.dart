import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/string_constants.dart';
import '../services/sync_service.dart';

/// Compact live sync indicator meant for an AppBar. Reflects whether the app is
/// online, how many local changes are still queued, and lets the operator force
/// a pass with a tap. Mirrors the fuller sync card shown in Settings.
class SyncStatusIcon extends ConsumerWidget {
  const SyncStatusIcon({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status =
        ref.watch(syncStatusProvider).valueOrNull ?? const SyncStatus();

    final syncing = status.running;
    final pending = status.pendingWrites;
    final hasError = !syncing && status.online && status.lastError != null;

    final IconData icon;
    if (!status.online) {
      icon = Icons.cloud_off;
    } else if (hasError) {
      icon = Icons.error_outline;
    } else if (pending > 0) {
      icon = Icons.cloud_upload;
    } else {
      icon = Icons.cloud_done;
    }

    final String tooltip;
    if (syncing) {
      tooltip = StringConstants.frSyncSyncing;
    } else if (!status.online) {
      tooltip = StringConstants.frSyncOffline;
    } else if (hasError) {
      tooltip = '${StringConstants.frSyncTitle} : ${status.lastError}';
    } else if (pending > 0) {
      tooltip = '$pending ${StringConstants.frSyncQueued}';
    } else {
      tooltip = StringConstants.frSyncAllSynced;
    }

    final iconColor = IconTheme.of(context).color;

    return IconButton(
      tooltip: tooltip,
      onPressed: syncing ? null : () => ref.read(syncServiceProvider).syncNow(),
      icon: syncing
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color?>(
                  iconColor ?? Theme.of(context).colorScheme.primary,
                ),
              ),
            )
          : pending > 0
              ? Badge.count(count: pending, child: Icon(icon))
              : Icon(icon),
    );
  }
}
