import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../common/constants/constants.dart';
import '../utils/storage.dart';

@immutable
class ReadingHistoryEntry {
  final String kind;
  final String id;
  final String title;
  final String preview;
  final String url;
  final double progress;
  final DateTime visitedAt;

  const ReadingHistoryEntry({
    required this.kind,
    required this.id,
    required this.title,
    required this.preview,
    required this.url,
    required this.progress,
    required this.visitedAt,
  });

  String get storageId => '$kind:$id';

  Map<String, dynamic> toMap() => {
    'kind': kind,
    'id': id,
    'title': title,
    'preview': preview,
    'url': url,
    'progress': progress,
    'visitedAt': visitedAt.millisecondsSinceEpoch,
  };

  static ReadingHistoryEntry? fromMap(dynamic raw) {
    if (raw is! Map) return null;
    final kind = raw['kind']?.toString();
    final id = raw['id']?.toString();
    final url = raw['url']?.toString();
    final visitedAt = raw['visitedAt'];
    if (kind == null ||
        kind.isEmpty ||
        id == null ||
        id.isEmpty ||
        url == null ||
        url.isEmpty ||
        visitedAt is! int) {
      return null;
    }
    final rawProgress = raw['progress'];
    final progress = rawProgress is num
        ? rawProgress.toDouble().clamp(0.0, 1.0)
        : 0.0;
    return ReadingHistoryEntry(
      kind: kind,
      id: id,
      title: raw['title']?.toString() ?? '',
      preview: raw['preview']?.toString() ?? '',
      url: url,
      progress: progress,
      visitedAt: DateTime.fromMillisecondsSinceEpoch(visitedAt),
    );
  }

  ReadingHistoryEntry copyWith({
    String? title,
    String? preview,
    String? url,
    double? progress,
    DateTime? visitedAt,
  }) {
    return ReadingHistoryEntry(
      kind: kind,
      id: id,
      title: title ?? this.title,
      preview: preview ?? this.preview,
      url: url ?? this.url,
      progress: progress ?? this.progress,
      visitedAt: visitedAt ?? this.visitedAt,
    );
  }
}

abstract final class ReadingHistoryService {
  static const int _maximumEntries = 200;
  static Future<void> _writeQueue = Future<void>.value();

  @visibleForTesting
  static bool persistenceEnabled = true;

  static ValueListenable<Box> get listenable =>
      GStorage.cache.listenable(keys: const [StorageKeys.readingHistory]);

  static List<ReadingHistoryEntry> get entries {
    final raw = GStorage.cache.get(
      StorageKeys.readingHistory,
      defaultValue: const <dynamic>[],
    );
    if (raw is! List) return const [];
    return raw
        .map(ReadingHistoryEntry.fromMap)
        .whereType<ReadingHistoryEntry>()
        .toList(growable: false);
  }

  static ReadingHistoryEntry? find(String kind, String id) {
    final storageId = '$kind:$id';
    for (final entry in entries) {
      if (entry.storageId == storageId) return entry;
    }
    return null;
  }

  static Future<void> record({
    required String kind,
    required String id,
    required String title,
    required String url,
    String preview = '',
  }) async {
    if (!persistenceEnabled) return;
    return _enqueue(() async {
      final current = entries.toList();
      final storageId = '$kind:$id';
      final previousIndex = current.indexWhere(
        (entry) => entry.storageId == storageId,
      );
      final previous = previousIndex < 0
          ? null
          : current.removeAt(previousIndex);
      final cleanTitle = _cleanText(title);
      final cleanPreview = _cleanText(preview, maximumLength: 140);
      current.insert(
        0,
        ReadingHistoryEntry(
          kind: kind,
          id: id,
          title: cleanTitle.isEmpty ? previous?.title ?? '' : cleanTitle,
          preview: cleanPreview.isEmpty
              ? previous?.preview ?? ''
              : cleanPreview,
          url: url,
          progress: previous?.progress ?? 0,
          visitedAt: DateTime.now(),
        ),
      );
      if (current.length > _maximumEntries) {
        current.removeRange(_maximumEntries, current.length);
      }
      await _write(current);
    });
  }

  static Future<void> saveProgress(
    String kind,
    String id,
    double progress,
  ) async {
    if (!persistenceEnabled) return;
    return _enqueue(() async {
      final current = entries.toList();
      final index = current.indexWhere(
        (entry) => entry.kind == kind && entry.id == id,
      );
      if (index < 0) return;
      final normalized = progress.clamp(0.0, 1.0);
      if ((current[index].progress - normalized).abs() < 0.002) return;
      current[index] = current[index].copyWith(progress: normalized);
      await _write(current);
    });
  }

  static Future<void> remove(String kind, String id) async {
    if (!persistenceEnabled) return;
    return _enqueue(() async {
      final current = entries
          .where((entry) => entry.kind != kind || entry.id != id)
          .toList();
      await _write(current);
    });
  }

  static Future<void> clear() => persistenceEnabled
      ? _enqueue(() => GStorage.cache.delete(StorageKeys.readingHistory))
      : Future<void>.value();

  static Future<void> flush() => _writeQueue;

  static Future<void> _write(List<ReadingHistoryEntry> entries) {
    return GStorage.cache.put(
      StorageKeys.readingHistory,
      entries.map((entry) => entry.toMap()).toList(growable: false),
    );
  }

  static Future<void> _enqueue(Future<void> Function() operation) {
    final result = _writeQueue.then((_) => operation());
    _writeQueue = result.catchError((Object _) {});
    return result;
  }

  static String _cleanText(String value, {int maximumLength = 200}) {
    final clean = value.replaceAll(RegExp(r'<[^>]+>'), ' ');
    final normalized = clean.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= maximumLength) return normalized;
    return '${normalized.substring(0, maximumLength)}…';
  }
}
