import 'dart:convert';

/// Content identity shared by recommendation de-duplication and feedback.
///
/// Zhihu returns several feed envelopes (`target`, `brief`, `card` and
/// `common_card`). This model deliberately extracts only identities that can
/// be verified from the response or its navigation URL. Unknown cards remain
/// displayable, but are never assigned a guessed feedback target.
class RecommendationItemDescriptor {
  final String stableKey;
  final RecommendationFeedbackTarget? feedbackTarget;

  const RecommendationItemDescriptor({
    required this.stableKey,
    this.feedbackTarget,
  });

  static RecommendationItemDescriptor? fromRaw(Map<String, dynamic> raw) {
    final candidates = <Map<String, dynamic>>[];

    void addCandidate(dynamic value) {
      final map = _asStringMap(value);
      if (map != null) candidates.add(map);
    }

    addCandidate(raw['target']);
    addCandidate(_asStringMap(raw['card'])?['content']);

    final brief = _decodeBrief(raw['brief']);
    if (brief != null) {
      addCandidate(brief['target']);
      addCandidate(brief);
    }

    for (final candidate in candidates) {
      final descriptor = _fromContentMap(candidate);
      if (descriptor != null) return descriptor;
    }

    final commonCard = _asStringMap(raw['common_card']);
    final card = _asStringMap(raw['card']);
    final commonAction = _asStringMap(commonCard?['action']);
    final cardAction = _asStringMap(card?['action']);
    final urls = <String?>[
      commonAction?['intent_url']?.toString(),
      cardAction?['intent_url']?.toString(),
      raw['url']?.toString(),
    ];
    for (final url in urls) {
      final descriptor = _fromUrl(url);
      if (descriptor != null) return descriptor;
    }

    final topLevelDescriptor = _fromContentMap(raw);
    if (topLevelDescriptor != null) return topLevelDescriptor;

    // A feed-envelope ID is still useful for preventing an exact duplicate in
    // one response, but it is not a verified content target.
    final envelopeId = raw['id']?.toString();
    if (envelopeId != null && envelopeId.isNotEmpty) {
      return RecommendationItemDescriptor(stableKey: 'feed:$envelopeId');
    }
    return null;
  }

  static RecommendationItemDescriptor? _fromContentMap(
    Map<String, dynamic> content,
  ) {
    var type = content['type']?.toString().toLowerCase();
    final id = content['id']?.toString();

    if ((type == null || type.isEmpty || type == 'feed') &&
        content['question'] is Map &&
        id != null &&
        id.isNotEmpty) {
      type = 'answer';
    }
    if (type == null || type.isEmpty || id == null || id.isEmpty) return null;

    final normalizedType = switch (type) {
      'answer' || 'answers' => 'answer',
      'article' || 'articles' || 'post' => 'article',
      'question' || 'questions' => 'question',
      'pin' || 'pins' => 'pin',
      'zvideo' || 'video' || 'videos' => 'zvideo',
      _ => type,
    };
    final feedbackType = switch (normalizedType) {
      'answer' => 'a',
      'article' => 'p',
      'question' => 'q',
      _ => null,
    };

    return RecommendationItemDescriptor(
      stableKey: '$normalizedType:$id',
      feedbackTarget: feedbackType == null
          ? null
          : RecommendationFeedbackTarget(type: feedbackType, id: id),
    );
  }

  static RecommendationItemDescriptor? _fromUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.isEmpty) return null;
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return null;

    final segments = uri.pathSegments.where((part) => part.isNotEmpty).toList();
    String? type;
    String? id;

    if (uri.scheme == 'zhihu') {
      final route = uri.host.isNotEmpty
          ? <String>[uri.host, ...segments]
          : segments;
      if (route.isEmpty) return null;
      final answerIndex = route.indexWhere(
        (part) => part == 'answer' || part == 'answers',
      );
      if (answerIndex >= 0 && answerIndex + 1 < route.length) {
        type = 'answer';
        id = route[answerIndex + 1];
      } else {
        type = route.first;
        if (route.length > 1) id = route[1];
      }
    } else {
      final answerIndex = segments.indexOf('answer');
      if (answerIndex >= 0 && answerIndex + 1 < segments.length) {
        type = 'answer';
        id = segments[answerIndex + 1];
      } else {
        for (final routeType in const [
          'question',
          'p',
          'article',
          'pin',
          'zvideo',
        ]) {
          final index = segments.indexOf(routeType);
          if (index >= 0 && index + 1 < segments.length) {
            type = routeType;
            id = segments[index + 1];
            break;
          }
        }
      }
    }

    if (type == null || id == null || id.isEmpty) return null;
    return _fromContentMap({'type': type, 'id': id});
  }

  static Map<String, dynamic>? _decodeBrief(dynamic value) {
    if (value is String) {
      try {
        return _asStringMap(jsonDecode(value));
      } on FormatException {
        return null;
      }
    }
    return _asStringMap(value);
  }

  static Map<String, dynamic>? _asStringMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }
}

class RecommendationFeedbackTarget {
  final String type;
  final String id;

  const RecommendationFeedbackTarget({required this.type, required this.id});

  List<String> payload(String event) => [event, type, id];

  String get stableKey => '$type:$id';
}

/// Keeps recommendation repetition out of the current process only.
///
/// This is intentionally not persisted: it corrects duplicate pages and
/// repeated refreshes without becoming a hidden long-term content filter.
class RecommendationSessionFilter {
  final Set<String> _seen = <String>{};

  int get seenCount => _seen.length;

  List<Map<String, dynamic>> accept(Iterable<Map<String, dynamic>> items) {
    final accepted = <Map<String, dynamic>>[];
    final pageKeys = <String>{};

    for (final item in items) {
      final descriptor = RecommendationItemDescriptor.fromRaw(item);
      final key = descriptor?.stableKey;
      if (key != null && (!pageKeys.add(key) || _seen.contains(key))) {
        continue;
      }
      accepted.add(item);
      if (key != null) _seen.add(key);
    }
    return accepted;
  }
}
