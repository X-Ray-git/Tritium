/// 用户信息模型
class UserInfo {
  final String id;
  final String urlToken;
  final String name;
  final String? headline;
  final String? avatarUrl;
  final String? avatarUrlTemplate;
  final String? gender;
  final bool? isFollowing;
  final bool? isFollowed;
  final int? followerCount;
  final int? followingCount;
  final int? answerCount;
  final int? articlesCount;
  final int? thankedCount;
  final int? voteupCount;

  UserInfo({
    required this.id,
    required this.urlToken,
    required this.name,
    this.headline,
    this.avatarUrl,
    this.avatarUrlTemplate,
    this.gender,
    this.isFollowing,
    this.isFollowed,
    this.followerCount,
    this.followingCount,
    this.answerCount,
    this.articlesCount,
    this.thankedCount,
    this.voteupCount,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      id: json['id']?.toString() ?? '',
      urlToken: json['url_token'] ?? '',
      name: json['name'] ?? '',
      headline: json['headline'],
      avatarUrl: json['avatar_url'],
      avatarUrlTemplate: json['avatar_url_template'],
      gender: _parseGender(json['gender']),
      isFollowing: json['is_following'],
      isFollowed: json['is_followed'],
      followerCount: json['follower_count'],
      followingCount: json['following_count'],
      answerCount: json['answer_count'],
      articlesCount: json['articles_count'],
      thankedCount: json['thanked_count'],
      voteupCount: json['voteup_count'],
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
      'gender': gender,
      'is_following': isFollowing,
      'is_followed': isFollowed,
      'follower_count': followerCount,
      'following_count': followingCount,
      'answer_count': answerCount,
      'articles_count': articlesCount,
      'thanked_count': thankedCount,
      'voteup_count': voteupCount,
    };
  }

  static String? _parseGender(dynamic gender) {
    if (gender == null) return null;
    if (gender is int) {
      switch (gender) {
        case 0:
          return '女';
        case 1:
          return '男';
        default:
          return '未知';
      }
    }
    return gender.toString();
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
