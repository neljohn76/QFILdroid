/// Severity of a diagnostic log entry.
enum LogLevel { debug, info, warning, error }

/// Functional category of a diagnostic log entry.
enum LogCategory { usb, sahara, firehose, firmware, flash, system }

/// A single timestamped diagnostic log entry.
class LogEntry {
  LogEntry({
    required this.timestamp,
    required this.level,
    required this.category,
    required this.message,
  });

  factory LogEntry.now({
    required LogLevel level,
    required LogCategory category,
    required String message,
  }) {
    return LogEntry(
      timestamp: DateTime.now(),
      level: level,
      category: category,
      message: message,
    );
  }

  final DateTime timestamp;
  final LogLevel level;
  final LogCategory category;
  final String message;

  String get formattedTimestamp {
    final t = timestamp.toIso8601String();
    return t.substring(0, 23);
  }

  String get levelTag {
    switch (level) {
      case LogLevel.debug:
        return 'D';
      case LogLevel.info:
        return 'I';
      case LogLevel.warning:
        return 'W';
      case LogLevel.error:
        return 'E';
    }
  }

  String get categoryTag {
    switch (category) {
      case LogCategory.usb:
        return 'USB';
      case LogCategory.sahara:
        return 'SAH';
      case LogCategory.firehose:
        return 'FHS';
      case LogCategory.firmware:
        return 'FW';
      case LogCategory.flash:
        return 'FLS';
      case LogCategory.system:
        return 'SYS';
    }
  }

  String format() =>
      '$formattedTimestamp $levelTag/$categoryTag: $message';
}
