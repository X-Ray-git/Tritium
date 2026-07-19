import 'package:flutter_test/flutter_test.dart';
import 'package:tritium/common/theme/theme_utils.dart';

void main() {
  test('light and dark themes use the Tritium brand color', () {
    expect(ThemeUtils.light().colorScheme.primary, TritiumColors.brand);
    expect(ThemeUtils.dark().colorScheme.primary, TritiumColors.brand);
    expect(TritiumColors.brand.toARGB32(), 0xFF3961FF);
  });
}
