import 'package:flutter_test/flutter_test.dart';
import 'package:qfildroid/models/firmware/flash_plan.dart';
import 'package:qfildroid/models/firmware/rawprogram_operation.dart';
import 'package:qfildroid/models/firmware/storage_info.dart';
import 'package:qfildroid/services/flash_planner.dart';

RawprogramOperation op({
  String filename = 'boot.img',
  int sectorSize = 4096,
  int startSector = 0,
  int numSectors = 100,
  int partition = 0,
}) =>
    RawprogramOperation(
      sourceFile: 'rawprogram0.xml',
      filename: filename,
      sectorSize: sectorSize,
      startSector: startSector,
      numSectors: numSectors,
      physicalPartition: partition,
    );

const StorageInfo ufs = StorageInfo(
  memoryName: 'UFS',
  sectorSize: 4096,
  totalBlocks: 122880,
  blockSize: 4096,
);

void main() {
  const planner = FlashPlanner();

  group('storage boundary validation', () {
    test('operation within bounds is valid', () {
      final plan = planner.plan(
        operations: [op(startSector: 0, numSectors: 100)],
        storage: ufs,
        fileAvailability: {'boot.img': true},
        dryRun: true,
      );
      expect(plan.errors, isEmpty);
      expect(plan.entries.single.status, PlanEntryStatus.valid);
    });

    test('operation beyond device capacity is rejected', () {
      final plan = planner.plan(
        operations: [op(startSector: 122870, numSectors: 100)],
        storage: ufs,
        fileAvailability: {'boot.img': true},
        dryRun: true,
      );
      expect(plan.entries.single.status, PlanEntryStatus.error);
      expect(
        plan.entries.single.messages.join(' '),
        contains('exceeds device capacity'),
      );
      expect(plan.isExecutable, isFalse);
    });

    test('sector size mismatch is rejected', () {
      final plan = planner.plan(
        operations: [op(sectorSize: 512)],
        storage: ufs,
        fileAvailability: {'boot.img': true},
        dryRun: true,
      );
      expect(plan.entries.single.status, PlanEntryStatus.error);
      expect(
        plan.entries.single.messages.join(' '),
        contains('differs from device'),
      );
    });

    test('unknown storage geometry refuses to plan writes', () {
      const unknown = StorageInfo(
        memoryName: 'unknown',
        sectorSize: 0,
        totalBlocks: 0,
        blockSize: 0,
      );
      final plan = planner.plan(
        operations: [op()],
        storage: unknown,
        fileAvailability: {'boot.img': true},
        dryRun: true,
      );
      expect(
        plan.errors.join(' '),
        contains('geometry unknown or invalid'),
      );
      expect(plan.isExecutable, isFalse);
    });
  });

  group('file availability', () {
    test('missing image file is an error', () {
      final plan = planner.plan(
        operations: [op()],
        storage: ufs,
        fileAvailability: const {},
        dryRun: true,
      );
      expect(plan.entries.single.status, PlanEntryStatus.error);
      expect(
        plan.entries.single.messages.join(' '),
        contains('not found in package'),
      );
    });

    test('failed verification is an error', () {
      final plan = planner.plan(
        operations: [op()],
        storage: ufs,
        fileAvailability: {'boot.img': false},
        dryRun: true,
      );
      expect(plan.entries.single.status, PlanEntryStatus.error);
      expect(
        plan.entries.single.messages.join(' '),
        contains('failed verification'),
      );
    });
  });

  group('overlap detection', () {
    test('overlapping writes on same partition produce a warning', () {
      final plan = planner.plan(
        operations: [
          op(filename: 'a.img', startSector: 0, numSectors: 100),
          op(filename: 'b.img', startSector: 50, numSectors: 100),
        ],
        storage: ufs,
        fileAvailability: {'a.img': true, 'b.img': true},
        dryRun: true,
      );
      expect(
        plan.warnings.join(' '),
        contains('overlap on physical partition 0'),
      );
    });

    test('writes on different partitions do not overlap', () {
      final plan = planner.plan(
        operations: [
          op(filename: 'a.img', startSector: 0, numSectors: 100, partition: 0),
          op(filename: 'b.img', startSector: 0, numSectors: 100, partition: 1),
        ],
        storage: ufs,
        fileAvailability: {'a.img': true, 'b.img': true},
        dryRun: true,
      );
      expect(plan.warnings.where((w) => w.contains('overlap')), isEmpty);
    });
  });

  group('dry-run', () {
    test('dry run is surfaced in the plan', () {
      final plan = planner.plan(
        operations: [op()],
        storage: ufs,
        fileAvailability: {'boot.img': true},
        dryRun: true,
      );
      expect(plan.dryRun, isTrue);
      expect(plan.warnings.join(' '), contains('DRY RUN'));
      expect(plan.isExecutable, isTrue);
    });

    test('total bytes only counts valid entries', () {
      final plan = planner.plan(
        operations: [
          op(filename: 'good.img', numSectors: 10),
          op(filename: 'missing.img', numSectors: 20),
        ],
        storage: ufs,
        fileAvailability: {'good.img': true},
        dryRun: true,
      );
      expect(plan.totalBytes, 10 * 4096);
      expect(plan.errorCount, 1);
      expect(plan.validCount, 1);
    });
  });
}
