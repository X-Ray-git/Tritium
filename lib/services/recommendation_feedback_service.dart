import '../http/feed_http.dart';
import '../models/recommendation_item.dart';

typedef RecommendationFeedbackPoster =
    Future<bool> Function(List<List<String>> targets);

/// Session-scoped batching for Zhihu recommendation feedback.
///
/// Touch events are batched after the list settles; read events flush
/// immediately. Failed requests remain pending for a later visible/read event.
class RecommendationFeedbackService {
  static const int batchSize = 5;
  static const Duration maxPendingAge = Duration(minutes: 2);

  final RecommendationFeedbackPoster _poster;
  final DateTime Function() _now;
  final Map<String, List<String>> _pending = <String, List<String>>{};
  final Set<String> _reported = <String>{};

  DateTime _lastSuccessfulPost;
  bool _posting = false;
  bool _flushRequested = false;

  RecommendationFeedbackService({
    RecommendationFeedbackPoster? poster,
    DateTime Function()? now,
  }) : _poster = poster ?? FeedHttp.postRecommendationFeedback,
       _now = now ?? DateTime.now,
       _lastSuccessfulPost = (now ?? DateTime.now)();

  Future<void> reportTouched(
    Iterable<RecommendationFeedbackTarget> targets,
  ) async {
    for (final target in targets) {
      _enqueue('t', target);
    }
    if (_pending.length >= batchSize ||
        _now().difference(_lastSuccessfulPost) >= maxPendingAge) {
      await _flush();
    }
  }

  Future<void> reportRead(RecommendationFeedbackTarget target) async {
    _enqueue('r', target);
    await _flush();
  }

  void _enqueue(String event, RecommendationFeedbackTarget target) {
    final eventKey = '$event:${target.stableKey}';
    if (_reported.add(eventKey)) {
      _pending[eventKey] = target.payload(event);
    }
  }

  Future<void> _flush() async {
    if (_posting) {
      _flushRequested = true;
      return;
    }
    if (_pending.isEmpty) return;
    _posting = true;
    try {
      do {
        _flushRequested = false;
        final batchKeys = _pending.keys.toList(growable: false);
        final batch = batchKeys
            .map((key) => _pending[key]!)
            .toList(growable: false);
        if (!await _poster(batch)) break;
        for (final key in batchKeys) {
          _pending.remove(key);
        }
        _lastSuccessfulPost = _now();
        if (_reported.length > 512) {
          _reported
            ..clear()
            ..addAll(_pending.keys);
        }
      } while (_flushRequested && _pending.isNotEmpty);
    } finally {
      _posting = false;
    }
  }
}
