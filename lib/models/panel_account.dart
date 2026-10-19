/// 面板账号模型（ckbox 唯一新增功能的核心数据）。
///
/// 对应「面板账号体系」：本地存储多个面板账号，每个账号关联一个订阅 URL。
/// 面板接口契约见 ckbox-spec/ckbox-面板接口深读.md。
///
/// 注意：与 Profile 不同，本模型不使用 freezed/json_serializable 代码生成，
/// 以便在无 build_runner 环境下也能独立编译。
class PanelAccount {
  /// 本地唯一 id（创建时间戳字符串）。
  final String id;

  /// 面板地址，如 https://panel.example.com（不含尾部斜杠）。
  final String panelUrl;

  /// 登录邮箱。
  final String email;

  /// 鉴权数据。
  /// - Xboard：`Bearer <sanctum_token>`（带 Bearer 前缀）
  /// - v2board：原生 JWT（无前缀）
  final String authData;

  /// 是否 Xboard 鉴权（true=Sanctum/Bearer，false=v2board JWT）。
  final bool isXboard;

  /// 订阅 token（用户表 token 字段，GUID），用于 URL 订阅。
  final String subscribeToken;

  /// 完整订阅 URL（面板 getSubscribe 返回）。
  final String subscribeUrl;

  /// 到期时间戳（秒，null=长期有效），来自 subscription-userinfo。
  final int? expireAt;

  /// 流量总量（字节，null=未知）。
  final int? totalTraffic;

  /// 已用上行（字节）。
  final int? upload;

  /// 已用下行（字节）。
  final int? download;

  /// 是否为当前活跃账号（多账号切换）。
  final bool isActive;

  /// 凭据已失效，需要用户重新登录。
  final bool needsRelogin;

  /// 上次刷新订阅信息的时间（毫秒时间戳，null=从未刷新）。
  final int? lastRefreshAt;

  const PanelAccount({
    required this.id,
    required this.panelUrl,
    required this.email,
    required this.authData,
    required this.isXboard,
    required this.subscribeToken,
    required this.subscribeUrl,
    this.expireAt,
    this.totalTraffic,
    this.upload,
    this.download,
    this.isActive = false,
    this.needsRelogin = false,
    this.lastRefreshAt,
  });

  /// 已用总流量（字节）。
  int get usedTraffic => (upload ?? 0) + (download ?? 0);

  /// 是否长期有效（无到期时间）。
  bool get isUnlimited => expireAt == null;

  Map<String, Object?> toJson() => {
        'id': id,
        'panelUrl': panelUrl,
        'email': email,
        'authData': authData,
        'isXboard': isXboard,
        'subscribeToken': subscribeToken,
        'subscribeUrl': subscribeUrl,
        'expireAt': expireAt,
        'totalTraffic': totalTraffic,
        'upload': upload,
        'download': download,
        'isActive': isActive,
        'needsRelogin': needsRelogin,
        'lastRefreshAt': lastRefreshAt,
      };

  factory PanelAccount.fromJson(Map<String, Object?> json) {
    int? intOf(Object? value) => value is num
        ? value.toInt()
        : (value is String ? int.tryParse(value) : null);
    return PanelAccount(
      id: json['id'] as String? ?? '',
      panelUrl: json['panelUrl'] as String? ?? '',
      email: json['email'] as String? ?? '',
      authData: json['authData'] as String? ?? '',
      isXboard: json['isXboard'] == true,
      subscribeToken: json['subscribeToken'] as String? ?? '',
      subscribeUrl: json['subscribeUrl'] as String? ?? '',
      expireAt: intOf(json['expireAt']),
      totalTraffic: intOf(json['totalTraffic']),
      upload: intOf(json['upload']),
      download: intOf(json['download']),
      isActive: json['isActive'] == true,
      needsRelogin: json['needsRelogin'] == true,
      lastRefreshAt: intOf(json['lastRefreshAt']),
    );
  }

  PanelAccount copyWith({
    String? authData,
    bool? isXboard,
    String? subscribeToken,
    String? subscribeUrl,
    int? expireAt,
    int? totalTraffic,
    int? upload,
    int? download,
    bool? isActive,
    bool? needsRelogin,
    int? lastRefreshAt,
    bool clearExpireAt = false,
  }) {
    return PanelAccount(
      id: id,
      panelUrl: panelUrl,
      email: email,
      authData: authData ?? this.authData,
      isXboard: isXboard ?? this.isXboard,
      subscribeToken: subscribeToken ?? this.subscribeToken,
      subscribeUrl: subscribeUrl ?? this.subscribeUrl,
      expireAt: clearExpireAt ? null : (expireAt ?? this.expireAt),
      totalTraffic: totalTraffic ?? this.totalTraffic,
      upload: upload ?? this.upload,
      download: download ?? this.download,
      isActive: isActive ?? this.isActive,
      needsRelogin: needsRelogin ?? this.needsRelogin,
      lastRefreshAt: lastRefreshAt ?? this.lastRefreshAt,
    );
  }
}
