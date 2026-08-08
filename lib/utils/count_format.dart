/// 可空统计值解析与格式化。
///
/// 知乎接口的统计字段可能缺失、为字符串或无法解析。未知值必须保持为 null 并显示
/// “—”，绝不能伪装成真实的 0；只有接口明确返回的有效数值才参与格式化。
library;

/// 解析统计值。字段缺失、类型非法或无法解析时返回 null。
int? parseCount(dynamic value) {
  if (value == null) return null;
  if (value is int) return value >= 0 ? value : null;
  if (value is num) {
    final number = value.toDouble();
    if (!number.isFinite || number < 0) return null;
    return number.toInt();
  }
  final text = value.toString().trim();
  if (text.isEmpty) return null;
  final parsed = int.tryParse(text);
  if (parsed == null) return null;
  return parsed >= 0 ? parsed : null;
}

/// 在 [primary] 与 [fallback] 之间取第一个有效数值。
///
/// 用于 `visit_count` 优先、`read_count` 兜底的场景；两者都无效时返回 null。
int? firstValidCount(dynamic primary, dynamic fallback) {
  return parseCount(primary) ?? parseCount(fallback);
}

/// 格式化统计值。null（未知/未加载）显示 “—”，其余按万/k 缩写。
String formatCount(dynamic value) {
  final count = parseCount(value);
  if (count == null) return '—';
  if (count >= 10000) {
    return '${(count / 10000).toStringAsFixed(1)}万';
  }
  if (count >= 1000) {
    return '${(count / 1000).toStringAsFixed(1)}k';
  }
  return count.toString();
}
