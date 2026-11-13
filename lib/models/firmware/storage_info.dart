/// Storage geometry reported by a firehose programmer via <getstorageinfo>.
class StorageInfo {
  const StorageInfo({
    required this.memoryName,
    required this.sectorSize,
    required this.totalBlocks,
    required this.blockSize,
  });

  final String memoryName;
  final int sectorSize;
  final int totalBlocks;
  final int blockSize;

  int get totalSectors => totalBlocks;

  int get totalBytes => totalBlocks * sectorSize;

  Map<String, Object?> toMap() => {
        'memoryName': memoryName,
        'sectorSize': sectorSize,
        'totalBlocks': totalBlocks,
        'blockSize': blockSize,
      };

  static StorageInfo fromMap(Map<Object?, Object?> map) => StorageInfo(
        memoryName: (map['memoryName'] as String?) ?? '',
        sectorSize: (map['sectorSize'] as num?)?.toInt() ?? 0,
        totalBlocks: (map['totalBlocks'] as num?)?.toInt() ?? 0,
        blockSize: (map['blockSize'] as num?)?.toInt() ?? 0,
      );
}

/// A partition entry shown in the Partition Manager (read-only diagnostics).
class PartitionInfo {
  const PartitionInfo({
    required this.label,
    required this.startSector,
    required this.numSectors,
    required this.sectorSize,
    required this.physicalPartition,
    this.readonly = false,
  });

  final String label;
  final int startSector;
  final int numSectors;
  final int sectorSize;
  final int physicalPartition;
  final bool readonly;

  int get byteLength => numSectors * sectorSize;

  int get endSector => startSector + numSectors - 1;
}
