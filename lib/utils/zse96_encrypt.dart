import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// 知乎 zse96 签名算法
/// 移植自 Hydrogen 项目的 zse96_encrypt.lua
class Zse96Encrypt {
  Zse96Encrypt._();

  // 加密密钥（对应 Lua 的 key_pad）
  static const List<int> _keyPad = [48, 53, 57, 48, 53, 51, 102, 55, 100, 49, 53, 101, 48, 49, 100, 55];

  // 自定义 Base64 字符表
  static const String _base64Chars = "6fpLRqJO8M/c3jnYxFkUVC4ZIG12SiH=5v0mXDazWBTsuw7QetbKdoPyAl+hN9rgE";

  // 映射表 zk
  static const List<int> _zkMapping = [
    0x45C16D72, 0x3D10851E, 0x5443B62F, 0xEB858940, 0xD26C8EAE, 0xAE321C1E, 0xF77A7478, 0xEE52F3E3,
    0x73477F5A, 0xC6135A3B, 0xE7C8E07A, 0x1B712186, 0xDF6A4E7A, 0x8F128CFA, 0x9BFAFB63, 0x7E5F5A54,
    0x872E453B, 0x7950FDCC, 0xA5866F7A, 0xFFA9AE79, 0xFB60A6A3, 0x8357F1E3, 0xB5EB71FA, 0x5E1F35EF,
    0x4EBB3172, 0x1B3CC7F4, 0xAD0B9B2F, 0xF23E4FDF, 0x13A930E6, 0xD0F93A1E, 0x15A9FA1D, 0x8BD43AFC
  ];

  // 映射表 zb（S-box）
  static const List<int> _zbMapping = [
    20, 223, 245, 7, 248, 2, 194, 209, 87, 6, 227, 253, 240, 128, 222, 91,
    237, 9, 125, 157, 230, 93, 252, 205, 90, 79, 144, 199, 159, 197, 186, 167,
    39, 37, 156, 198, 38, 42, 43, 168, 217, 153, 15, 103, 80, 189, 71, 191,
    97, 84, 247, 95, 36, 69, 14, 35, 12, 171, 28, 114, 178, 148, 86, 182,
    32, 83, 158, 109, 22, 255, 94, 238, 151, 85, 77, 124, 254, 18, 4, 26,
    123, 176, 232, 193, 131, 172, 143, 142, 150, 30, 10, 146, 162, 62, 224, 218,
    196, 229, 1, 192, 213, 27, 110, 56, 231, 180, 138, 107, 242, 187, 54, 120,
    19, 44, 117, 228, 215, 203, 53, 239, 251, 127, 81, 11, 133, 96, 204, 132,
    41, 115, 73, 55, 249, 147, 102, 48, 122, 145, 106, 118, 74, 190, 29, 16,
    174, 5, 177, 129, 63, 113, 99, 31, 161, 76, 246, 34, 211, 13, 60, 68,
    207, 160, 65, 111, 82, 165, 67, 169, 225, 57, 112, 244, 155, 51, 236, 200,
    233, 58, 61, 47, 100, 137, 185, 64, 17, 70, 234, 163, 219, 108, 170, 166,
    59, 149, 52, 105, 24, 212, 78, 173, 45, 0, 116, 226, 119, 136, 206, 135,
    175, 195, 25, 92, 121, 208, 126, 139, 3, 75, 141, 21, 130, 98, 241, 40,
    154, 66, 184, 49, 181, 46, 243, 88, 101, 183, 8, 23, 72, 188, 104, 179,
    210, 134, 250, 201, 164, 89, 216, 202, 220, 50, 221, 152, 140, 33, 235, 214
  ];

  static const String _version = '101_3_3.0';
  static const String _apiVersion = '3.0.91';
  
