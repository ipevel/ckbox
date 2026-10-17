import 'package:flutter/material.dart';

import '../../common/common.dart';
import '../../models/models.dart';

/// 面板账号管理视图（ckbox 面板账号体系）。
///
/// 列出本地已登录的面板账号，支持刷新订阅信息（重新拉 getSubscribe）与删除账号。
/// 登录入口在 AddProfileView 的「面板登录」，此处负责后续管理。
class PanelAccountsView extends StatefulWidget {
  const PanelAccountsView({super.key});

  @override
  State<PanelAccountsView> createState() => _PanelAccountsViewState();
}

class _PanelAccountsViewState extends State<PanelAccountsView> {
  final _store = PanelAccountStore();
  final _client = PanelClient();
  List<PanelAccount> _accounts = [];
  bool _loading = true;
  String? _refreshingId;

  @override
  void initState() {
    super.initState();
    _load();
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

  Future<void> _refresh(PanelAccount account) async {
    setState(() => _refreshingId = account.id);
    try {
      final sub = await _client.getSubscribe(
        panelUrl: account.panelUrl,
        authData: account.authData,
      );
      final updated = account.copyWith(
        subscribeUrl: sub.subscribeUrl,
        subscribeToken: sub.subscribeToken,
        expireAt: sub.expireAt,
        totalTraffic: sub.transferEnable,
        upload: sub.upload,
        download: sub.download,
      );
      await _store.upsert(updated);
      await _load();
      if (mounted) context.showSnackBar('已刷新订阅信息');
    } on PanelApiException catch (e) {
      if (mounted) context.showSnackBar(e.message);
    } catch (e) {
      if (mounted) context.showSnackBar('刷新失败：$e');
    } finally {
      if (mounted) setState(() => _refreshingId = null);
    }
  }

  Future<void> _remove(PanelAccount account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除面板账号'),
        content: Text('确定删除 ${account.email}？\n（已导入的订阅配置不受影响）'),
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_accounts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48),
            const SizedBox(height: 12),
            const Text('还没有面板账号'),
            const SizedBox(height: 4),
            const Text(
              '在「添加配置」里选「面板登录」',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _accounts.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final account = _accounts[index];
        return _AccountCard(
          account: account,
          refreshing: _refreshingId == account.id,
          onRefresh: () => _refresh(account),
          onRemove: () => _remove(account),
        );
      },
    );
  }
}

class _AccountCard extends StatelessWidget {
  final PanelAccount account;
  final bool refreshing;
  final VoidCallback onRefresh;
  final VoidCallback onRemove;

  const _AccountCard({
    required this.account,
    required this.refreshing,
    required this.onRefresh,
    required this.onRemove,
  });

  String _formatBytes(int? bytes) {
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

  String _formatExpire(int? expireAt) {
    if (expireAt == null) return '长期有效';
    final dt = DateTime.fromMillisecondsSinceEpoch(expireAt * 1000);
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    return '${dt.year}-$mm-$dd';
  }

  @override
  Widget build(BuildContext context) {
    final used = (account.upload ?? 0) + (account.download ?? 0);
    return Card(
      margin: EdgeInsets.zero,
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
                  Text(
                    account.email,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    account.panelUrl,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '流量 ${_formatBytes(used)} / ${_formatBytes(account.totalTraffic)}'
                    ' · 到期 ${_formatExpire(account.expireAt)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: refreshing ? null : onRefresh,
              icon: refreshing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              tooltip: '刷新订阅信息',
            ),
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline),
              tooltip: '删除账号',
            ),
          ],
        ),
      ),
    );
  }
}
