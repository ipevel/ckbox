import 'package:ckbox/providers/providers.dart';
import 'package:ckbox/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../common/common.dart';
import '../../models/models.dart';
import 'panel_account_detail_view.dart';
import 'panel_login_view.dart';

/// 面板账号管理视图（ckbox 面板账号体系）。
///
/// 列出本地已登录的面板账号，支持刷新订阅信息、切换活跃账号、删除账号，
/// 点卡片进入账号详情。登录入口在 AddProfileView 的「面板登录」。
class PanelAccountsView extends ConsumerStatefulWidget {
  const PanelAccountsView({super.key});

  @override
  ConsumerState<PanelAccountsView> createState() => _PanelAccountsViewState();
}

class _PanelAccountsViewState extends ConsumerState<PanelAccountsView> {
  final _store = PanelAccountStore();
  final _client = PanelClient();
  List<PanelAccount> _accounts = [];
  bool _loading = true;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
    _autoRefresh();
  }

  Future<void> _load() async {
    final accounts = await _store.load();
    if (mounted) {
      setState(() {
        _accounts = accounts;
        _loading = false;
      });
    }
  }

  /// 后台刷新到期账号，不阻塞列表展示。
  Future<void> _autoRefresh() async {
    await PanelAccountSync.refreshStale(client: _client, store: _store);
    await _load();
  }

  Future<void> _refresh(PanelAccount account) async {
    setState(() => _busyId = account.id);
    final result = await PanelAccountSync.refresh(
      account,
      client: _client,
      store: _store,
    );
    await _load();
    if (!mounted) return;
    setState(() => _busyId = null);

    if (!result.ok) {
      context.showSnackBar('刷新失败：${result.error}');
      return;
    }
    if (result.reboundProfiles > 0) {
      context.showSnackBar('订阅地址已更新，已修复 ${result.reboundProfiles} 个订阅');
    } else {
      context.showSnackBar('已刷新订阅信息');
    }
  }

  /// 切换活跃账号：确保订阅存在 → 标记活跃 → 切为当前订阅。
  Future<void> _switchTo(PanelAccount account) async {
    setState(() => _busyId = account.id);
    final profile = await PanelAccountLinker.ensureProfile(account);
    if (profile == null) {
      if (mounted) {
        setState(() => _busyId = null);
        context.showSnackBar('订阅不可用，请先刷新或重新登录');
      }
      return;
    }
    await _store.setActive(account.id);
    ref.read(currentProfileIdProvider.notifier).value = profile.id;
    await _load();
    if (!mounted) return;
    setState(() => _busyId = null);
    context.showSnackBar('已切换到 ${account.email}');
  }

  Future<void> _remove(PanelAccount account) async {
    final bound = PanelAccountLinker.profilesOf(account).length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除面板账号'),
        content: Text(
          bound > 0
              ? '确定删除 ${account.email}？\n已导入的 $bound 个订阅会保留，但不再跟随该账号刷新。'
              : '确定删除 ${account.email}？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _store.remove(account.id);
    await _load();
    if (mounted) context.showSnackBar('已删除账号');
  }

  Future<void> _relogin(PanelAccount account) async {
    await _addPanel(existingId: account.id, oldUrl: account.subscribeUrl);
  }

  Future<void> _addPanel({String? existingId, String? oldUrl}) async {
    await showExtend(
      context,
      builder: (_, type) {
        return AdaptiveSheetScaffold(
          type: type,
          title: existingId == null ? '面板登录' : '重新登录',
          body: PanelLoginView(
            existingId: existingId,
            onLogin: (subscribeUrl) async {
              await PanelAccountLinker.attach(
                newUrl: subscribeUrl,
                oldUrl: oldUrl,
              );
            },
          ),
        );
      },
    );
    await _load();
  }

  void _openDetail(PanelAccount account) {
    showExtend(
      context,
      builder: (_, type) {
        return AdaptiveSheetScaffold(
          type: type,
          title: account.email,
          body: PanelAccountDetailView(accountId: account.id),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        _buildHeader(context),
        ..._buildWarnings(context),
        Expanded(
          child: _accounts.isEmpty ? _buildEmpty() : _buildList(),
        ),
      ],
    );
  }

  /// 顶部概览：账号数量 + 当前账号 + 添加入口。
  Widget _buildHeader(BuildContext context) {
    final scheme = context.colorScheme;
    PanelAccount? active;
    for (final account in _accounts) {
      if (account.isActive) active = account;
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '共 ${_accounts.length} 个账号',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                if (active != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '当前使用 ${active.email}',
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: _addPanel,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('添加面板'),
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
          ),
        ],
      ),
    );
  }

  /// 额度/到期告警横幅。
  List<Widget> _buildWarnings(BuildContext context) {
    final warnings = PanelQuotaGuard.checkAll(_accounts);
    if (warnings.isEmpty) return const [];
    final scheme = context.colorScheme;
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          decoration: BoxDecoration(
            color: scheme.errorContainer.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.error.withValues(alpha: 0.25)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 18,
                color: scheme.onErrorContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '账号提醒',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: scheme.onErrorContainer,
                      ),
                    ),
                    for (final warning in warnings)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          warning.message,
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onErrorContainer,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _buildEmpty() {
    final scheme = context.colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cloud_off_outlined,
                size: 32,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '还没有面板账号',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              '登录面板后，订阅可自动跟随账号刷新，额度与到期时间也会同步显示。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _addPanel,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('添加面板'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
      itemCount: _accounts.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final account = _accounts[index];
        return _AccountCard(
          account: account,
          busy: _busyId == account.id,
          boundCount: PanelAccountLinker.profilesOf(account).length,
          warning: PanelQuotaGuard.check(account),
          onTap: () => _openDetail(account),
          onRefresh: () => _refresh(account),
          onSwitch: () => _switchTo(account),
          onRelogin: () => _relogin(account),
          onRemove: () => _remove(account),
        );
      },
    );
  }
}

