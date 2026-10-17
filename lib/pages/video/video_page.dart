import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';

import '../../services/video_service.dart';

/// A separate route keeps native video surfaces out of the selectable reader.
class VideoPage extends StatefulWidget {
  const VideoPage({super.key});
  @override
  State<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage> with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  CancelToken? _request;
  int _generation = 0;
  String? _error;
  bool _loading = true;
  bool _fullscreen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    _request?.cancel();
    final request = _request = CancelToken();
    final old = _controller;
    _controller = null;
    if (old != null) await old.dispose();
    if (!mounted || generation != _generation) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    VideoPlayerController? controller;
    try {
      final args = Get.arguments;
      final id = args is Map ? args['videoId'] as String? : null;
      if (id == null) throw const FormatException('无效的视频 ID');
      final context = args['context'] as ({String id, String type})?;
      final uri = await VideoService.resolve(
        id,
        context: context,
        cancelToken: request,
      );
      if (!mounted || generation != _generation) return;
      // Never forward the authenticated API client's Cookie to a video CDN.
      controller = VideoPlayerController.networkUrl(uri);
      await controller.initialize().timeout(const Duration(seconds: 25));
      if (!mounted || generation != _generation) {
        await controller.dispose();
        return;
      }
      _controller = controller;
      controller.addListener(_changed);
      setState(() {
        _loading = false;
      });
      // Opening is explicit, but playback stays paused until the user presses play.
    } catch (_) {
      await controller?.dispose();
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _error = '视频加载失败，请检查网络或登录状态后重试';
      });
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _setFullscreen(bool enabled) {
    setState(() => _fullscreen = enabled);
    unawaited(
      SystemChrome.setPreferredOrientations(
        enabled
            ? [
                DeviceOrientation.landscapeLeft,
                DeviceOrientation.landscapeRight,
              ]
            : [],
      ),
    );
    unawaited(
      SystemChrome.setEnabledSystemUIMode(
        enabled ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(_controller?.pause());
  }

  @override
  void dispose() {
    ++_generation;
    _request?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _controller?.removeListener(_changed);
    unawaited(_controller?.dispose());
    if (_fullscreen) {
      unawaited(SystemChrome.setPreferredOrientations([]));
      unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    }
    super.dispose();
  }

  String _time(Duration value) =>
      '${value.inMinutes}:${(value.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final value = controller?.value;
    final error = _error ?? (value?.hasError == true ? '视频播放失败，请重试' : null);
    return PopScope(
      canPop: !_fullscreen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _fullscreen) _setFullscreen(false);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: _fullscreen ? null : AppBar(title: const Text('视频播放')),
        body: SafeArea(
          child: Center(
            child: _loading
                ? const CircularProgressIndicator()
                : error != null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(error, style: const TextStyle(color: Colors.white)),
                      TextButton(onPressed: _load, child: const Text('重新加载')),
                    ],
                  )
                : controller == null
                ? const SizedBox.shrink()
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: value!.aspectRatio > 0
                                ? value.aspectRatio
                                : 16 / 9,
                            child: VideoPlayer(controller),
                          ),
                        ),
                      ),
                      if (value.isBuffering) const LinearProgressIndicator(),
                      VideoProgressIndicator(
                        controller,
                        allowScrubbing: true,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            color: Colors.white,
                            tooltip: value.isPlaying ? '暂停' : '播放',
                            icon: Icon(
                              value.isPlaying ? Icons.pause : Icons.play_arrow,
                            ),
                            onPressed: () async {
                              try {
                                if (value.isPlaying) {
                                  await controller.pause();
                                } else {
                                  if (value.position >= value.duration) {
                                    await controller.seekTo(Duration.zero);
                                  }
                                  if (mounted) await controller.play();
                                }
                              } catch (_) {
                                if (mounted) {
                                  setState(() => _error = '视频播放失败，请重试');
                                }
                              }
                            },
                          ),
                          Text(
                            '${_time(value.position)} / ${_time(value.duration)}',
                            style: const TextStyle(color: Colors.white),
                          ),
                          const Spacer(),
                          IconButton(
                            color: Colors.white,
                            tooltip: _fullscreen ? '退出全屏' : '全屏',
                            onPressed: () => _setFullscreen(!_fullscreen),
                            icon: Icon(
                              _fullscreen
                                  ? Icons.fullscreen_exit
                                  : Icons.fullscreen,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
