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

/// 面板 API 客户端。
///
/// 实现 ckbox 面板账号体系的两个核心接口（login → getSubscribe），
/// 自动探测 Xboard（Sanctum）与 v2board（JWT）两种鉴权。
/// 契约依据：ckbox-spec/ckbox-面板接口深读.md。
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
  /// 入参 email/password。返回订阅 token + auth_data + 鉴权类型。
  /// 失败时抛 [PanelApiException]（注意：两面板登录失败返回 HTTP 500 而非 4xx）。
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
        throw PanelApiException('登录响应缺少 auth_data（面板可能不是 Xboard/v2board）');
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
  ///
  /// 需鉴权头。返回订阅 URL 与流量/到期信息。
  Future<PanelSubscribeInfo> getSubscribe({
    required String panelUrl,
    required String authData,
  }) async {
    final url = '${normalizePanelUrl(panelUrl)}/api/v1/user/getSubscribe';
    try {
      final resp = await _dio.get<Object?>(
        url,
        options: Options(headers: _authHeaders(authData)),
      );
      final data = _extractData(resp);
      final subscribeUrl = data['subscribe_url'] as String? ?? '';
      if (subscribeUrl.isEmpty) {
        throw PanelApiException('getSubscribe 响应缺少 subscribe_url');
      }
      return PanelSubscribeInfo(
        subscribeUrl: subscribeUrl,
        subscribeToken: data['token'] as String?,
        expireAt: (data['expired_at'] as num?)?.toInt(),
        transferEnable: (data['transfer_enable'] as num?)?.toInt(),
        upload: (data['u'] as num?)?.toInt(),
        download: (data['d'] as num?)?.toInt(),
        plan: data['plan'] as Map<String, Object?>?,
      );
    } on DioException catch (e) {
      throw _toPanelException(e);
    }
  }

  /// 拉取订阅配置（Clash YAML）：GET {subscribeUrl}?flag=clash
  ///
  /// 返回 YAML 文本 + subscription-userinfo 头解析结果。
  /// 该 URL 已含 token，无需额外鉴权头；flag=clash 使面板返回 Clash 协议。
  Future<PanelSubscribeConfig> fetchSubscribeConfig(String subscribeUrl) async {
    final uri = Uri.parse(subscribeUrl);
    final query = Map<String, String>.from(uri.queryParameters);
    query['flag'] = 'clash';
    final url = uri.replace(queryParameters: query).toString();
    try {
      final resp = await _dio.get<String>(
        url,
        options: Options(
          responseType: ResponseType.plain,
          headers: {'User-Agent': 'clash'},
        ),
      );
      final info = _parseSubscriptionUserInfo(
        resp.headers.value('subscription-userinfo'),
      );
      return PanelSubscribeConfig(
        yaml: resp.data ?? '',
        expireAt: info['expire'],
        total: info['total'],
        upload: info['upload'],
        download: info['download'],
      );
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
    return PanelApiException('$message (HTTP $status)');
  }

  /// 解析 subscription-userinfo 头：`upload=..; download=..; total=..; expire=..`
  static Map<String, int?> _parseSubscriptionUserInfo(String? header) {
    final result = <String, int?>{};
    if (header == null || header.isEmpty) return result;
    for (final part in header.split(';')) {
      final kv = part.trim().split('=');
      if (kv.length != 2) continue;
      final key = kv[0].trim();
      final value = int.tryParse(kv[1].trim());
      if (value != null) result[key] = value;
    }
    return result;
  }
}

/// 订阅配置拉取结果。
class PanelSubscribeConfig {
  final String yaml;
  final int? expireAt;
  final int? total;
  final int? upload;
  final int? download;

  const PanelSubscribeConfig({
    required this.yaml,
    this.expireAt,
    this.total,
    this.upload,
    this.download,
  });
}

/// 面板 API 异常。
class PanelApiException implements Exception {
  final String message;
  const PanelApiException(this.message);

  @override
  String toString() => 'PanelApiException: $message';
}
