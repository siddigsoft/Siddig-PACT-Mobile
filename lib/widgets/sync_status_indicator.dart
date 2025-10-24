import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/sync_provider.dart';
import '../services/offline_sync_service.dart';

class SyncStatusIndicator extends StatelessWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SyncProvider>(
      builder: (context, syncProvider, child) {
        final status = syncProvider.syncStatus;
        final isOnline = syncProvider.isOnline;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _getBackgroundColor(status, isOnline),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getStatusIcon(status, isOnline),
                size: 16,
                color: _getIconColor(status, isOnline),
              ),
              const SizedBox(width: 6),
              Text(
                _getStatusText(status, isOnline),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _getTextColor(status, isOnline),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getBackgroundColor(SyncStatus status, bool isOnline) {
    if (!isOnline) {
      return Colors.grey.shade200;
    }

    switch (status) {
      case SyncStatus.syncing:
        return Colors.blue.shade50;
      case SyncStatus.success:
        return Colors.green.shade50;
      case SyncStatus.error:
        return Colors.red.shade50;
      default:
        return Colors.white;
    }
  }

  IconData _getStatusIcon(SyncStatus status, bool isOnline) {
    if (!isOnline) {
      return Icons.wifi_off;
    }

    switch (status) {
      case SyncStatus.syncing:
        return Icons.sync;
      case SyncStatus.success:
        return Icons.check_circle;
      case SyncStatus.error:
        return Icons.error;
      default:
        return Icons.wifi;
    }
  }

  Color _getIconColor(SyncStatus status, bool isOnline) {
    if (!isOnline) {
      return Colors.grey.shade600;
    }

    switch (status) {
      case SyncStatus.syncing:
        return Colors.blue.shade600;
      case SyncStatus.success:
        return Colors.green.shade600;
      case SyncStatus.error:
        return Colors.red.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  Color _getTextColor(SyncStatus status, bool isOnline) {
    if (!isOnline) {
      return Colors.grey.shade700;
    }

    switch (status) {
      case SyncStatus.syncing:
        return Colors.blue.shade700;
      case SyncStatus.success:
        return Colors.green.shade700;
      case SyncStatus.error:
        return Colors.red.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  String _getStatusText(SyncStatus status, bool isOnline) {
    if (!isOnline) {
      return 'Offline';
    }

    switch (status) {
      case SyncStatus.syncing:
        return 'Syncing...';
      case SyncStatus.success:
        return 'Synced';
      case SyncStatus.error:
        return 'Sync Error';
      default:
        return 'Online';
    }
  }
}

class SyncStatusDialog extends StatelessWidget {
  const SyncStatusDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SyncProvider>(
      builder: (context, syncProvider, child) {
        return AlertDialog(
          title: const Text('Sync Status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Status: ${syncProvider.syncStatus.toString().split('.').last}'),
              Text('Online: ${syncProvider.isOnline ? 'Yes' : 'No'}'),
              const SizedBox(height: 16),
              StreamBuilder<String>(
                stream: syncProvider.syncMessages,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return Text('Latest: ${snapshot.data}');
                  }
                  return const SizedBox.shrink();
                },
              ),
              const SizedBox(height: 16),
              const Text('Manual Sync Options:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: syncProvider.syncStatus == SyncStatus.syncing
                        ? null
                        : () async {
                            await syncProvider.performFullSync();
                          },
                    icon: const Icon(Icons.sync),
                    label: const Text('Full Sync'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: syncProvider.syncStatus == SyncStatus.syncing
                        ? null
                        : () async {
                            await syncProvider.syncTasks();
                          },
                    icon: const Icon(Icons.task),
                    label: const Text('Tasks'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: syncProvider.syncStatus == SyncStatus.syncing
                        ? null
                        : () async {
                            await syncProvider.syncEquipment();
                          },
                    icon: const Icon(Icons.build),
                    label: const Text('Equipment'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: syncProvider.syncStatus == SyncStatus.syncing
                        ? null
                        : () async {
                            await syncProvider.syncSafetyReports();
                          },
                    icon: const Icon(Icons.shield),
                    label: const Text('Safety'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}