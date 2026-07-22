import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'app_chrome.dart';

/// 正文图片画廊：同文图片翻页、双击/双指缩放、下拉退出和长按操作。
class ImageViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const ImageViewer({
    super.key,
    required this.imageUrls,
    required this.initialIndex,
  });

  static void show(
    BuildContext context,
    String imageUrl, {
    List<String> imageUrls = const [],
  }) {
    final urls = <String>[];
    for (final url in imageUrls) {
      if (url.isNotEmpty && !urls.contains(url)) urls.add(url);
    }
    if (!urls.contains(imageUrl)) urls.add(imageUrl);
    final initialIndex = urls.indexOf(imageUrl).clamp(0, urls.length - 1);

    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (context, animation, secondaryAnimation) =>
            ImageViewer(imageUrls: urls, initialIndex: initialIndex),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  State<ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<ImageViewer>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  late final TransformationController _transformationController;
  late final AnimationController _zoomAnimationController;
  Animation<Matrix4>? _zoomAnimation;
  late int _currentIndex;
  bool _isZoomed = false;
  bool _isReturning = false;
  double _dismissOffset = 0;
  Offset _doubleTapPosition = Offset.zero;

  String get _currentUrl => widget.imageUrls[_currentIndex];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _transformationController = TransformationController();
    _zoomAnimationController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 300),
        )..addListener(() {
          final animation = _zoomAnimation;
          if (animation != null) {
            _transformationController.value = animation.value;
          }
        });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _zoomAnimationController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _setZoomed(bool value) {
    if (_isZoomed != value) setState(() => _isZoomed = value);
  }

  void _animateZoomTo(Matrix4 target, {bool resetAfter = false}) {
    _zoomAnimation =
        Matrix4Tween(
          begin: _transformationController.value,
          end: target,
        ).animate(
          CurvedAnimation(
            parent: _zoomAnimationController,
            curve: Curves.easeOut,
          ),
        );
    _zoomAnimationController.forward(from: 0).whenComplete(() {
      if (mounted && resetAfter) _setZoomed(false);
    });
  }

  void _onImageDoubleTap(Offset position) {
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    if (currentScale > 1.01) {
      _animateZoomTo(Matrix4.identity(), resetAfter: true);
      return;
    }

    const targetScale = 3.2;
    final target =
        Matrix4.diagonal3Values(targetScale, targetScale, targetScale)
          ..setTranslationRaw(
            -position.dx * (targetScale - 1),
            -position.dy * (targetScale - 1),
            0,
          );
    _setZoomed(true);
    _animateZoomTo(target);
  }

  void _onImageInteractionUpdate(ScaleUpdateDetails details) {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    if (scale > 1.01) {
      _setZoomed(true);
    } else if (details.scale < 0.99) {
      _setZoomed(false);
    }
  }

  void _onImageInteractionEnd(ScaleEndDetails details) {
    if (_transformationController.value.getMaxScaleOnAxis() <= 1.01) {
      _transformationController.value = Matrix4.identity();
      _setZoomed(false);
    }
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (_isZoomed) return;
    setState(() {
      _isReturning = false;
      _dismissOffset = (_dismissOffset + details.delta.dy).clamp(0, 600);
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (_isZoomed) return;
    if (_dismissOffset > 120 || (details.primaryVelocity ?? 0) > 700) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _isReturning = true;
      _dismissOffset = 0;
    });
  }

  void _showMenu() {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (sheetContext) => TritiumGlassSheet(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: Theme.of(
                    sheetContext,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const ListTile(
                leading: Icon(Icons.image_outlined),
                title: Text(
                  '图片操作',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.share_rounded),
                title: const Text('分享图片'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _shareImage(_currentUrl);
                },
              ),
              ListTile(
                leading: const Icon(Icons.save_alt_rounded),
                title: const Text('保存到相册'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _saveImage(_currentUrl);
                },
              ),
              ListTile(
                leading: const Icon(Icons.link_rounded),
                title: const Text('复制图片链接'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: _currentUrl));
                  Navigator.pop(sheetContext);
                  Get.snackbar('已复制', '图片链接已复制');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveImage(String imageUrl) async {
    try {
      final bytes = await _downloadImage(imageUrl);
      if (bytes == null) throw StateError('empty image');
      await Gal.putImageBytes(
        Uint8List.fromList(bytes),
        name: 'tritium_${DateTime.now().millisecondsSinceEpoch}',
      );
      Get.snackbar('保存成功', '图片已保存到系统相册');
    } catch (_) {
      Get.snackbar('保存失败', '请检查相册权限或网络连接');
    }
  }

  Future<void> _shareImage(String imageUrl) async {
    try {
      final bytes = await _downloadImage(imageUrl);
      if (bytes == null) throw StateError('empty image');
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/tritium_${imageUrl.hashCode}.jpg');
      await file.writeAsBytes(bytes, flush: true);
      await Share.shareXFiles([XFile(file.path)]);
    } catch (_) {
      Get.snackbar('分享失败', '无法准备图片文件');
    }
  }

  Future<Uint8List?> _downloadImage(String imageUrl) async {
    final response = await Dio().get<List<int>>(
      imageUrl,
      options: Options(
        responseType: ResponseType.bytes,
        headers: const {'Referer': 'https://www.zhihu.com/'},
      ),
    );
    final bytes = response.data;
    return bytes == null ? null : Uint8List.fromList(bytes);
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final progress = (_dismissOffset / screenHeight).clamp(0.0, 1.0);
    final scale = 1 - progress * 0.14;
    final backgroundOpacity = 1 - progress * 0.75;
    final topPadding = MediaQuery.paddingOf(context).top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: ColoredBox(
          color: Colors.black.withValues(alpha: backgroundOpacity),
          child: Stack(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragUpdate: _isZoomed ? null : _onVerticalDragUpdate,
                onVerticalDragEnd: _isZoomed ? null : _onVerticalDragEnd,
                child: AnimatedContainer(
                  duration: _isReturning
                      ? const Duration(milliseconds: 220)
                      : Duration.zero,
                  curve: Curves.easeOutCubic,
                  transform: Matrix4.identity()
                    ..translateByDouble(0, _dismissOffset, 0, 1)
                    ..scaleByDouble(scale, scale, 1, 1),
                  transformAlignment: Alignment.center,
                  child: PageView.builder(
                    controller: _pageController,
                    physics: _isZoomed
                        ? const NeverScrollableScrollPhysics()
                        : const PageScrollPhysics(),
                    itemCount: widget.imageUrls.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentIndex = index;
                        _isZoomed = false;
                        _transformationController.value = Matrix4.identity();
                      });
                    },
                    itemBuilder: (context, index) {
                      final url = widget.imageUrls[index];
                      return _ZoomableGalleryImage(
                        key: ValueKey(url),
                        imageUrl: url,
                        transformationController: _transformationController,
                        zoomed: _isZoomed,
                        onTap: () => Navigator.of(context).pop(),
                        onLongPress: _showMenu,
                        onDoubleTapDown: (position) =>
                            _doubleTapPosition = position,
                        onDoubleTap: () =>
                            _onImageDoubleTap(_doubleTapPosition),
                        onInteractionUpdate: _onImageInteractionUpdate,
                        onInteractionEnd: _onImageInteractionEnd,
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                top: topPadding + 12,
                left: 16,
                right: 16,
                child: IgnorePointer(
                  ignoring: _isZoomed,
                  child: AnimatedOpacity(
                    opacity: _isZoomed ? 0 : 1,
                    duration: const Duration(milliseconds: 180),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (widget.imageUrls.length > 1)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              '${_currentIndex + 1} / ${widget.imageUrls.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton.filledTonal(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                            color: Colors.white,
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.15,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ZoomableGalleryImage extends StatelessWidget {
  final String imageUrl;
  final TransformationController transformationController;
  final bool zoomed;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final ValueChanged<Offset> onDoubleTapDown;
  final VoidCallback onDoubleTap;
  final ValueChanged<ScaleUpdateDetails> onInteractionUpdate;
  final ValueChanged<ScaleEndDetails> onInteractionEnd;

  const _ZoomableGalleryImage({
    super.key,
    required this.imageUrl,
    required this.transformationController,
    required this.zoomed,
    required this.onTap,
    required this.onLongPress,
    required this.onDoubleTapDown,
    required this.onDoubleTap,
    required this.onInteractionUpdate,
    required this.onInteractionEnd,
  });

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = (MediaQuery.sizeOf(context).width * dpr).round().clamp(
      1,
      4096,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      onDoubleTapDown: (details) => onDoubleTapDown(details.localPosition),
      onDoubleTap: onDoubleTap,
      child: InteractiveViewer(
        transformationController: transformationController,
        minScale: 1,
        maxScale: 5,
        panEnabled: zoomed,
        clipBehavior: Clip.none,
        onInteractionUpdate: onInteractionUpdate,
        onInteractionEnd: onInteractionEnd,
        child: Center(
          child: Hero(
            tag: imageUrl,
            child: SizedBox.expand(
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                httpHeaders: const {'Referer': 'https://www.zhihu.com/'},
                memCacheWidth: cacheWidth,
                maxWidthDiskCache: cacheWidth * 2,
                fadeInDuration: const Duration(milliseconds: 250),
                fadeOutDuration: const Duration(milliseconds: 80),
                placeholder: (context, url) => const Center(
                  child: SizedBox.square(
                    dimension: 40,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white70,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.broken_image_rounded,
                        color: Colors.white70,
                        size: 42,
                      ),
                      SizedBox(height: 8),
                      Text('加载失败', style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
