import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/log_entry.dart';

/// In-memory ring buffer of timestamped diagnostic logs.
///
/// Every USB event, protocol exchange, firmware validation and flash
/// operation is recorded here. Entries can be exported as a text report.
class LogService extends ChangeNotifier {
  LogService({int capacity = 2000}) : _capacity = capacity;

  final int _capacity;
  final List<LogEntry> _entries = <LogEntry>[];
  final StreamController<LogEntry> _streamController =
      StreamController<LogEntry>.broadcast();

  List<LogEntry> get entries => List.unmodifiable(_entries);

  Stream<LogEntry> get stream => _streamController.stream;

  void add(LogLevel level, LogCategory category, String message) {
    final entry = LogEntry.now(
      level: level,
      category: category,
      message: message,
    );
    _entries.add(entry);
    if (_entries.length > _capacity) {
      _entries.removeRange(0, _entries.length - _capacity);
    }
    if (!_streamController.isClosed) {
      _streamController.add(entry);
    }
    notifyListeners();
  }

  void debug(LogCategory category, String message) =>
      add(LogLevel.debug, category, message);

  void info(LogCategory category, String message) =>
      add(LogLevel.info, category, message);

  void warning(LogCategory category, String message) =>
      add(LogLevel.warning, category, message);

  void error(LogCategory category, String message) =>
      add(LogLevel.error, category, message);

  List<LogEntry> filtered({
    LogLevel? minLevel,
    Set<LogCategory>? categories,
    String? query,
  }) {
    return _entries.where((entry) {
      if (categories != null && categories.isNotEmpty) {
        if (!categories.contains(entry.category)) return false;
      }
      if (minLevel != null && entry.level.index < minLevel.index) return false;
      if (query != null && query.isNotEmpty) {
        if (!entry.message.toLowerCase().contains(query.toLowerCase())) {
          return false;
        }
      }
      return true;
    }).toList(growable: false);
  }

  /// Builds the full exportable diagnostic report.
  String exportText() {
    final buffer = StringBuffer()
      ..writeln('QFILdroid diagnostic report')
      ..writeln('Generated: ${DateTime.now().toIso8601String()}')
      ..writeln('Entries: ${_entries.length}')
      ..writeln('---');
    for (final entry in _entries) {
      buffer.writeln(entry.format());
    }
    return buffer.toString();
  }

  @override
  void dispose() {
    _streamController.close();
    super.dispose();
  }
}
