<p align="center">
  <img src="assets/images/logo/icon.jpg" width="120" alt="Tritium Logo">
</p>

# Tritium

[![License](https://img.shields.io/github/license/X-Ray-git/Tritium)](LICENSE)

Tritium 是一个使用 Flutter 开发的知乎第三方 Android 客户端。

## ✨ 功能特性

- 📱 浏览推荐、热榜内容
- 📖 阅读问题、回答、文章、想法
- 💬 查看评论区
- 👤 查看用户主页
- 🎨 支持 Material You 动态取色
- 🌙 支持深色模式
- ⚡ 支持高刷新率

## 📦 安装

从 [Releases](../../releases) 页面下载最新版本的 APK 文件安装即可。

## 🛠️ 构建

### 环境要求

- Flutter SDK 3.10.0 或更高版本
- Android SDK
- JDK 17

### 构建步骤

```bash
# 克隆项目
git clone https://github.com/X-Ray-git/Tritium.git
cd Tritium

# 获取依赖
flutter pub get

# 构建 APK
flutter build apk --release
```

构建产物位于 `build/app/outputs/flutter-apk/app-release.apk`

## 🙏 致谢

- [Hydrogen](https://github.com/zhihulite/Hydrogen) - 本项目的 API 接口实现参考了 Hydrogen 项目

## 📄 许可证

本项目采用 [MIT License](LICENSE) 开源许可证。
