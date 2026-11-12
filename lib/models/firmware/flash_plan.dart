import 'rawprogram_operation.dart';

/// Validation outcome for one planned operation.
enum PlanEntryStatus { valid, warning, error }

/// One operation in a validated flash plan.
class FlashPlanEntry {
  const FlashPlanEntry({
    required this.operation,
    required this.status,
    required this.messages,
  });

  final RawprogramOperation operation;
  final PlanEntryStatus status;
  final List<String> messages;

  bool get isValid => status != PlanEntryStatus.error;
}

/// Result of validating a firmware package against device storage geometry.
class FlashPlan {
  const FlashPlan({
    required this.entries,
    required this.errors,
    required this.warnings,
    required this.dryRun,
    required this.totalBytes,
  });

  final List<FlashPlanEntry> entries;
  final List<String> errors;
  final List<String> warnings;
  final bool dryRun;
  final int totalBytes;

  bool get isExecutable => errors.isEmpty && entries.any((e) => e.isValid);

  int get validCount => entries.where((e) => e.isValid).length;

  int get errorCount =>
      entries.where((e) => e.status == PlanEntryStatus.error).length;
}
