import 'package:flutter_test/flutter_test.dart';
import 'package:tritium/models/user/user_info.dart';

void main() {
  test('user info keeps only account identity fields', () {
    final user = UserInfo.fromJson({
      'id': 42,
      'url_token': 'reader',
      'name': '阅读者',
      'headline': '只读账户',
      'avatar_url_template': 'https://example.test/{size}.png',
      'is_following': true,
    });

    expect(user.id, '42');
    expect(user.urlToken, 'reader');
    expect(user.avatar, 'https://example.test/xl.png');
    expect(user.toJson().containsKey('is_following'), isFalse);
  });
}
