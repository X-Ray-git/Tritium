import 'package:flutter/material.dart';

/// 主题颜色类型枚举
enum ThemeColorType {
  zhihuBlue('知乎蓝', Color(0xFF0066FF)),
  blue('默认蓝', Color(0xFF2196F3)),
  indigo('靛蓝', Color(0xFF3F51B5)),
  purple('紫色', Color(0xFF9C27B0)),
  pink('粉色', Color(0xFFE91E63)),
  red('红色', Color(0xFFF44336)),
  orange('橙色', Color(0xFFFF9800)),
  amber('琥珀', Color(0xFFFFC107)),
  green('绿色', Color(0xFF4CAF50)),
  teal('青色', Color(0xFF009688)),
  cyan('蓝绿', Color(0xFF00BCD4));

  final String label;
  final Color color;

  const ThemeColorType(this.label, this.color);
}

/// 获取所有主题颜色类型列表
List<ThemeColorType> get themeColorTypes => ThemeColorType.values;
