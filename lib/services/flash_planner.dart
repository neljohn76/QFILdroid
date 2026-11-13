import '../models/firmware/flash_plan.dart';
import '../models/firmware/rawprogram_operation.dart';
import '../models/firmware/storage_info.dart';

/// Validates planned operations against device storage geometry and
/// produces an explicit, reviewable flash plan.
///
/// Safety rules enforced here:
///  - every operation must fit inside the reported storage bounds,
///  - sector size must match the device-reported sector size,
///  - overlapping writes on the same partition are flagged as warnings,
///  - unknown or unverifiable image files are surfaced as errors.
class FlashPlanner {
  const FlashPlanner();

  FlashPlan plan({
    required List<RawprogramOperation> operations,
    required StorageInfo storage,
    required Map<String, bool> fileAvailability,
    required bool dryRun,
  }) {
    final errors = <String>[];
    final warnings = <String>[];
    final entries = <FlashPlanEntry>[];
    var totalBytes = 0;

    if (storage.sectorSize <= 0 || storage.totalBlocks <= 0) {
      errors.add(
          'Device storage geometry unknown or invalid; refusing to plan writes');
    }

    final byPartition = <int, List<RawprogramOperation>>{};
    for (final op in operations) {
      (byPartition[op.physicalPartition] ??= []).add(op);
    }

    for (final op in operations) {
      final messages = <String>[];
      var status = PlanEntryStatus.valid;

      if (storage.sectorSize > 0 && op.sectorSize != storage.sectorSize) {
        messages.add(
            'sector size ${op.sectorSize} differs from device ${storage.sectorSize}');
        status = PlanEntryStatus.error;
      }

      if (storage.totalBlocks > 0 &&
          op.startSector + op.numSectors > storage.totalBlocks) {
        messages.add(
            'range [${op.startSector}, ${op.startSector + op.numSectors}) '
            'exceeds device capacity ${storage.totalBlocks} sectors');
        status = PlanEntryStatus.error;
      }

      final available = fileAvailability[op.filename];
      if (available == null) {
        messages.add('image file not found in package: ${op.filename}');
        status = PlanEntryStatus.error;
      } else if (!available) {
        messages.add('image file failed verification: ${op.filename}');
        status = PlanEntryStatus.error;
      }

      entries.add(
        FlashPlanEntry(
          operation: op,
          status: status,
          messages: messages,
        ),
      );
      if (status == PlanEntryStatus.valid) totalBytes += op.byteLength;
    }

    for (final partitionOps in byPartition.entries) {
      final sorted = partitionOps.value.toList()
        ..sort((a, b) => a.startSector.compareTo(b.startSector));
      for (var i = 1; i < sorted.length; i++) {
        final prev = sorted[i - 1];
        final current = sorted[i];
        if (current.startSector < prev.startSector + prev.numSectors) {
          warnings.add(
              'overlap on physical partition ${partitionOps.key}: '
              '${current.filename} starts at ${current.startSector} before '
              '${prev.filename} ends at ${prev.startSector + prev.numSectors - 1}');
        }
      }
    }

    if (dryRun) {
      warnings.add('DRY RUN: no data will be written to the device');
    }

    return FlashPlan(
      entries: entries,
      errors: errors,
      warnings: warnings,
      dryRun: dryRun,
      totalBytes: totalBytes,
    );
  }
}
