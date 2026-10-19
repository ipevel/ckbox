import 'dart:convert';

import 'package:dio/dio.dart';

/// 面板登录结果。
class PanelLoginResult {
  /// 订阅 token（用户表 token 字段，GUID），用于 URL 订阅。
  final String token;

  /// 鉴权数据（Xboard：`Bearer <sanctum>`；v2board：裸 JWT）。
  final String authData;

  final bool isAdmin;

  /// 是否 Xboard 鉴权（true=Sanctum/Bearer，false=v2board JWT）。
  final bool isXboard;

  const PanelLoginResult({
    required this.token,
    required this.authData,
    required this.isAdmin,
    required this.isXboard,
  });
}

/// 面板订阅信息（getSubscribe 响应）。
class PanelSubscribeInfo {
  final String subscribeUrl;
  final String? subscribeToken;
  final int? expireAt;
  final int? transferEnable;
  final int? upload;
  final int? download;
  final Map<String, Object?>? plan;

  const PanelSubscribeInfo({
    required this.subscribeUrl,
    this.subscribeToken,
    this.expireAt,
    this.transferEnable,
    this.upload,
    this.download,
    this.plan,
  });
}

/// 面板用户信息（user/info 响应）。
class PanelUserInfo {
  final String email;
  final int? transferEnable;
  final int? expireAt;
  final int? createdAt;
  final int? lastLoginAt;
  final int? balance;
  final int? commissionBalance;
  final int? planId;
  final double? discount;
  final double? commissionRate;
  final String? uuid;
  final String? avatarUrl;
  final bool banned;

  const PanelUserInfo({
    required this.email,
    this.transferEnable,
    this.expireAt,
    this.createdAt,
    this.lastLoginAt,
    this.balance,
    this.commissionBalance,
    this.planId,
    this.discount,
    this.commissionRate,
    this.uuid,
    this.avatarUrl,
    this.banned = false,
  });
}

/// 面板 API 客户端。
///
/// 实现 ckbox 面板账号体系依赖的接口，自动探测
/// Xboard（Sanctum）与 v2board（JWT）两种鉴权。
/// 契约依据：ckbox-spec/ckbox-面板接口深读.md 与 ckbox-spec/ckbox-面板契约-*.md。
class PanelClient {
  final Dio _dio;

