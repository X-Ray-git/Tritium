import 'package:flutter/material.dart';

/// 通用容器组件
///
/// 原名 BlurContainer，已移除毛玻璃效果，改为普通容器
class BlurContainer extends StatelessWidget {
  /// 子组件
  final Widget child;

  /// 背景颜色（可选，如果不提供则使用透明背景）
  final Color? backgroundColor;

  /// 圆角半径
  final BorderRadius? borderRadius;

  /// 边框
  final BoxBorder? border;

  /// 外边距
  final EdgeInsetsGeometry? margin;

  /// 内边距
  final EdgeInsetsGeometry? padding;

  /// 是否强制启用毛玻璃效果（已废弃，保留参数兼容）
  final bool forceBlur;

  /// 自定义模糊程度（已废弃，保留参数兼容）
  final double? customBlurIntensity;

  const BlurContainer({
    super.key,
    required this.child,
    this.backgroundColor,
    this.borderRadius,
    this.border,
    this.margin,
    this.padding,
    this.forceBlur = false,
    this.customBlurIntensity,
  });

  @override
  Widget build(BuildContext context) {
    // 移除毛玻璃逻辑，直接使用 Container
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? Theme.of(context).colorScheme.surface,
        borderRadius: borderRadius,
        border: border,
      ),
      child: child,
    );
  }
}

/// 通用 AppBar
///
/// 原名 BlurAppBar，已移除毛玻璃效果
class BlurAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final Widget? leading;
  final List<Widget>? actions;
  final bool automaticallyImplyLeading;
  final double? elevation;
  final bool centerTitle;
  final PreferredSizeWidget? bottom;

  const BlurAppBar({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.automaticallyImplyLeading = true,
    this.elevation,
    this.centerTitle = false,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: title,
      leading: leading,
      actions: actions,
      automaticallyImplyLeading: automaticallyImplyLeading,
      elevation: elevation,
      centerTitle: centerTitle,
      bottom: bottom,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (bottom?.preferredSize.height ?? 0),
      );
}

/// 通用 BottomNavigationBar 容器
///
/// 原名 BlurBottomBar，已移除毛玻璃效果
class BlurBottomBar extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const BlurBottomBar({
    super.key,
    required this.child,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final effectivePadding = padding ?? EdgeInsets.only(
      left: 16,
      right: 16,
      top: 8,
      bottom: 8 + bottomPadding,
    );

    return Container(
      padding: effectivePadding,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: child,
    );
  }
}
