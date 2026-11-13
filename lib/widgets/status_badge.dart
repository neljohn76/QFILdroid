import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../models/connection_stage.dart';

/// Colored badge for the current connection stage.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.stage, this.compact = false});

  final ConnectionStage stage;
  final bool compact;

  static Color colorFor(ConnectionStage stage) {
    switch (stage) {
      case ConnectionStage.disconnected:
        return QfildroidTheme.muted;
      case ConnectionStage.usbConnected:
      case ConnectionStage.permissionRequired:
        return QfildroidTheme.info;
      case ConnectionStage.edlCandidateDetected:
        return QfildroidTheme.warning;
      case ConnectionStage.protocolConnected:
      case ConnectionStage.programmerValidated:
      case ConnectionStage.readyForAuthorizedOperation:
        return QfildroidTheme.success;
      case ConnectionStage.operationInProgress:
        return QfildroidTheme.info;
      case ConnectionStage.operationFailed:
        return QfildroidTheme.danger;
      case ConnectionStage.operationCompleted:
        return QfildroidTheme.success;
    }
  }

  static IconData iconFor(ConnectionStage stage) {
    switch (stage) {
      case ConnectionStage.disconnected:
        return Icons.usb_off;
      case ConnectionStage.usbConnected:
        return Icons.usb;
      case ConnectionStage.permissionRequired:
        return Icons.lock_outline;
      case ConnectionStage.edlCandidateDetected:
        return Icons.warning_amber_outlined;
      case ConnectionStage.protocolConnected:
        return Icons.cable;
      case ConnectionStage.programmerValidated:
        return Icons.verified_outlined;
      case ConnectionStage.readyForAuthorizedOperation:
        return Icons.task_alt;
      case ConnectionStage.operationInProgress:
        return Icons.sync;
      case ConnectionStage.operationFailed:
        return Icons.error_outline;
      case ConnectionStage.operationCompleted:
        return Icons.check_circle_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = colorFor(stage);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconFor(stage), size: compact ? 12 : 16, color: color),
          const SizedBox(width: 6),
          Text(
            stage.label,
            style: TextStyle(
              color: color,
              fontSize: compact ? 11 : 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
