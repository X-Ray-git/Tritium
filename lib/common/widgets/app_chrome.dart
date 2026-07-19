import 'dart:ui';

import 'package:flutter/material.dart';

const tritiumMobileToolbarHeight = 48.0;

/// 只在少量固定表面使用模糊，避免长列表重复 BackdropFilter。
class TritiumBlurAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final Widget? leading;
  final double? leadingWidth;
  final List<Widget>? actions;
  final bool centerTitle;

  const TritiumBlurAppBar({
    super.key,
    this.title,
    this.leading,
    this.leadingWidth,
    this.actions,
    this.centerTitle = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(tritiumMobileToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AppBar(
      title: title,
      leading: leading,
      leadingWidth: leadingWidth,
      actions: actions,
      centerTitle: centerTitle,
      toolbarHeight: tritiumMobileToolbarHeight,
      backgroundColor: colors.surface.withValues(alpha: 0.76),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class TritiumPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const TritiumPanel({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fill = colors.onSurface.withValues(alpha: dark ? 0.035 : 0.024);
    return Material(
      color: Color.alphaBlend(fill, colors.surface),
      shape: RoundedSuperellipseBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: colors.outlineVariant.withValues(alpha: dark ? 0.34 : 0.28),
          width: 0.8,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class TritiumGlassSheet extends StatelessWidget {
  final Widget child;

  const TritiumGlassSheet({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(8, 0, 8, bottom + 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surface.withValues(alpha: 0.90),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: colors.outlineVariant.withValues(alpha: 0.42),
                width: 0.8,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
