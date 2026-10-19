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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _addPanel,
              icon: const Icon(Icons.add),
              label: const Text('添加面板'),
            ),
          ),
        ),
        ..._buildWarnings(context),
        Expanded(
          child: _accounts.isEmpty ? _buildEmpty() : _buildList(),
        ),
      ],
    );
  }

  /// 额度/到期告警横幅。
  List<Widget> _buildWarnings(BuildContext context) {
    final warnings = PanelQuotaGuard.checkAll(_accounts);
    if (warnings.isEmpty) return const [];
    final scheme = Theme.of(context).colorScheme;
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.errorContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 18, color: scheme.onErrorContainer),
                  const SizedBox(width: 6),
                  Text(
                    '账号提醒',
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onErrorContainer,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              for (final warning in warnings)
                Text(
                  warning.message,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onErrorContainer,
                  ),
                ),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 48),
          const SizedBox(height: 12),
          const Text('还没有面板账号'),
          const SizedBox(height: 4),
          const Text('点上方「添加面板」登录', style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: _accounts.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final account = _accounts[index];
        return _AccountCard(
          account: account,
          busy: _busyId == account.id,
          boundCount: PanelAccountLinker.profilesOf(account).length,
          warning: PanelQuotaGuard.check(account) != null,
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
  final bool warning;
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

  static String _formatExpire(int? expireAt) {
    if (expireAt == null) return '长期有效';
    final dt = DateTime.fromMillisecondsSinceEpoch(expireAt * 1000);
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    return '${dt.year}-$mm-$dd';
  }

  Widget _badge(BuildContext context, String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: color),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              const Icon(Icons.account_circle_outlined, size: 40),
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
                            style: const TextStyle(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (account.isActive)
                          _badge(context, '当前', scheme.primary),
                        if (account.needsRelogin)
                          _badge(context, '需重新登录', scheme.error),
                        if (warning && !account.needsRelogin)
                          _badge(context, '额度告急', scheme.error),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      account.panelUrl,
                      style: TextStyle(fontSize: 12, color: scheme.outline),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '流量 ${_formatBytes(account.usedTraffic)} / '
                      '${_formatBytes(account.totalTraffic)}'
                      ' · 到期 ${_formatExpire(account.expireAt)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      boundCount > 0 ? '已导入 $boundCount 个订阅' : '尚未导入订阅',
                      style: TextStyle(fontSize: 12, color: scheme.outline),
                    ),
                  ],
                ),
              ),
              if (busy)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else ...[
                if (account.needsRelogin)
                  IconButton(
                    onPressed: onRelogin,
                    icon: const Icon(Icons.login),
                    tooltip: '重新登录',
                  )
                else ...[
                  if (!account.isActive)
                    IconButton(
                      onPressed: onSwitch,
                      icon: const Icon(Icons.swap_horiz),
                      tooltip: '切换到此账号',
                    ),
                  IconButton(
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh),
                    tooltip: '刷新订阅信息',
                  ),
                ],
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline),
                  tooltip: '删除账号',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