  /// 生成加密头和重写后的 URL
  /// 按照 Hydrogen 逻辑：将 api.zhihu.com 请求重写到 www.zhihu.com/api/v4
  static ({String rewrittenUrl, Map<String, String> headers}) generateSignHeadersWithUrl({
    required String url,
    String? cookies,
  }) {
    // 1. 获取 d_c0
    String dc0 = '';
    if (cookies != null) {
      final match = RegExp(r'd_c0=([^;]+)').firstMatch(cookies);
      if (match != null) {
        dc0 = match.group(1) ?? '';
        debugPrint('Found d_c0: $dc0');
      } else {
        debugPrint('WARNING: d_c0 not found in cookies');
      }
    }

    // 2. 处理 Path 和 URL 重写（严格按照 Hydrogen zse96_encrypt.lua Line 336-343）
    String path = '';
    String rewrittenUrl = url;
    
    if (url.contains('www.zhihu.com')) {
      // 已经是 www，直接提取 path
      path = url.split('zhihu.com')[1];
    } else if (url.contains('api.zhihu.com')) {
      // 关键！Hydrogen 逻辑：api.zhihu.com 转换到 www.zhihu.com/api/v4
      path = '/api/v4${url.split('zhihu.com')[1]}';
      rewrittenUrl = 'https://www.zhihu.com$path';
      debugPrint('URL Rewrite: $url -> $rewrittenUrl');
    } else {
      // fallback
      try {
        final uri = Uri.parse(url);
        path = uri.toString().substring(uri.origin.length);
      } catch (e) {
        path = url;
      }
    }

    final dataToHash = '$_version+$path+$dc0';
    debugPrint('Zse96 Hash Input: $dataToHash');

    final md5Hex = md5.convert(utf8.encode(dataToHash)).toString().toLowerCase();
    
    // 加密生成签名
    final signature = _b64encode(md5Hex);

    final headers = {
      'x-api-version': _apiVersion,
      'x-zse-93': _version,
      'x-zse-96': '2.0_$signature',
      'x-app-za': 'OS=Web',
    };
    
    return (rewrittenUrl: rewrittenUrl, headers: headers);
  }
  
  /// 兼容旧接口（仅返回 Headers）
  static Map<String, String> generateSignHeaders({
    required String url,
    String? cookies,
  }) {
    return generateSignHeadersWithUrl(url: url, cookies: cookies).headers;
  }


  /// 自定义 Base64 编码
  static String _b64encode(String md5Hex, {int device = 0, int seed = 63}) {
    // 修复：Lua 实现中直接连接了 md5 hex 字符串，并没有将其解析为 16 字节的二进制
    // 所以这里应该使用 md5 hex 字符串的 ASCII 字节（长度 32）
    final md5Bytes = md5Hex.codeUnits;

    // 构建头部
    final header = [seed, device, ...md5Bytes];
    
    // PKCS7 填充
    final padded = _pkcs7Pad(header, 16);
    
    // 分离头部块
    final headerBlock = padded.sublist(0, 16);
    
    // 与 keyPad 异或混淆
    final transformedHeader = List<int>.filled(16, 0);
    for (int i = 0; i < 16; i++) {
      transformedHeader[i] = headerBlock[i] ^ _keyPad[i] ^ 42;
    }
    
    // 变换得到 IV
    final iv = _transformBlock(transformedHeader);
    
    // 处理剩余数据块
    final body = padded.sublist(16);
    final transformedBody = _processBlocks(body, iv);
    
    // 合并 IV 和加密数据
    final combined = [...iv, ...transformedBody];
    
    // 填充到 3 的倍数
    final padCount = (3 - (combined.length % 3)) % 3;
    for (int i = 0; i < padCount; i++) {
      combined.add(0);
    }
    
    // 自定义 Base64 编码
    final result = StringBuffer();
    int shiftCounter = 0;
    
    for (int i = combined.length - 1; i >= 2; i -= 3) {
      final b0 = combined[i] ^ (_unsignedRightShift(58, 8 * (shiftCounter % 4)));
      shiftCounter++;
      final b1 = combined[i - 1] ^ (_unsignedRightShift(58, 8 * (shiftCounter % 4)));
      shiftCounter++;
      final b2 = combined[i - 2] ^ (_unsignedRightShift(58, 8 * (shiftCounter % 4)));
      shiftCounter++;
      
      final num = b0 + (b1 << 8) + (b2 << 16);
      
      result.write(_base64Chars[(num & 63)]);
      result.write(_base64Chars[((num >> 6) & 63)]);
      result.write(_base64Chars[((num >> 12) & 63)]);
      result.write(_base64Chars[((num >> 18) & 63)]);
    }
    
    return result.toString();
  }

