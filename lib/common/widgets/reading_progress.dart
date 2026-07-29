import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../services/reading_history_service.dart';

class TritiumReadingProgressBar extends StatelessWidget {
  final ValueListenable<double> progress;

  const TritiumReadingProgressBar({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: 1,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: colors.outlineVariant.withValues(alpha: 0.30)),
          ValueListenableBuilder<double>(
            valueListenable: progress,
            builder: (context, value, child) => FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value.clamp(0.0, 1.0),
              child: ColoredBox(color: colors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tracks reading progress against the end of the main body, not the end of
/// comments that may be inserted lazily. Completion means the body end has
/// reached the viewport's bottom edge, not its top edge.
class ReadingSession {
  final String kind;
  final String id;
  final ScrollController scrollController;
  final GlobalKey bodyEndKey;
  final ValueNotifier<double> progress;

  bool _restoreRequested = false;
  bool _disposed = false;
  double? _knownBodyEndScrollOffset;
  DateTime _lastPersistedAt = DateTime.fromMillisecondsSinceEpoch(0);

  ReadingSession({
    required this.kind,
    required this.id,
    required this.scrollController,
    required this.bodyEndKey,
    ValueNotifier<double>? progress,
  }) : progress = progress ?? ValueNotifier<double>(0) {
    scrollController.addListener(_handleScroll);
  }

  void contentReady() {
    if (_restoreRequested || _disposed) return;
    _restoreRequested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _restore());
  }

  void refresh() {
    if (_disposed) return;
    _updateProgress();
  }

  void _handleScroll() {
    _updateProgress();
    final now = DateTime.now();
    if (now.difference(_lastPersistedAt) >= const Duration(milliseconds: 500)) {
      _lastPersistedAt = now;
      _persist();
    }
  }

  double? _bodyEndScrollOffset() {
    if (!scrollController.hasClients) return null;
    final renderObject = bodyEndKey.currentContext?.findRenderObject();
    if (renderObject != null && renderObject.attached) {
      final viewport = RenderAbstractViewport.maybeOf(renderObject);
      final offset = viewport?.getOffsetToReveal(renderObject, 1).offset;
      if (offset != null && offset.isFinite) {
        final position = scrollController.position;
        _knownBodyEndScrollOffset = offset.clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        );
      }
    }
    if (_knownBodyEndScrollOffset != null) {
      return _knownBodyEndScrollOffset;
    }
    final estimated = scrollController.position.maxScrollExtent;
    return estimated.isFinite ? estimated : null;
  }

  void _updateProgress() {
    final bodyEnd = _bodyEndScrollOffset();
    if (bodyEnd == null || !scrollController.hasClients) return;
    final position = scrollController.position;
    final travel = bodyEnd - position.minScrollExtent;
    final next = travel <= precisionErrorTolerance
        ? 1.0
        : ((scrollController.offset - position.minScrollExtent) / travel).clamp(
            0.0,
            1.0,
          );
    if ((progress.value - next).abs() >= 0.0005) progress.value = next;
  }

  void _restore() {
    if (_disposed || !scrollController.hasClients) return;
    final saved = ReadingHistoryService.find(kind, id)?.progress ?? 0;
    final bodyEnd = _bodyEndScrollOffset();
    if (saved <= 0 || bodyEnd == null) {
      _updateProgress();
      return;
    }
    final position = scrollController.position;
    final target =
        (position.minScrollExtent +
                (bodyEnd - position.minScrollExtent) * saved)
            .clamp(position.minScrollExtent, position.maxScrollExtent);
    scrollController.jumpTo(target);
    _updateProgress();
  }

  void _persist() {
    if (_disposed) return;
    ReadingHistoryService.saveProgress(kind, id, progress.value);
  }

  void dispose({bool disposeProgress = true}) {
    if (_disposed) return;
    _disposed = true;
    scrollController.removeListener(_handleScroll);
    ReadingHistoryService.saveProgress(kind, id, progress.value);
    if (disposeProgress) progress.dispose();
  }
}