  PanelClient()
      : _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
          headers: {
            // ckbox 作为订阅客户端标识；面板据此 + flag 参数返回 Clash YAML
            'User-Agent': 'ckbox',
            'Accept': 'application/json',
          },
        ));

  /// 鉴权类型探测：Xboard 的 auth_data 带 `Bearer ` 前缀，v2board 是裸 JWT。
  static bool detectIsXboard(String authData) =>
      authData.startsWith('Bearer ');

  /// 规范化面板地址：去尾部斜杠。
  static String normalizePanelUrl(String url) {
    var u = url.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }

  /// 登录：POST {panel}/api/v1/passport/auth/login
  ///
  /// 失败时抛 [PanelApiException]（两面板登录失败返回 HTTP 500 而非 4xx）。
  Future<PanelLoginResult> login({
    required String panelUrl,
    required String email,
    required String password,
  }) async {
    final url = '${normalizePanelUrl(panelUrl)}/api/v1/passport/auth/login';
    try {
      final resp = await _dio.post<Object?>(
        url,
        data: {'email': email, 'password': password},
      );
      final data = _extractData(resp);
      final authData = data['auth_data'] as String? ?? '';
      final token = data['token'] as String? ?? '';
      if (authData.isEmpty) {
        throw const PanelApiException(
          '登录响应缺少 auth_data（面板可能不是 Xboard/v2board）',
        );
      }
      return PanelLoginResult(
        token: token,
        authData: authData,
        isAdmin: data['is_admin'] == true,
        isXboard: detectIsXboard(authData),
      );
    } on DioException catch (e) {
      throw _toPanelException(e);
    }
  }

  /// 获取订阅信息：GET {panel}/api/v1/user/getSubscribe
  Future<PanelSubscribeInfo> getSubscribe({
    required String panelUrl,
    required String authData,
  }) async {
    final url = '${normalizePanelUrl(panelUrl)}/api/v1/user/getSubscribe';
    final data = await _getData(url, authData);
    final subscribeUrl = data['subscribe_url'] as String? ?? '';
    if (subscribeUrl.isEmpty) {
      throw const PanelApiException('getSubscribe 响应缺少 subscribe_url');
    }
    return PanelSubscribeInfo(
      subscribeUrl: subscribeUrl,
      subscribeToken: data['token'] as String?,
      expireAt: _asInt(data['expired_at']),
      transferEnable: _asInt(data['transfer_enable']),
      upload: _asInt(data['u']),
      download: _asInt(data['d']),
      plan: data['plan'] is Map
          ? Map<String, Object?>.from(data['plan'] as Map)
          : null,
    );
  }

  /// 用户信息：GET {panel}/api/v1/user/info
  Future<PanelUserInfo> getUserInfo({
    required String panelUrl,
    required String authData,
  }) async {
    final url = '${normalizePanelUrl(panelUrl)}/api/v1/user/info';
    final data = await _getData(url, authData);
    return PanelUserInfo(
      email: data['email'] as String? ?? '',
      transferEnable: _asInt(data['transfer_enable']),
      expireAt: _asInt(data['expired_at']),
      createdAt: _asInt(data['created_at']),
      lastLoginAt: _asInt(data['last_login_at']),
      balance: _asInt(data['balance']),
      commissionBalance: _asInt(data['commission_balance']),
      planId: _asInt(data['plan_id']),
      discount: _asDouble(data['discount']),
      commissionRate: _asDouble(data['commission_rate']),
      uuid: data['uuid'] as String?,
      avatarUrl: data['avatar_url'] as String?,
      banned: data['banned'] == true,
    );
  }

  /// 带鉴权头的 GET，返回响应体里的 data 对象。
  Future<Map<String, Object?>> _getData(String url, String authData) async {
    try {
      final resp = await _dio.get<Object?>(
        url,
        options: Options(headers: _authHeaders(authData)),
      );
      return _extractData(resp);
    } on DioException catch (e) {
      throw _toPanelException(e);
    }
  }

  /// 鉴权头：authData 直接作为 Authorization 值。
  /// Xboard 已带 `Bearer ` 前缀；v2board 裸 JWT 也被其 User 中间件接受。
  Map<String, String> _authHeaders(String authData) =>
      {'Authorization': authData};

  /// 从响应中提取 data 字段。
  /// 兼容 Xboard `{status,message,data,error}` 与 v2board `{data}` 两种形状。
  Map<String, Object?> _extractData(Response<Object?> resp) {
    final body = resp.data;
    if (body is Map) {
      _throwIfFailed(body, resp.statusCode);
      if (body.containsKey('data') && body['data'] != null) {
        final d = body['data'];
        return d is Map ? Map<String, Object?>.from(d) : <String, Object?>{};
      }
      return Map<String, Object?>.from(body);
    }
    if (body is String && body.isNotEmpty) {
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map) {
          return Map<String, Object?>.from(decoded);
        }
      } catch (_) {}
    }
    return <String, Object?>{};
  }

  PanelApiException _toPanelException(DioException e) {
    final status = e.response?.statusCode;
    final body = e.response?.data;
    String message = e.message ?? '网络错误';
    // 两面板失败（尤其登录失败 500）时 message 字段在响应体里
    if (body is Map && body['message'] is String) {
      message = body['message'] as String;
    } else if (body is String && body.isNotEmpty) {
      message = body;
    }
    return PanelApiException('$message (HTTP $status)', statusCode: status);
  }

  // ---------------------------------------------------------------- B / C / D

  /// 公告：响应外层是 `{data,total}`，无 status/message 信封。
  Future<List<PanelNotice>> getNotices({
    required String panelUrl,
    required String authData,
    int page = 1,
  }) async {
    final body = await _authBody(
      '${normalizePanelUrl(panelUrl)}/api/v1/user/notice/fetch?current=$page',
      authData,
    );
    final data = body['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => PanelNotice.fromJson(Map<String, Object?>.from(e)))
        .toList();
  }

  /// 工单列表（不带 id 返回全部，`message` 恒为 null）。
  Future<List<PanelTicket>> getTickets({
    required String panelUrl,
    required String authData,
  }) async {
    final data = await _authData(
      '${normalizePanelUrl(panelUrl)}/api/v1/user/ticket/fetch',
      authData,
    );
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => PanelTicket.fromJson(Map<String, Object?>.from(e)))
        .toList();
  }

  /// 工单详情（带消息列表）。
  Future<PanelTicket> getTicket({
    required String panelUrl,
    required String authData,
    required int ticketId,
  }) async {
    final data = await _authData(
      '${normalizePanelUrl(panelUrl)}/api/v1/user/ticket/fetch?id=$ticketId',
      authData,
    );
    return PanelTicket.fromJson(
      data is Map ? Map<String, Object?>.from(data) : <String, Object?>{},
    );
  }

  /// 新建工单。level: 0=一般 1=技术 2=财务/提现。
  Future<void> saveTicket({
    required String panelUrl,
    required String authData,
    required String subject,
    required int level,
    required String message,
  }) async {
    await _postBody(
      '${normalizePanelUrl(panelUrl)}/api/v1/user/ticket/save',
      authData,
      {'subject': subject, 'level': level.toString(), 'message': message},
    );
  }

  Future<void> replyTicket({
    required String panelUrl,
    required String authData,
    required int ticketId,
    required String message,
  }) async {
    await _postBody(
      '${normalizePanelUrl(panelUrl)}/api/v1/user/ticket/reply',
      authData,
      {'id': ticketId, 'message': message},
    );
  }

  Future<void> closeTicket({
    required String panelUrl,
    required String authData,
    required int ticketId,
  }) async {
    await _postBody(
      '${normalizePanelUrl(panelUrl)}/api/v1/user/ticket/close',
      authData,
      {'id': ticketId},
    );
  }

  /// 流量明细（本月 1 日起，按时间倒序）。
  Future<List<PanelTrafficLog>> getTrafficLog({
    required String panelUrl,
    required String authData,
  }) async {
    final data = await _authData(
      '${normalizePanelUrl(panelUrl)}/api/v1/user/stat/getTrafficLog',
      authData,
    );
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => PanelTrafficLog.fromJson(Map<String, Object?>.from(e)))
        .toList();
  }

  /// 登录设备列表。
  ///
  /// Xboard 来自 personal_access_tokens（name/last_used_at/created_at），
  /// v2board 来自 Cache 会话（ip/login_at/ua），两套字段都读、缺的留空。
  Future<List<PanelSession>> getActiveSessions({
    required String panelUrl,
    required String authData,
  }) async {
    final data = await _authData(
      '${normalizePanelUrl(panelUrl)}/api/v1/user/getActiveSession',
      authData,
    );
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => PanelSession.fromJson(Map<String, Object?>.from(e)))
        .toList();
  }

  Future<void> removeActiveSession({
    required String panelUrl,
    required String authData,
    required String sessionId,
  }) async {
    await _postBody(
      '${normalizePanelUrl(panelUrl)}/api/v1/user/removeActiveSession',
      authData,
      {'session_id': sessionId},
    );
  }

  Future<void> changePassword({
    required String panelUrl,
    required String authData,
    required String oldPassword,
    required String newPassword,
  }) async {
    await _postBody(
      '${normalizePanelUrl(panelUrl)}/api/v1/user/changePassword',
      authData,
      {'old_password': oldPassword, 'new_password': newPassword},
    );
  }

  /// 佣金转余额。
  Future<void> transferCommission({
    required String panelUrl,
    required String authData,
    required int amount,
  }) async {
    await _postBody(
      '${normalizePanelUrl(panelUrl)}/api/v1/user/transfer',
      authData,
      {'transfer_amount': amount},
    );
  }

  /// 面板网页版快速登录链接。
  Future<String> getQuickLoginUrl({
    required String panelUrl,
    required String authData,
  }) async {
    final data = await _postBody(
      '${normalizePanelUrl(panelUrl)}/api/v1/user/getQuickLoginUrl',
      authData,
      const {},
    );
    return data['data'] as String? ?? '';
  }

  // ------------------------------------------------------------------ 交易类

  /// 可购买套餐列表。
  Future<List<PanelPlan>> getPlans({
    required String panelUrl,
    required String authData,
  }) async {
    final data = await _authData(
      '${normalizePanelUrl(panelUrl)}/api/v1/user/plan/fetch',
      authData,
    );
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => PanelPlan.fromJson(Map<String, Object?>.from(e)))
        .toList();
  }

  /// 支付方式（method 取 id）。
  Future<List<PanelPaymentMethod>> getPaymentMethods({
    required String panelUrl,
    required String authData,
  }) async {
    final data = await _authData(
      '${normalizePanelUrl(panelUrl)}/api/v1/user/order/getPaymentMethod',
      authData,
    );
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => PanelPaymentMethod.fromJson(Map<String, Object?>.from(e)))
        .toList();
  }

  /// 建单，返回订单号。
  Future<String> saveOrder({
    required String panelUrl,
    required String authData,
    required int planId,
    required String period,
    String? couponCode,
  }) async {
    final body = await _postBody(
      '${normalizePanelUrl(panelUrl)}/api/v1/user/order/save',
      authData,
      {
        'plan_id': planId,
        'period': period,
        if (couponCode != null && couponCode.isNotEmpty) 'coupon_code': couponCode,
      },
    );
    final data = body['data'];
    if (data is! String || data.isEmpty) {
      throw const PanelApiException('建单失败：响应缺少 trade_no');
    }
    return data;
  }

  /// 发起支付。响应是裸 `{type,data}`：type -1 已直接开通 / 0 二维码 / 1 跳转。
  Future<PanelCheckout> checkout({
    required String panelUrl,
    required String authData,
    required String tradeNo,
    required int method,
  }) async {
    final body = await _postBody(
      '${normalizePanelUrl(panelUrl)}/api/v1/user/order/checkout',
      authData,
      {'trade_no': tradeNo, 'method': method},
    );
    return PanelCheckout(
      type: (body['type'] as num?)?.toInt() ?? 1,
      data: body['data'],
    );
  }

  /// 轮询订单状态：0待支付 1开通中 2已取消 3已完成 4已折抵。
  Future<int> getOrderStatus({
    required String panelUrl,
    required String authData,
    required String tradeNo,
  }) async {
    final data = await _authData(
      '${normalizePanelUrl(panelUrl)}/api/v1/user/order/check'
      '?trade_no=$tradeNo',
      authData,
    );
    return (data as num?)?.toInt() ?? -1;
  }

  Future<List<PanelOrder>> getOrders({
    required String panelUrl,
    required String authData,
    int? status,
  }) async {
    final query = status == null ? '' : '?status=$status';
    final data = await _authData(
      '${normalizePanelUrl(panelUrl)}/api/v1/user/order/fetch$query',
      authData,
    );
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => PanelOrder.fromJson(Map<String, Object?>.from(e)))
        .toList();
  }

  Future<void> cancelOrder({
    required String panelUrl,
    required String authData,
    required String tradeNo,
  }) async {
    await _postBody(
      '${normalizePanelUrl(panelUrl)}/api/v1/user/order/cancel',
      authData,
      {'trade_no': tradeNo},
    );
  }

  /// 优惠券校验，返回券信息；不可用时抛 [PanelApiException]。
  Future<PanelCoupon> checkCoupon({
    required String panelUrl,
    required String authData,
    required String code,
    int? planId,
    String? period,
  }) async {
    final payload = <String, dynamic>{'code': code};
    if (planId != null) {
      payload['plan_id'] = planId;
    }
    if (period != null) {
      payload['period'] = period;
    }
    final body = await _postBody(
      '${normalizePanelUrl(panelUrl)}/api/v1/user/coupon/check',
      authData,
      payload,
    );
    final data = body['data'];
    return PanelCoupon.fromJson(
      data is Map ? Map<String, Object?>.from(data) : <String, Object?>{},
    );
  }

  /// 邀请信息：邀请码列表 + 定长五项统计。
  Future<PanelInvite> getInviteInfo({
    required String panelUrl,
    required String authData,
  }) async {
    final data = await _authData(
      '${normalizePanelUrl(panelUrl)}/api/v1/user/invite/fetch',
      authData,
    );
    if (data is! Map) return const PanelInvite();
    return PanelInvite.fromJson(Map<String, Object?>.from(data));
  }

  Future<void> saveInviteCode({
    required String panelUrl,
    required String authData,
  }) async {
    await _authData(
      '${normalizePanelUrl(panelUrl)}/api/v1/user/invite/save',
      authData,
    );
  }

  /// 佣金明细，响应是裸 `{data,total}`。
  Future<List<PanelCommissionLog>> getCommissionLogs({
    required String panelUrl,
    required String authData,
    int page = 1,
  }) async {
    final body = await _authBody(
      '${normalizePanelUrl(panelUrl)}/api/v1/user/invite/details'
      '?current=$page&page_size=20',
      authData,
    );
    final data = body['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => PanelCommissionLog.fromJson(Map<String, Object?>.from(e)))
        .toList();
  }

  // ------------------------------------------------------------------ 登录类

  /// 注册。emailCode 仅在面板开启邮箱验证时需要。
  Future<PanelLoginResult> register({
    required String panelUrl,
    required String email,
    required String password,
    String? inviteCode,
    String? emailCode,
  }) async {
    final body = await _postBody(
      '${normalizePanelUrl(panelUrl)}/api/v1/passport/auth/register',
      null,
      {
        'email': email,
        'password': password,
        if (inviteCode != null && inviteCode.isNotEmpty)
          'invite_code': inviteCode,
        if (emailCode != null && emailCode.isNotEmpty) 'email_code': emailCode,
      },
    );
    return _loginResultFrom(body);
  }

  /// 发送邮箱验证码。
  Future<void> sendEmailVerify({
    required String panelUrl,
    required String email,
  }) async {
    await _postBody(
      '${normalizePanelUrl(panelUrl)}/api/v1/passport/comm/sendEmailVerify',
      null,
      {'email': email},
    );
  }

  /// 忘记密码：邮箱 + 验证码 + 新密码。
  Future<void> forgetPassword({
    required String panelUrl,
    required String email,
    required String emailCode,
    required String password,
  }) async {
    await _postBody(
      '${normalizePanelUrl(panelUrl)}/api/v1/passport/auth/forget',
      null,
      {'email': email, 'email_code': emailCode, 'password': password},
    );
  }

  PanelLoginResult _loginResultFrom(Map<String, Object?> body) {
    final data = body['data'];
    final map = data is Map ? Map<String, Object?>.from(data) : body;
    final authData = map['auth_data'] as String? ?? '';
    if (authData.isEmpty) {
      throw const PanelApiException('响应缺少 auth_data');
    }
    return PanelLoginResult(
      token: map['token'] as String? ?? '',
      authData: authData,
      isAdmin: map['is_admin'] == true,
      isXboard: detectIsXboard(authData),
    );
  }

  /// 面板以 HTTP 200 + `{status:'fail'}` 返回失败时，按业务失败处理并带出 message。
  static void _throwIfFailed(Map<Object?, Object?> body, int? statusCode) {
    if (body['status'] == 'fail') {
      throw PanelApiException(
        (body['message'] as String?) ?? '面板返回失败',
        statusCode: statusCode,
      );
    }
  }

  /// 带鉴权头的 GET，返回完整响应体 Map。
  Future<Map<String, Object?>> _authBody(String url, String authData) async {
    return _requestMap(url, headers: _authHeaders(authData));
  }

  /// 带鉴权头的 POST，返回完整响应体 Map。
  Future<Map<String, Object?>> _postBody(
    String url,
    String? authData,
    Map<String, dynamic> data,
  ) async {
    return _requestMap(
      url,
      headers: authData == null ? null : _authHeaders(authData),
      data: data,
    );
  }

  Future<Map<String, Object?>> _requestMap(
    String url, {
    Map<String, String>? headers,
    Map<String, dynamic>? data,
  }) async {
    try {
      final resp = data == null
          ? await _dio.get<Object?>(url, options: Options(headers: headers))
          : await _dio.post<Object?>(
              url,
              data: data,
              options: Options(headers: headers),
            );
      final body = resp.data;
      if (body is Map) {
        _throwIfFailed(body, resp.statusCode);
        return Map<String, Object?>.from(body);
      }
      if (body is String && body.isNotEmpty) {
        try {
          final decoded = jsonDecode(body);
          if (decoded is Map) return Map<String, Object?>.from(decoded);
        } catch (_) {}
      }
      return <String, Object?>{};
    } on DioException catch (e) {
      throw _toPanelException(e);
    }
  }

  /// 裸 `data`：兼容信封与 `{data,total}`、标量三种形状。
  Future<Object?> _authData(String url, String authData) async {
    final body = await _authBody(url, authData);
    if (!body.containsKey('data')) return body;
    return body['data'];
  }

  /// 兼容 int / 数字字符串 / ISO 时间串（不同面板与字段的类型不一致）。
  static int? _asInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value) ?? double.tryParse(value)?.toInt();
      if (parsed != null) return parsed;
      final ms = DateTime.tryParse(value)?.millisecondsSinceEpoch;
      return ms == null ? null : ms ~/ 1000;
    }
    return null;
  }

  static double? _asDouble(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

/// 公告。
class PanelNotice {
  final int id;
  final String title;
  final String content;
  final String? imgUrl;
  final List<String> tags;
  final int createdAt;

  const PanelNotice({
    required this.id,
    required this.title,
    required this.content,
    this.imgUrl,
    this.tags = const [],
    this.createdAt = 0,
  });

  factory PanelNotice.fromJson(Map<String, Object?> json) {
    final tags = json['tags'];
    return PanelNotice(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      imgUrl: json['img_url'] as String?,
      tags: tags is List
          ? tags.whereType<Object>().map((e) => '$e').toList()
          : const [],
      createdAt: (json['created_at'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 工单消息。
class PanelTicketMessage {
  final int id;
  final bool isMe;
  final String message;
  final int createdAt;

  const PanelTicketMessage({
    required this.id,
    required this.isMe,
    required this.message,
    this.createdAt = 0,
  });

  factory PanelTicketMessage.fromJson(Map<String, Object?> json) {
    return PanelTicketMessage(
      id: (json['id'] as num?)?.toInt() ?? 0,
      isMe: json['is_me'] == true,
      message: json['message'] as String? ?? '',
      createdAt: (json['created_at'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 工单。
class PanelTicket {
  final int id;
  final int level;
  final int replyStatus;
  final int status;
  final String subject;
  final List<PanelTicketMessage> messages;

  const PanelTicket({
    required this.id,
    required this.level,
    required this.replyStatus,
    required this.status,
    required this.subject,
    this.messages = const [],
  });

  bool get closed => status == 1;

  factory PanelTicket.fromJson(Map<String, Object?> json) {
    final messages = json['message'];
    return PanelTicket(
      id: (json['id'] as num?)?.toInt() ?? 0,
      level: (json['level'] as num?)?.toInt() ?? 0,
      replyStatus: (json['reply_status'] as num?)?.toInt() ?? 0,
      status: (json['status'] as num?)?.toInt() ?? 0,
      subject: json['subject'] as String? ?? '',
      messages: messages is List
          ? messages
              .whereType<Map>()
              .map((e) => PanelTicketMessage.fromJson(
                    Map<String, Object?>.from(e),
                  ))
              .toList()
          : const [],
    );
  }
}

/// 流量明细（单日）。
class PanelTrafficLog {
  final int upload;
  final int download;
  final int recordAt;
  final double serverRate;

  const PanelTrafficLog({
    this.upload = 0,
    this.download = 0,
    this.recordAt = 0,
    this.serverRate = 0,
  });

  int get total => upload + download;

  factory PanelTrafficLog.fromJson(Map<String, Object?> json) {
    return PanelTrafficLog(
      upload: (json['u'] as num?)?.toInt() ?? 0,
      download: (json['d'] as num?)?.toInt() ?? 0,
      recordAt: (json['record_at'] as num?)?.toInt() ?? 0,
      serverRate: (json['server_rate'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// 登录设备。
class PanelSession {
  final int id;
  final String name;
  final String? ip;
  final String? userAgent;
  final int? lastUsedAt;
  final int? createdAt;

  const PanelSession({
    required this.id,
    this.name = '',
    this.ip,
    this.userAgent,
    this.lastUsedAt,
    this.createdAt,
  });

  factory PanelSession.fromJson(Map<String, Object?> json) {
    final rawId = json['id'];
    return PanelSession(
      id: rawId is num ? rawId.toInt() : (int.tryParse('$rawId') ?? 0),
      name: json['name'] as String? ?? '',
      ip: json['ip'] as String?,
      userAgent: json['ua'] as String?,
      lastUsedAt: _asIntOrNull(json['last_used_at']),
      createdAt: _asIntOrNull(json['created_at']),
    );
  }
}

/// 套餐。
class PanelPlan {
  final int id;
  final String name;
  final String content;
  final int transferEnable;
  final int? speedLimit;
  final int? deviceLimit;
  final bool show;
  final bool sell;
  final bool renew;
  final int sort;
  final List<String> tags;
  final Map<String, double> prices;

  const PanelPlan({
    required this.id,
    required this.name,
    this.content = '',
    this.transferEnable = 0,
    this.speedLimit,
    this.deviceLimit,
    this.show = false,
    this.sell = false,
    this.renew = false,
    this.sort = 0,
    this.tags = const [],
    this.prices = const {},
  });

  /// 周期名 → 价格（元）。
  double? priceOf(String period) => prices[period];

  /// 是否有可购周期。
  bool get purchasable => sell && prices.isNotEmpty;

  factory PanelPlan.fromJson(Map<String, Object?> json) {
    final tags = json['tags'];
    final prices = <String, double>{};
    for (final period in _periods) {
      final value = (json[period] as num?)?.toDouble();
      if (value != null) prices[period] = value / 100;
    }
    return PanelPlan(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      content: json['content'] as String? ?? '',
      transferEnable: (json['transfer_enable'] as num?)?.toInt() ?? 0,
      speedLimit: (json['speed_limit'] as num?)?.toInt(),
      deviceLimit: (json['device_limit'] as num?)?.toInt(),
      show: json['show'] == true,
      sell: json['sell'] == true,
      renew: json['renew'] == true,
      sort: (json['sort'] as num?)?.toInt() ?? 0,
      tags: tags is List
          ? tags.whereType<Object>().map((e) => '$e').toList()
          : const [],
      prices: prices,
    );
  }

  static const _periods = [
    'month_price',
    'quarter_price',
    'half_year_price',
    'year_price',
    'two_year_price',
    'three_year_price',
    'onetime_price',
    'reset_price',
  ];
}

/// 支付方式。
class PanelPaymentMethod {
  final int id;
  final String name;
  final String payment;
  final String? icon;
  final int? handlingFeeFixed;
  final double? handlingFeePercent;

  const PanelPaymentMethod({
    required this.id,
    required this.name,
    required this.payment,
    this.icon,
    this.handlingFeeFixed,
    this.handlingFeePercent,
  });

  factory PanelPaymentMethod.fromJson(Map<String, Object?> json) {
    return PanelPaymentMethod(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      payment: json['payment'] as String? ?? '',
      icon: json['icon'] as String?,
      handlingFeeFixed: (json['handling_fee_fixed'] as num?)?.toInt(),
      handlingFeePercent: (json['handling_fee_percent'] as num?)?.toDouble(),
    );
  }
}

/// 支付结果：type -1 已直接开通 / 0 二维码内容 / 1 跳转 URL。
class PanelCheckout {
  final int type;
  final Object? data;

  const PanelCheckout({required this.type, this.data});

  bool get activated => type == -1;
  bool get isQrCode => type == 0;
  bool get isRedirect => type == 1;
}

/// 订单。
class PanelOrder {
  final int id;
  final int planId;
  final int type;
  final String period;
  final String tradeNo;
  final int totalAmount;
  final int status;
  final int commissionBalance;
  final int? paidAt;
  final int createdAt;
  final String? planName;
  final String? paymentName;

  const PanelOrder({
    required this.id,
    required this.planId,
    required this.type,
    required this.period,
    required this.tradeNo,
    required this.totalAmount,
    required this.status,
    this.commissionBalance = 0,
    this.paidAt,
    this.createdAt = 0,
    this.planName,
    this.paymentName,
  });

  bool get pending => status == 0;
  bool get finished => status == 3;

  factory PanelOrder.fromJson(Map<String, Object?> json) {
    final plan = json['plan'];
    final payment = json['payment'];
    return PanelOrder(
      id: (json['id'] as num?)?.toInt() ?? 0,
      planId: (json['plan_id'] as num?)?.toInt() ?? 0,
      type: (json['type'] as num?)?.toInt() ?? 0,
      period: json['period'] as String? ?? '',
      tradeNo: json['trade_no'] as String? ?? '',
      totalAmount: (json['total_amount'] as num?)?.toInt() ?? 0,
      status: (json['status'] as num?)?.toInt() ?? 0,
      commissionBalance: (json['commission_balance'] as num?)?.toInt() ?? 0,
      paidAt: (json['paid_at'] as num?)?.toInt(),
      createdAt: (json['created_at'] as num?)?.toInt() ?? 0,
      planName: plan is Map ? plan['name'] as String? : null,
      paymentName: payment is Map ? payment['name'] as String? : null,
    );
  }
}

/// 优惠券。
class PanelCoupon {
  final int id;
  final String code;
  final String name;
  final int type;
  final int value;
  final int? limitUse;
  final int? limitUseWithUser;
  final List<String> limitPlanIds;
  final List<String> limitPeriod;
  final int? startedAt;
  final int? endedAt;

  const PanelCoupon({
    required this.id,
    required this.code,
    required this.name,
    required this.type,
    required this.value,
    this.limitUse,
    this.limitUseWithUser,
    this.limitPlanIds = const [],
    this.limitPeriod = const [],
    this.startedAt,
    this.endedAt,
  });

  /// 是否按百分比抵扣。
  bool get isPercent => type == 2;

  factory PanelCoupon.fromJson(Map<String, Object?> json) {
    List<String> strings(Object? value) => value is List
        ? value.whereType<Object>().map((e) => '$e').toList()
        : const [];
    return PanelCoupon(
      id: (json['id'] as num?)?.toInt() ?? 0,
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      type: (json['type'] as num?)?.toInt() ?? 0,
      value: (json['value'] as num?)?.toInt() ?? 0,
      limitUse: (json['limit_use'] as num?)?.toInt(),
      limitUseWithUser: (json['limit_use_with_user'] as num?)?.toInt(),
      limitPlanIds: strings(json['limit_plan_ids']),
      limitPeriod: strings(json['limit_period']),
      startedAt: (json['started_at'] as num?)?.toInt(),
      endedAt: (json['ended_at'] as num?)?.toInt(),
    );
  }
}

/// 邀请码。
class PanelInviteCode {
  final int userId;
  final String code;
  final int pv;
  final int createdAt;

  const PanelInviteCode({
    required this.userId,
    required this.code,
    this.pv = 0,
    this.createdAt = 0,
  });

  factory PanelInviteCode.fromJson(Map<String, Object?> json) {
    return PanelInviteCode(
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      code: json['code'] as String? ?? '',
      pv: (json['pv'] as num?)?.toInt() ?? 0,
      createdAt: (json['created_at'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 邀请信息：邀请码列表 + 定长五项统计。
class PanelInvite {
  final List<PanelInviteCode> codes;
  final List<int> stat;

  const PanelInvite({this.codes = const [], this.stat = const []});

  int get registeredUsers => _at(0);
  int get validCommission => _at(1);
  int get pendingCommission => _at(2);
  int get commissionRate => _at(3);
  int get availableCommission => _at(4);

  int _at(int i) => i < stat.length ? stat[i] : 0;

  factory PanelInvite.fromJson(Map<String, Object?> json) {
    final codes = json['codes'];
    final stat = json['stat'];
    return PanelInvite(
      codes: codes is List
          ? codes
              .whereType<Map>()
              .map((e) => PanelInviteCode.fromJson(
                    Map<String, Object?>.from(e),
                  ))
              .toList()
          : const [],
      stat: stat is List
          ? stat.whereType<num>().map((e) => e.toInt()).toList()
          : const [],
    );
  }
}

/// 佣金明细。
class PanelCommissionLog {
  final int id;
  final int orderAmount;
  final String tradeNo;
  final int getAmount;
  final int createdAt;

  const PanelCommissionLog({
    required this.id,
    required this.orderAmount,
    required this.tradeNo,
    required this.getAmount,
    this.createdAt = 0,
  });

  factory PanelCommissionLog.fromJson(Map<String, Object?> json) {
    return PanelCommissionLog(
      id: (json['id'] as num?)?.toInt() ?? 0,
      orderAmount: (json['order_amount'] as num?)?.toInt() ?? 0,
      tradeNo: json['trade_no'] as String? ?? '',
      getAmount: (json['get_amount'] as num?)?.toInt() ?? 0,
      createdAt: (json['created_at'] as num?)?.toInt() ?? 0,
    );
  }
}

int? _asIntOrNull(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  if (value is String) {
    final parsed = int.tryParse(value) ?? double.tryParse(value)?.toInt();
    if (parsed != null) return parsed;
    final ms = DateTime.tryParse(value)?.millisecondsSinceEpoch;
    return ms == null ? null : ms ~/ 1000;
  }
  return null;
}

/// 面板 API 异常。
class PanelApiException implements Exception {
  final String message;

  /// HTTP 状态码（网络层失败时为 null）。
  final int? statusCode;

  const PanelApiException(this.message, {this.statusCode});

  /// 是否鉴权失效（凭据过期 / 被登录设备管理注销）。
  bool get isUnauthorized => statusCode == 401 || statusCode == 403;

  @override
  String toString() => 'PanelApiException: $message';
}
