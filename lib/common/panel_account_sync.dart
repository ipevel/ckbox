import '../models/models.dart';
import 'panel_account_linker.dart';
import 'panel_account_store.dart';
import 'panel_client.dart';

/// 面板账号刷新结果。
class PanelRefreshResult {
  final PanelAccount account;

  /// 订阅 URL 是否发生变化（面板重置 token 后会变）。
  final bool urlChanged;

  /// 被回写修复的订阅数量。
  final int reboundProfiles;

  /// 失败原因（null=成功）。
  final String? error;

  const PanelRefreshResult({
    required this.account,
    this.urlChanged = false,
    this.reboundProfiles = 0,
    this.error,
  });

  bool get ok => error == null;
}

/// 面板账号刷新。
///
/// 拉取最新订阅信息 → 订阅 URL 变化时回写已导入订阅 → 更新本地记录。
/// 凭据失效只打「需重新登录」标记，不静默删除任何数据。
class PanelAccountSync {
  const PanelAccountSync._();

  /// 后台自动刷新的节流间隔。
  static const refreshInterval = Duration(hours: 24);

  /// 刷新单个账号。
  static Future<PanelRefreshResult> refresh(
    PanelAccount account, {
    PanelClient? client,
    PanelAccountStore? store,
  }) async {
    final c = client ?? PanelClient();
    final s = store ?? PanelAccountStore();
    try {
      final sub = await c.getSubscribe(
        panelUrl: account.panelUrl,
        authData: account.authData,
      );
      final oldUrl = account.subscribeUrl;
      final newUrl = sub.subscribeUrl;
      final rebound = await PanelAccountLinker.rebind(
        oldUrl: oldUrl,
        newUrl: newUrl,
      );
      final updated = account.copyWith(
        subscribeUrl: newUrl,
        subscribeToken: sub.subscribeToken,
        expireAt: sub.expireAt,
        clearExpireAt: sub.expireAt == null,
        totalTraffic: sub.transferEnable,
        upload: sub.upload,
        download: sub.download,
        needsRelogin: false,
        lastRefreshAt: DateTime.now().millisecondsSinceEpoch,
      );
      await s.upsert(updated);
      return PanelRefreshResult(
        account: updated,
        urlChanged: oldUrl != newUrl,
        reboundProfiles: rebound,
      );
    } on PanelApiException catch (e) {
      if (e.isUnauthorized) {
        await s.markNeedsRelogin(account.id, true);
      }
      return PanelRefreshResult(account: account, error: e.message);
    } catch (e) {
      return PanelRefreshResult(account: account, error: '$e');
    }
  }

  /// 后台批量刷新到期的账号（每账号每 [refreshInterval] 最多一次）。
  ///
  /// 供启动后与进入账号列表时调用，不阻塞 UI。
  static Future<void> refreshStale({
    PanelClient? client,
    PanelAccountStore? store,
  }) async {
    final s = store ?? PanelAccountStore();
    final c = client ?? PanelClient();
    final accounts = await s.load();
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final account in accounts) {
      if (account.needsRelogin) continue;
      final last = account.lastRefreshAt;
      if (last != null && now - last < refreshInterval.inMilliseconds) {
        continue;
      }
      await refresh(account, client: c, store: s);
    }
  }
}
