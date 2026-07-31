import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../services/reading_history_service.dart';

class TritiumReadingProgressBar extends StatefulWidget {
  final ValueListenable<double> progress;
  final ValueListenable<bool>? seekable;
  final ValueChanged<double>? onSeek;

  const TritiumReadingProgressBar({
    super.key,
    required this.progress,
    this.seekable,
    this.onSeek,
  });

  @override
  State<TritiumReadingProgressBar> createState() =>
      _TritiumReadingProgressBarState();
}

class _TritiumReadingProgressBarState extends State<TritiumReadingProgressBar> {
  bool _dragging = false;
  double? _dragProgress;

  void _seek(DragUpdateDetails details, double width) {
    if (width <= 0) return;
    final next = (details.localPosition.dx / width).clamp(0.0, 1.0);
    setState(() => _dragProgress = next);
    widget.onSeek?.call(next);
  }

  void _startSeek(DragStartDetails details, double width) {
    if (width <= 0) return;
    final next = (details.localPosition.dx / width).clamp(0.0, 1.0);
    setState(() {
      _dragging = true;
      _dragProgress = next;
    });
    widget.onSeek?.call(next);
  }

  void _finishSeek() {
    if (!_dragging) return;
    setState(() {
      _dragging = false;
      _dragProgress = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ValueListenableBuilder<double>(
      valueListenable: widget.progress,
      builder: (context, progress, child) {
        final seekable = widget.seekable;
        if (seekable == null) {
          return _buildBar(
            context,
            colors,
            progress: progress,
            canSeek: widget.onSeek != null,
          );
        }
        return ValueListenableBuilder<bool>(
          valueListenable: seekable,
          builder: (context, canSeek, child) => _buildBar(
            context,
            colors,
            progress: progress,
            canSeek: canSeek && widget.onSeek != null,
          ),
        );
      },
    );
  }

  Widget _buildBar(
    BuildContext context,
    ColorScheme colors, {
    required double progress,
    required bool canSeek,
  }) {
    final displayedProgress = (_dragProgress ?? progress).clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final labelLeft = width.isFinite
            ? (displayedProgress * width - 22).clamp(
                0.0,
                (width - 44).clamp(0.0, double.infinity),
              )
            : 0.0;
        return Semantics(
          label: '正文阅读进度',
          value: '${(displayedProgress * 100).round()}%',
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: canSeek
                ? (details) => _startSeek(details, width)
                : null,
            onHorizontalDragUpdate: canSeek
                ? (details) => _seek(details, width)
                : null,
            onHorizontalDragEnd: canSeek ? (_) => _finishSeek() : null,
            onHorizontalDragCancel: canSeek ? _finishSeek : null,
            child: SizedBox(
              height: 24,
              width: double.infinity,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: _dragging ? 3 : 1,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ColoredBox(
                          color: colors.outlineVariant.withValues(alpha: 0.30),
                        ),
                        FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: displayedProgress,
                          child: ColoredBox(color: colors.primary),
                        ),
                      ],
                    ),
                  ),
                  if (_dragging)
                    Positioned(
                      top: 5,
                      left: labelLeft,
                      width: 44,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.inverseSurface.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            '${(displayedProgress * 100).round()}%',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: colors.onInverseSurface,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Keeps the one-pixel reading indicator visually attached to the app bar
/// while providing a practical, invisible horizontal drag target below it.
class TritiumReadingProgressOverlay extends StatelessWidget {
  final Widget child;
  final ValueListenable<double> progress;
  final ValueListenable<bool> seekable;
  final ValueChanged<double> onSeek;
  final double top;

  const TritiumReadingProgressOverlay({
    super.key,
    required this.child,
    required this.progress,
    required this.seekable,
    required this.onSeek,
    this.top = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        Positioned(
          top: top,
          left: 0,
          right: 0,
          height: 24,
          child: TritiumReadingProgressBar(
            progress: progress,
            seekable: seekable,
            onSeek: onSeek,
          ),
        ),
      ],
    );
  }
}

extension TritiumReadingProgressWidget on Widget {
  Widget withTritiumReadingProgress({
    required ValueListenable<double> progress,
    required ValueListenable<bool> seekable,
    required ValueChanged<double> onSeek,
    double top = 0,
  }) {
    return TritiumReadingProgressOverlay(
      progress: progress,
      seekable: seekable,
      onSeek: onSeek,
      top: top,
      child: this,
    );
  }

  Widget withTritiumReadingSession(ReadingSession? session, {double top = 0}) {
    if (session == null) return this;
    return withTritiumReadingProgress(
      progress: session.progress,
      seekable: session.seekable,
      onSeek: session.seekToProgress,
      top: top,
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
  final ValueNotifier<bool> seekable;

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
    ValueNotifier<bool>? seekable,
  }) : progress = progress ?? ValueNotifier<double>(0),
       seekable = seekable ?? ValueNotifier<bool>(false) {
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
    final canSeek = travel > precisionErrorTolerance;
    if (seekable.value != canSeek) seekable.value = canSeek;
    final next = travel <= precisionErrorTolerance
        ? 1.0
        : ((scrollController.offset - position.minScrollExtent) / travel).clamp(
            0.0,
            1.0,
          );
    if ((progress.value - next).abs() >= 0.0005) progress.value = next;
  }

  void seekToProgress(double value) {
    if (_disposed || !scrollController.hasClients) return;
    final bodyEnd = _bodyEndScrollOffset();
    if (bodyEnd == null) return;
    final position = scrollController.position;
    final travel = bodyEnd - position.minScrollExtent;
    if (travel <= precisionErrorTolerance) return;
    final target = position.minScrollExtent + travel * value.clamp(0.0, 1.0);
    scrollController.jumpTo(
      target.clamp(position.minScrollExtent, position.maxScrollExtent),
    );
    _updateProgress();
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
    if (disposeProgress) {
      progress.dispose();
      seekable.dispose();
    }
  }
}
