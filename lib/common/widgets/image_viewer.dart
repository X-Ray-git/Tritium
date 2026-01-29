import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:gal/gal.dart';

/// 全屏图片查看器
class ImageViewer extends StatelessWidget {
  final String imageUrl;
  final String? heroTag;

  const ImageViewer({
    super.key,
    required this.imageUrl,
    this.heroTag,
  });

  static void show(BuildContext context, String imageUrl, {String? heroTag}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => ImageViewer(
          imageUrl: imageUrl,
          heroTag: heroTag,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      body: GestureDetector(
        onTap: () => Navigator.pop(context), // 单击退出
        onLongPress: () => _showMenu(context),
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Hero(
            tag: heroTag ?? imageUrl,
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              httpHeaders: const {'Referer': 'https://www.zhihu.com/'},
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.contain,
              placeholder: (context, url) => const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
              errorWidget: (context, url, error) => const Icon(
                Icons.error,
                color: Colors.white,
                size: 48,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.save_alt),
              title: const Text('保存图片'),
              onTap: () {
                Navigator.pop(context);
                _saveImage(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveImage(BuildContext context) async {
    try {
      // 检查权限 (特别是 Android < 10)
      // Gal 内部通常会处理，但最好先请求
      // bool hasAccess = await Gal.hasAccess();
      // if (!hasAccess) {
      //   await Gal.requestAccess();
      //   return; // Gal requestAccess usually handles flow? 
      // }
      // Gal 插件可以直接调用，自动处理
      
      Get.showSnackbar(const GetSnackBar(
        message: '正在保存...',
        duration: Duration(seconds: 1),
        snackPosition: SnackPosition.BOTTOM,
      ));

      // 下载图片字节
      final response = await Dio().get(
        imageUrl,
        options: Options(
          responseType: ResponseType.bytes, 
          headers: {'Referer': 'https://www.zhihu.com/'}, // 添加 Referer 防盗链
        ),
      );
      
      // 保存到相册
      await Gal.putImageBytes(
        Uint8List.fromList(response.data),
        name: 'zhihu_${DateTime.now().millisecondsSinceEpoch}',
      );
      
      Get.snackbar(
        '保存成功',
        '图片已保存到系统相册',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      debugPrint('Save Image Error: $e');
      if (e is GalException) {
         String msg = '保存失败';
         if (e.type == GalExceptionType.accessDenied) {
           msg = '请授予存储权限';
         } else {
           msg = '保存异常: ${e.type}';
         }
         Get.snackbar(
          '保存失败',
          msg,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16),
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      } else {
        Get.snackbar(
          '保存失败',
          '下载或保存出错',
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16),
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
  }
}