  /// PKCS7 填充
  static List<int> _pkcs7Pad(List<int> data, int blockSize) {
    final padLen = blockSize - (data.length % blockSize);
    final padded = [...data];
    for (int i = 0; i < padLen; i++) {
      padded.add(padLen);
    }
    return padded;
  }

  /// 无符号右移
  static int _unsignedRightShift(int x, int shift) {
    shift = shift % 32;
    if (shift == 0) return x & 0xFFFFFFFF;
    return ((x & 0xFFFFFFFF) >> shift);
  }

  /// 位旋转
  static int _rotateXor(int x, int rot) {
    rot = rot % 32;
    x = x & 0xFFFFFFFF;
    return (((x << rot) | (x >> (32 - rot))) & 0xFFFFFFFF);
  }

  /// 转换值
  static int _transformValue(int e) {
    e = e & 0xFFFFFFFF;
    // 打包为 4 字节
    final packed = [
      (e >> 24) & 0xFF,
      (e >> 16) & 0xFF,
      (e >> 8) & 0xFF,
      e & 0xFF,
    ];
    
    // S-box 替换
    final transformed = packed.map((b) => _zbMapping[b]).toList();
    
    // 还原为整数
    int r = (transformed[0] << 24) | (transformed[1] << 16) | (transformed[2] << 8) | transformed[3];
    r = r & 0xFFFFFFFF;
    
    // 多次旋转异或
    final rx2 = _rotateXor(r, 2);
    final rx10 = _rotateXor(r, 10);
    final rx18 = _rotateXor(r, 18);
    final rx24 = _rotateXor(r, 24);
    
    return (r ^ rx2 ^ rx10 ^ rx18 ^ rx24) & 0xFFFFFFFF;
  }

  /// 变换 16 字节块
  static List<int> _transformBlock(List<int> data) {
    // 解包为 4 个 32 位整数
    int w0 = (data[0] << 24) | (data[1] << 16) | (data[2] << 8) | data[3];
    int w1 = (data[4] << 24) | (data[5] << 16) | (data[6] << 8) | data[7];
    int w2 = (data[8] << 24) | (data[9] << 16) | (data[10] << 8) | data[11];
    int w3 = (data[12] << 24) | (data[13] << 16) | (data[14] << 8) | data[15];
    
    final words = <int>[w0, w1, w2, w3];
    
    // 32 轮处理
    for (int r = 0; r < 32; r++) {
      final zkVal = _zkMapping[r];
      final temp = (words[r + 1] ^ words[r + 2] ^ words[r + 3] ^ zkVal) & 0xFFFFFFFF;
      final transformed = _transformValue(temp);
      words.add((words[r] ^ transformed) & 0xFFFFFFFF);
    }
    
    // 取最后 4 个整数（反序）
    final resWords = [words[35], words[34], words[33], words[32]];
    
    // 打包为字节
    final result = <int>[];
    for (final word in resWords) {
      result.add((word >> 24) & 0xFF);
      result.add((word >> 16) & 0xFF);
      result.add((word >> 8) & 0xFF);
      result.add(word & 0xFF);
    }
    
    return result;
  }

  /// 处理数据块
  static List<int> _processBlocks(List<int> data, List<int> iv) {
    final output = <int>[];
    var currentChain = List<int>.from(iv);
    
    // 按 16 字节分块
    for (int i = 0; i < data.length; i += 16) {
      final chunk = <int>[];
      for (int j = 0; j < 16; j++) {
        chunk.add(i + j < data.length ? data[i + j] : 0);
      }
      
      // 异或
      final xored = <int>[];
      for (int j = 0; j < 16; j++) {
        xored.add(chunk[j] ^ currentChain[j]);
      }
      
      // 变换
      currentChain = _transformBlock(xored);
      output.addAll(currentChain);
    }
    
    return output;
  }
}