class _AccountCard extends StatelessWidget {
  final PanelAccount account;
  final bool busy;
  final int boundCount;
  final PanelQuotaWarning? warning;
  final VoidCallback onTap;
  final VoidCallback onRefresh;
  final VoidCallback onSwitch;
  final VoidCallback onRelogin;
  final VoidCallback onRemove;

  const _AccountCard({
    required this.account,
    required this.busy,
    required this.boundCount,
    required this.warning,
    required this.onTap,
    required this.onRefresh,
    required this.onSwitch,
    required this.onRelogin,
    required this.onRemove,
  });

  static String _formatBytes(int? bytes) {
    if (bytes == null) return '—';
    if (bytes >= 1073741824) {
      return '${(bytes / 1073741824).toStringAsFixed(2)} GB';
    }
    if (bytes >= 1048576) {
      return '${(bytes / 1048576).toStringAsFixed(2)} MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    return '$bytes B';
  }

  DateTime? get _expireTime {
    final expireAt = account.expireAt;
    if (expireAt == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(expireAt * 1000);
  }

  int? get _daysLeft {
    final expire = _expireTime;
    if (expire == null) return null;
    return expire.difference(DateTime.now()).inDays;
  }

  String _formatExpire() {
    final expire = _expireTime;
    if (expire == null) return '长期有效';
    final mm = expire.month.toString().padLeft(2, '0');
    final dd = expire.day.toString().padLeft(2, '0');
    final days = _daysLeft ?? 0;
    final date = '${expire.year}-$mm-$dd';
    if (days < 0) return '$date（已过期）';
    return '$date（剩 $days 天）';
  }

  /// 告警标签：按告警原因给出对应文案与配色。
  Widget _warningPill(ColorScheme scheme) {
    final quotaWarning = warning!;
    final daysLeft = quotaWarning.daysLeft;
    if (daysLeft != null && daysLeft <= 0) {
      return _StatusPill(
        label: '已到期',
        color: scheme.error,
        icon: Icons.event_busy,
      );
    }
    if (daysLeft != null && daysLeft < 7) {
      return _StatusPill(
        label: '即将到期',
        color: scheme.tertiary,
        icon: Icons.schedule,
      );
    }
    return _StatusPill(
      label: '额度告急',
      color: scheme.tertiary,
      icon: Icons.warning_amber_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final total = account.totalTraffic;
    final used = account.usedTraffic;
    final hasQuota = total != null && total > 0;
    final ratio = hasQuota ? (used / total).clamp(0.0, 1.0).toDouble() : 0.0;
    final percent = ratio * 100;
    final quotaColor = percent >= 80
        ? scheme.error
        : percent >= 60
            ? scheme.tertiary
            : scheme.primary;

    final daysLeft = _daysLeft;
    final expireColor = daysLeft == null
        ? null
        : daysLeft < 0
            ? scheme.error
            : daysLeft < 7
                ? scheme.tertiary
                : null;

    return CommonCard(
      isSelected: account.isActive,
      onPressed: onTap,
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AccountAvatar(email: account.email),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                account.email,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (account.isActive)
                              _StatusPill(
                                label: '当前',
                                color: scheme.primary,
                                icon: Icons.check,
                              ),
                            if (account.needsRelogin)
                              _StatusPill(
                                label: '需重新登录',
                                color: scheme.error,
                                icon: Icons.error_outline,
                              ),
                            if (warning != null && !account.needsRelogin)
                              _warningPill(scheme),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.link,
                              size: 13,
                              color: scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                account.panelUrl,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (hasQuota) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 6,
                    color: quotaColor,
                    backgroundColor: scheme.surfaceContainerHighest,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '已用 ${_formatBytes(used)} / ${_formatBytes(total)}',
                        style: TextStyle(fontSize: 12, color: quotaColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${percent.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: quotaColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ] else ...[
                _MetaItem(
                  icon: Icons.data_usage,
                  text: '已用 ${_formatBytes(used)}',
                ),
                const SizedBox(height: 10),
              ],
              Wrap(
                spacing: 14,
                runSpacing: 6,
                children: [
                  _MetaItem(
                    icon: Icons.schedule,
                    text: _formatExpire(),
                    color: expireColor,
                  ),
                  _MetaItem(
                    icon: Icons.rss_feed,
                    text: boundCount > 0 ? '$boundCount 个订阅' : '未导入订阅',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Divider(
                height: 1,
                color: scheme.outlineVariant.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 4),
              _buildActions(scheme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActions(ColorScheme scheme) {
    if (busy) {
      return const SizedBox(
        height: 40,
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text('处理中…', style: TextStyle(fontSize: 12)),
          ],
        ),
      );
    }
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          if (account.needsRelogin)
            FilledButton.tonalIcon(
              onPressed: onRelogin,
              icon: const Icon(Icons.login, size: 16),
              label: const Text('重新登录'),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            )
          else if (!account.isActive)
            FilledButton.tonalIcon(
              onPressed: onSwitch,
              icon: const Icon(Icons.swap_horiz, size: 16),
              label: const Text('切换到此'),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            )
          else
            _StatusPill(
              label: '当前使用中',
              color: scheme.primary,
              icon: Icons.check_circle_outline,
            ),
          const Spacer(),
          if (!account.needsRelogin)
            IconButton(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              tooltip: '刷新订阅信息',
              iconSize: 20,
              visualDensity: VisualDensity.compact,
            ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline),
            tooltip: '删除账号',
            iconSize: 20,
            visualDensity: VisualDensity.compact,
            color: scheme.error,
          ),
        ],
      ),
    );
  }
}

/// 账号头像：取邮箱首字母，配色按邮箱哈希在三套容器色间轮转。
class _AccountAvatar extends StatelessWidget {
  final String email;

  const _AccountAvatar({required this.email});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    var hash = 0;
    for (final unit in email.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    final index = hash % 3;
    final backgrounds = [
      scheme.primaryContainer,
      scheme.secondaryContainer,
      scheme.tertiaryContainer,
    ];
    final foregrounds = [
      scheme.onPrimaryContainer,
      scheme.onSecondaryContainer,
      scheme.onTertiaryContainer,
    ];
    final letter = email.isEmpty ? '?' : email[0].toUpperCase();
    return CircleAvatar(
      radius: 20,
      backgroundColor: backgrounds[index],
      child: Text(
        letter,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: foregrounds[index],
        ),
      ),
    );
  }
}

/// 状态标签。
class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _StatusPill({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// 图标 + 文本的次要信息项。
class _MetaItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;

  const _MetaItem({required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final foreground = color ?? scheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: foreground),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, color: foreground)),
      ],
    );
  }
}
