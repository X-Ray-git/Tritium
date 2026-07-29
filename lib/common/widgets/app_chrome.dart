import 'dart:math' as math;
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
  final Widget? bottom;

  const TritiumBlurAppBar({
    super.key,
    this.title,
    this.leading,
    this.leadingWidth,
    this.actions,
    this.centerTitle = true,
    this.bottom,
  });

  @override
  Size get preferredSize =>
      Size.fromHeight(tritiumMobileToolbarHeight + (bottom == null ? 0 : 1));

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
      bottom: bottom == null
          ? null
          : PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: bottom!,
            ),
    );
  }
}

/// 与固定顶栏共享尺寸和材质的 Sliver 版本。
///
/// 详情页使用 pinned 而不是 floating/snap，避免快速反向滚动时顶栏反复
/// 进入吸附动画，造成标题弹跳。
class TritiumSliverAppBar extends StatelessWidget {
  final Widget? title;
  final Widget? leading;
  final List<Widget>? actions;
  final bool centerTitle;
  final Widget? bottom;

  const TritiumSliverAppBar({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.centerTitle = true,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SliverAppBar(
      pinned: true,
      floating: false,
      snap: false,
      title: title,
      leading: leading,
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
      bottom: bottom == null
          ? null
          : PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: bottom!,
            ),
    );
  }
}

/// Auto Folo 移动端导航栏使用的原生模糊玻璃表面。
class TritiumGlassNavigationSurface extends StatelessWidget {
  final Widget child;
  final double radius;

  const TritiumGlassNavigationSurface({
    super.key,
    required this.child,
    this.radius = 28,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final baseTint = dark
        ? Color.lerp(colors.surfaceContainerHighest, colors.scrim, 0.18)!
        : const Color(0xFFD2DCF0);
    final topTint = dark
        ? Color.lerp(baseTint, colors.onSurface, 0.10)!
        : const Color(0xFFF7FAFF);
    final bottomTint = dark
        ? Color.lerp(baseTint, colors.scrim, 0.22)!
        : const Color(0xFFE7EDF7);

    return CustomPaint(
      painter: _NavigationGlassShadowPainter(radius: radius, dark: dark),
      child: ClipPath(
        clipper: _NavigationShapeClipper(radius),
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: const SizedBox.expand(),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    topTint.withValues(alpha: dark ? 0.30 : 0.24),
                    baseTint.withValues(alpha: dark ? 0.24 : 0.20),
                    bottomTint.withValues(alpha: dark ? 0.28 : 0.21),
                  ],
                  stops: const [0, 0.54, 1],
                ),
              ),
              child: child,
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _NavigationRimPainter(
                    radius: radius,
                    lightIntensity: dark ? 0.28 : 0.34,
                    ambientStrength: dark ? 0.05 : 0.07,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavigationShapeClipper extends CustomClipper<Path> {
  final double radius;

  const _NavigationShapeClipper(this.radius);

  @override
  Path getClip(Size size) => RoundedSuperellipseBorder(
    borderRadius: BorderRadius.circular(radius),
  ).getOuterPath(Offset.zero & size);

  @override
  bool shouldReclip(covariant _NavigationShapeClipper oldClipper) {
    return radius != oldClipper.radius;
  }
}

Path tritiumContinuousRectanglePath(Rect rect, double radius) {
  return RoundedSuperellipseBorder(
    borderRadius: BorderRadius.circular(radius),
  ).getOuterPath(rect);
}

class TritiumNavigationOuterShadowPainter extends CustomPainter {
  final bool dark;

  const TritiumNavigationOuterShadowPainter({required this.dark});

  @override
  void paint(Canvas canvas, Size size) {
    final path = tritiumContinuousRectanglePath(Offset.zero & size, 28);
    final outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect((Offset.zero & size).inflate(32))
      ..addPath(path, Offset.zero);
    canvas.save();
    canvas.clipPath(outside);
    canvas.drawPath(
      path.shift(const Offset(0, 4)),
      Paint()
        ..color = Colors.black.withValues(alpha: dark ? 0.46 : 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    canvas.drawPath(
      path.shift(const Offset(0, 1)),
      Paint()
        ..color = Colors.black.withValues(alpha: dark ? 0.28 : 0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(
    covariant TritiumNavigationOuterShadowPainter oldDelegate,
  ) {
    return dark != oldDelegate.dark;
  }
}

class _NavigationGlassShadowPainter extends CustomPainter {
  final double radius;
  final bool dark;

  const _NavigationGlassShadowPainter({
    required this.radius,
    required this.dark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = tritiumContinuousRectanglePath(Offset.zero & size, radius);
    canvas.drawPath(
      path.shift(Offset(0, dark ? 6 : 2)),
      Paint()
        ..color = Colors.black.withValues(alpha: dark ? 0.22 : 0.06)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, dark ? 18 : 8),
    );
    canvas.drawPath(
      path.shift(const Offset(0, 1)),
      Paint()
        ..color = Colors.black.withValues(alpha: dark ? 0.14 : 0.035)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
  }

  @override
  bool shouldRepaint(covariant _NavigationGlassShadowPainter oldDelegate) {
    return radius != oldDelegate.radius || dark != oldDelegate.dark;
  }
}

class _NavigationRimPainter extends CustomPainter {
  static const _lightAngle = 0.75 * math.pi;

  final double radius;
  final double lightIntensity;
  final double ambientStrength;
  final Color color;

  const _NavigationRimPainter({
    required this.radius,
    required this.lightIntensity,
    required this.ambientStrength,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final intensity = lightIntensity.clamp(0.0, 1.0);
    if (intensity == 0) return;

    final bounds = Offset.zero & size;
    final squareBounds = Rect.fromCircle(
      center: bounds.center,
      radius: bounds.size.longestSide / 2,
    );
    final rimColor = color.withValues(
      alpha: Curves.easeOut.transform(intensity) * 0.68,
    );
    final x = math.cos(_lightAngle);
    final y = -math.sin(_lightAngle);
    final lightCoverage = 0.3 + (0.5 - 0.3) * intensity;
    final shader = LinearGradient(
      colors: [
        rimColor,
        rimColor.withValues(alpha: ambientStrength),
        rimColor.withValues(alpha: ambientStrength),
        rimColor,
      ],
      stops: [0, lightCoverage, 1 - lightCoverage, 1],
      begin: Alignment(x, y),
      end: Alignment(-x, -y),
    ).createShader(squareBounds);
    final path = tritiumContinuousRectanglePath(
      bounds.deflate(0.75),
      (radius - 0.5).clamp(0.0, double.infinity),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: intensity * 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = shader
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = shader
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.35,
    );
  }

  @override
  bool shouldRepaint(covariant _NavigationRimPainter oldDelegate) {
    return radius != oldDelegate.radius ||
        lightIntensity != oldDelegate.lightIntensity ||
        ambientStrength != oldDelegate.ambientStrength ||
        color != oldDelegate.color;
  }
}

/// 详情页顶栏的小号栏目标题，与 Auto Folo 的移动端文章栏一致。
class TritiumSectionTitle extends StatelessWidget {
  final String text;

  const TritiumSectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        letterSpacing: 2,
        color: colors.onSurfaceVariant.withValues(alpha: 0.8),
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
