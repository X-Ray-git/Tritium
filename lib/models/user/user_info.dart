/// 用户信息模型
class UserInfo {
  final String id;
  final String urlToken;
  final String name;
  final String? headline;
  final String? avatarUrl;
  final String? avatarUrlTemplate;

  UserInfo({
    required this.id,
    required this.urlToken,
    required this.name,
    this.headline,
    this.avatarUrl,
    this.avatarUrlTemplate,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      id: json['id']?.toString() ?? '',
      urlToken: json['url_token'] ?? '',
      name: json['name'] ?? '',
      headline: json['headline'],
      avatarUrl: json['avatar_url'],
      avatarUrlTemplate: json['avatar_url_template'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url_token': urlToken,
      'name': name,
      'headline': headline,
      'avatar_url': avatarUrl,
      'avatar_url_template': avatarUrlTemplate,
    };
  }

  /// 获取头像 URL
  String get avatar {
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return avatarUrl!;
    }
    if (avatarUrlTemplate != null && avatarUrlTemplate!.isNotEmpty) {
      return avatarUrlTemplate!.replaceAll('{size}', 'xl');
    }
    return '';
  }
}
