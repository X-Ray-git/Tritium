<p align="center">
  <img src="assets/images/logo/icon.jpg" width="120" alt="Tritium Logo">
</p>

# Tritium

[![License](https://img.shields.io/github/license/X-Ray-git/Tritium)](LICENSE)

Tritium 是一个专注阅读体验的非官方知乎 Android 客户端，使用 Flutter 开发。

## 功能范围

- 浏览推荐和热榜，阅读问题、回答、文章与想法
- 查看评论、回复数量、点赞数量和用户公开资料
- 知乎内容链接在应用内跳转，外部链接和视频交给系统浏览器
- 推荐、热榜与设置主导航，支持浅色、深色及跟随系统
- 固定使用 Tritium 品牌色 `RGB(57, 97, 255)` / `#3961FF`
- 支持高刷新率显示模式

Tritium 当前定位为只读客户端，不提供点赞、关注、回复、收藏、私信或 AI 功能。

## 构建

环境要求：Flutter 3.44.6、Android SDK、JDK 17。

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

未配置签名时，本地 release 构建会使用 debug 签名，仅供开发验证。正式发布需按
[发布说明](docs/operations/release-build.md) 配置签名。

构建产物位于 `build/app/outputs/flutter-apk/app-release.apk`。

## 工程文档

- [维护知识库](docs/README.md)
- [架构概览](docs/architecture/overview.md)
- [Android 设计语言](docs/design/android.md)
- [发布与签名](docs/operations/release-build.md)
- [当前状态](docs/status/current.md)
- [真机验收清单](docs/status/device-acceptance.md)

## 参考与致谢

- Hydrogen：功能模块、接口与分页处理思路参考
- Auto Folo：设计语言、维护文档和发布流程参考

参考工程只用于理解设计和架构，Tritium 保持独立实现。

## 许可证

本项目采用 [MIT License](LICENSE) 开源许可证。
