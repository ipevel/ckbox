import '../models/models.dart';

/// 额度/到期告警。
class PanelQuotaWarning {
  final String accountId;
  final String email;
  final double usedPercent;
  final int? daysLeft;
  final String message;

  const PanelQuotaWarning({
    required this.accountId,
    required this.email,
    required this.usedPercent,
    this.daysLeft,
    required this.message,
  });
}

/// 面板额度与到期守护。
///
/// 只基于本地已存的账号快照判断，不额外发请求；
/// 快照由 [PanelAccountSync] 每天刷新一次。
class PanelQuotaGuard {
  const PanelQuotaGuard._();

  /// 用量达到该比例即告警。
  static const warnPercent = 80;

  /// 距到期不足该天数即告警。
  static const warnDays = 7;

  static List<PanelQuotaWarning> checkAll(List<PanelAccount> accounts) =>
      accounts.map(check).whereType<PanelQuotaWarning>().toList();

  /// 单账号告警判断，无告警返回 null。
  static PanelQuotaWarning? check(PanelAccount account) {
    final parts = <String>[];
    double? percent;
    final total = account.totalTraffic;
    if (total != null && total > 0) {
      percent = account.usedTraffic / total * 100;
      if (percent >= warnPercent) {
        parts.add('已用 ${percent.toStringAsFixed(1)}%');
      }
    }

    int? daysLeft;
    final expireAt = account.expireAt;
    if (expireAt != null) {
      final left = expireAt - DateTime.now().millisecondsSinceEpoch ~/ 1000;
      daysLeft = left ~/ 86400;
      if (left <= 0) {
        parts.add('已到期');
      } else if (daysLeft < warnDays) {
        parts.add('$daysLeft 天后到期');
      }
    }

    if (parts.isEmpty) return null;
    return PanelQuotaWarning(
      accountId: account.id,
      email: account.email,
      usedPercent: percent ?? 0,
      daysLeft: daysLeft,
      message: '${account.email}：${parts.join('，')}',
    );
  }
}
