import 'package:ckbox/common/common.dart';
import 'package:ckbox/models/models.dart';
import 'package:ckbox/state.dart';
import 'package:ckbox/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';

import 'panel_login_view.dart';

/// 面板账号详情页。
///
/// 按账号 id 读本地凭据，展示面板侧信息：账户、流量、公告、工单、登录设备、
/// 套餐与订单、邀请返佣。所有请求走 [PanelClient]，两面板差异已在解析层兜住。
class PanelAccountDetailView extends StatefulWidget {
  final String accountId;

  const PanelAccountDetailView({super.key, required this.accountId});

  @override
  State<PanelAccountDetailView> createState() => _PanelAccountDetailViewState();
}

class _PanelAccountDetailViewState extends State<PanelAccountDetailView>
    with SingleTickerProviderStateMixin {
  final _client = PanelClient();
  late final TabController _tab;
  PanelAccount? _account;
  PanelUserInfo? _info;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 7, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final accounts = await PanelAccountStore().load();
    PanelAccount? found;
    for (final account in accounts) {
      if (account.id == widget.accountId) found = account;
    }
    if (found == null) {
      if (mounted) {
        setState(() {
          _error = '账号已不存在';
          _loading = false;
        });
      }
      return;
    }
    PanelUserInfo? info;
    String? error;
    try {
      info = await _client.getUserInfo(
        panelUrl: found.panelUrl,
        authData: found.authData,
      );
    } on PanelApiException catch (e) {
      error = e.message;
    } catch (e) {
      error = '$e';
    }
    if (!mounted) return;
    setState(() {
      _account = found;
      _info = info;
      _error = error;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final account = _account;
    if (account == null) {
      return Center(child: Text(_error ?? '账号不可用'));
    }
    if (account.needsRelogin) {
      return _NeedRelogin(account: account, onLogin: _load);
    }
    return Column(
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        TabBar(
          controller: _tab,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: '账户'),
            Tab(text: '流量'),
            Tab(text: '公告'),
            Tab(text: '工单'),
            Tab(text: '设备'),
            Tab(text: '套餐订单'),
            Tab(text: '邀请'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _AccountTab(account: account, info: _info, client: _client),
              _TrafficTab(account: account, client: _client),
              _NoticeTab(account: account, client: _client),
              _TicketTab(account: account, client: _client),
              _SessionTab(account: account, client: _client),
              _TradeTab(account: account, client: _client),
              _InviteTab(account: account, client: _client),
            ],
          ),
        ),
      ],
    );
  }
}

class _NeedRelogin extends StatelessWidget {
  final PanelAccount account;
  final VoidCallback onLogin;

  const _NeedRelogin({required this.account, required this.onLogin});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 48),
            const SizedBox(height: 12),
            const Text('凭据已失效，需要重新登录'),
            const SizedBox(height: 4),
            Text(
              account.email,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => showExtend(
                context,
                builder: (_, type) {
                  return AdaptiveSheetScaffold(
                    type: type,
                    title: '重新登录',
                    body: PanelLoginView(
                      onLogin: (url) async {
                        await globalState.appController
                            .addProfileFormURL(url);
                      },
                    ),
                  );
                },
              ),
              child: const Text('重新登录'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 通用区块：进入时加载一次，可下拉/点按重载。
class _Section<T> extends StatefulWidget {
  final String title;
  final Future<T> Function() loader;
  final Widget Function(BuildContext context, T data) builder;
  final String emptyText;

  const _Section({
    required this.title,
    required this.loader,
    required this.builder,
    this.emptyText = '暂无数据',
  });

  @override
  State<_Section<T>> createState() => _SectionState<T>();
}

class _SectionState<T> extends State<_Section<T>> {
  late Future<T> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.loader();
  }

  void _reload() {
    setState(() => _future = widget.loader());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Row(
            children: [
              Expanded(child: Text(widget.title)),
              IconButton(
                onPressed: _reload,
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: '重新加载',
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<T>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                final error = snapshot.error;
                final text = error is PanelApiException
                    ? error.message
                    : '$error';
                return Center(child: Text(text));
              }
              return widget.builder(context, snapshot.data as T);
            },
          ),
        ),
      ],
    );
  }
}

String _bytes(int? v) {
  if (v == null) return '—';
  if (v >= 1073741824) return '${(v / 1073741824).toStringAsFixed(2)} GB';
  if (v >= 1048576) return '${(v / 1048576).toStringAsFixed(2)} MB';
  if (v >= 1024) return '${(v / 1024).toStringAsFixed(2)} KB';
  return '$v B';
}

String _money(int? fen) => fen == null ? '—' : '¥${(fen / 100).toStringAsFixed(2)}';

String _date(int? seconds) {
  if (seconds == null || seconds <= 0) return '—';
  final dt = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  final mm = dt.month.toString().padLeft(2, '0');
  final dd = dt.day.toString().padLeft(2, '0');
  return '${dt.year}-$mm-${dd}';
}

Map<String, String> _labels() => const {
      'month_price': '月付',
      'quarter_price': '季付',
      'half_year_price': '半年',
      'year_price': '年付',
      'two_year_price': '两年',
      'three_year_price': '三年',
      'onetime_price': '一次性',
      'reset_price': '流量重置',
    };

// ------------------------------------------------------------------ 账户

class _AccountTab extends StatelessWidget {
  final PanelAccount account;
  final PanelUserInfo? info;
  final PanelClient client;

  const _AccountTab({
    required this.account,
    required this.info,
    required this.client,
  });

  @override
  Widget build(BuildContext context) {
    final data = info;
    final used = account.usedTraffic;
    final total = account.totalTraffic;
    final ratio = (total != null && total > 0)
        ? (used / total * 100).clamp(0, 100).toDouble()
        : 0.0;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundImage: (data?.avatarUrl != null &&
                              (data!.avatarUrl ?? '').isNotEmpty)
                          ? NetworkImage(data!.avatarUrl!)
                          : null,
                      child: (data?.avatarUrl ?? '').isEmpty
                          ? const Icon(Icons.person_outline)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data?.email.isNotEmpty == true
                                ? data!.email
                                : account.email,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            account.panelUrl,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(value: ratio / 100),
                const SizedBox(height: 8),
                Text('流量 ${_bytes(used)} / ${_bytes(total)}（${ratio.toStringAsFixed(1)}%）'),
                const SizedBox(height: 4),
                Text('到期 ${_date(account.expireAt)}'),
                if (data?.banned == true)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('账号已被封禁'),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              _kv('余额', _money(data?.balance)),
              _kv('佣金余额', _money(data?.commissionBalance)),
              _kv('注册时间', _date(data?.createdAt)),
              _kv('上次登录', _date(data?.lastLoginAt)),
              _kv('订阅地址', account.subscribeUrl.isEmpty
                  ? '—'
                  : account.subscribeUrl),
              _kv('面板类型', account.isXboard ? 'Xboard' : 'v2board'),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: const Text('修改密码'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _changePassword(context, account, client),
              ),
              ListTile(
                leading: const Icon(Icons.open_in_browser),
                title: const Text('在面板网页端登录'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  try {
                    final url = await client.getQuickLoginUrl(
                      panelUrl: account.panelUrl,
                      authData: account.authData,
                    );
                    if (url.isEmpty) {
                      if (context.mounted) {
                        context.showSnackBar('面板未返回快速登录链接');
                      }
                      return;
                    }
                    globalState.openUrl(url, needConfirm: true);
                  } on PanelApiException catch (e) {
                    if (context.mounted) context.showSnackBar(e.message);
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90, child: Text(k, style: const TextStyle(fontSize: 13))),
          Expanded(
            child: Text(v, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  void _changePassword(
    BuildContext context,
    PanelAccount account,
    PanelClient client,
  ) {
    final oldController = TextEditingController();
    final newController = TextEditingController();
    showExtend(
      context,
      builder: (sheetContext, type) {
        return AdaptiveSheetScaffold(
          type: type,
          title: '修改密码',
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              TextField(
                controller: oldController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '当前密码',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '新密码（至少 8 位）',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () async {
                  try {
                    await client.changePassword(
                      panelUrl: account.panelUrl,
                      authData: account.authData,
                      oldPassword: oldController.text,
                      newPassword: newController.text,
                    );
                    if (context.mounted) {
                      context.showSnackBar('密码已修改');
                      Navigator.pop(sheetContext);
                    }
                  } on PanelApiException catch (e) {
                    if (context.mounted) context.showSnackBar(e.message);
                  }
                },
                child: const Text('提交'),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ------------------------------------------------------------------ 流量

class _TrafficTab extends StatelessWidget {
  final PanelAccount account;
  final PanelClient client;

  const _TrafficTab({required this.account, required this.client});

  @override
  Widget build(BuildContext context) {
    return _Section<List<PanelTrafficLog>>(
      title: '本月流量明细',
      loader: () => client.getTrafficLog(
        panelUrl: account.panelUrl,
        authData: account.authData,
      ),
      builder: (context, logs) {
        if (logs.isEmpty) return const Center(child: Text('本月暂无流量记录'));
        final max = logs.fold<int>(1, (a, b) => b.total > a ? b.total : a);
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          itemCount: logs.length,
          itemBuilder: (context, index) {
            final log = logs[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(_date(log.recordAt))),
                      Text(_bytes(log.total), style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(value: log.total / max),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ------------------------------------------------------------------ 公告

class _NoticeTab extends StatelessWidget {
  final PanelAccount account;
  final PanelClient client;

  const _NoticeTab({required this.account, required this.client});

  @override
  Widget build(BuildContext context) {
    return _Section<List<PanelNotice>>(
      title: '面板公告',
      loader: () => client.getNotices(
        panelUrl: account.panelUrl,
        authData: account.authData,
      ),
      builder: (context, notices) {
        if (notices.isEmpty) return const Center(child: Text('暂无公告'));
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          itemCount: notices.length,
          itemBuilder: (context, index) {
            final notice = notices[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ExpansionTile(
                title: Text(notice.title),
                subtitle: Text(_date(notice.createdAt)),
                childrenPadding:
                    const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(notice.content),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ------------------------------------------------------------------ 工单

class _TicketTab extends StatelessWidget {
  final PanelAccount account;
  final PanelClient client;

  const _TicketTab({required this.account, required this.client});

  static const _levels = ['一般', '技术', '财务'];

  @override
  Widget build(BuildContext context) {
    return _Section<List<PanelTicket>>(
      title: '工单',
      loader: () => client.getTickets(
        panelUrl: account.panelUrl,
        authData: account.authData,
      ),
      builder: (context, tickets) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _newTicket(context),
                  icon: const Icon(Icons.add_comment_outlined),
                  label: const Text('新建工单 / 报障'),
                ),
              ),
            ),
            Expanded(
              child: tickets.isEmpty
                  ? const Center(child: Text('还没有工单'))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: tickets.length,
                      itemBuilder: (context, index) {
                        final ticket = tickets[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            title: Text(ticket.subject),
                            subtitle: Text(
                              '#${ticket.id} · ${_levels[ticket.level.clamp(0, 2)]}'
                              ' · ${ticket.closed ? '已关闭' : '进行中'}'
                              ' · ${ticket.replyStatus == 1 ? '有回复' : '待回复'}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _openTicket(context, ticket),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _newTicket(BuildContext context) async {
    final subjectController = TextEditingController();
    final messageController = TextEditingController();
    var level = 1;
    await showExtend(
      context,
      builder: (_, type) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return AdaptiveSheetScaffold(
              type: type,
              title: '新建工单',
              body: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 0, label: Text('一般')),
                      ButtonSegment(value: 1, label: Text('技术')),
                      ButtonSegment(value: 2, label: Text('财务')),
                    ],
                    selected: {level},
                    onSelectionChanged: (s) =>
                        setSheetState(() => level = s.first),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: subjectController,
                    decoration: const InputDecoration(
                      labelText: '标题',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: messageController,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: '内容（可写故障现象与报错）',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () async {
                      try {
                        await client.saveTicket(
                          panelUrl: account.panelUrl,
                          authData: account.authData,
                          subject: subjectController.text.trim(),
                          level: level,
                          message: messageController.text.trim(),
                        );
                        if (sheetContext.mounted) {
                          sheetContext.showSnackBar('工单已提交');
                          Navigator.pop(sheetContext);
                        }
                      } on PanelApiException catch (e) {
                        if (sheetContext.mounted) {
                          sheetContext.showSnackBar(e.message);
                        }
                      }
                    },
                    child: const Text('提交'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openTicket(BuildContext context, PanelTicket ticket) async {
    await showExtend(
      context,
      builder: (_, type) {
        return AdaptiveSheetScaffold(
          type: type,
          title: ticket.subject,
          body: _TicketDetail(
            ticket: ticket,
            account: account,
            client: client,
          ),
        );
      },
    );
  }
}

class _TicketDetail extends StatefulWidget {
  final PanelTicket ticket;
  final PanelAccount account;
  final PanelClient client;

  const _TicketDetail({
    required this.ticket,
    required this.account,
    required this.client,
  });

  @override
  State<_TicketDetail> createState() => _TicketDetailState();
}

class _TicketDetailState extends State<_TicketDetail> {
  final _controller = TextEditingController();
  late PanelTicket _ticket;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _ticket = widget.ticket;
    _reload();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final detail = await widget.client.getTicket(
        panelUrl: widget.account.panelUrl,
        authData: widget.account.authData,
        ticketId: _ticket.id,
      );
      if (mounted) setState(() => _ticket = detail);
    } on PanelApiException catch (e) {
      if (mounted) context.showSnackBar(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              for (final message in _ticket.messages)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: message.isMe
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.isMe ? '我' : '客服',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(message.message),
                    ],
                  ),
                ),
              if (_ticket.messages.isEmpty)
                const Center(child: Text('暂无消息')),
            ],
          ),
        ),
        if (!_ticket.closed)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: '回复内容',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            setState(() => _busy = true);
                            try {
                              await widget.client.replyTicket(
                                panelUrl: widget.account.panelUrl,
                                authData: widget.account.authData,
                                ticketId: _ticket.id,
                                message: _controller.text.trim(),
                              );
                              _controller.clear();
                              await _reload();
                            } on PanelApiException catch (e) {
                              if (mounted) context.showSnackBar(e.message);
                            } finally {
                              if (mounted) setState(() => _busy = false);
                            }
                          },
                    icon: const Icon(Icons.send),
                    tooltip: '发送',
                  ),
                  IconButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            setState(() => _busy = true);
                            try {
                              await widget.client.closeTicket(
                                panelUrl: widget.account.panelUrl,
                                authData: widget.account.authData,
                                ticketId: _ticket.id,
                              );
                              await _reload();
                            } on PanelApiException catch (e) {
                              if (mounted) context.showSnackBar(e.message);
                            } finally {
                              if (mounted) setState(() => _busy = false);
                            }
                          },
                    icon: const Icon(Icons.check_circle_outline),
                    tooltip: '关闭工单',
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ------------------------------------------------------------------ 设备

class _SessionTab extends StatelessWidget {
  final PanelAccount account;
  final PanelClient client;

  const _SessionTab({required this.account, required this.client});

  @override
  Widget build(BuildContext context) {
    return _Section<List<PanelSession>>(
      title: '登录设备',
      loader: () => client.getActiveSessions(
        panelUrl: account.panelUrl,
        authData: account.authData,
      ),
      builder: (context, sessions) {
        if (sessions.isEmpty) {
          return const Center(child: Text('该面板未开放登录设备列表'));
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          itemCount: sessions.length,
          itemBuilder: (context, index) {
            final session = sessions[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                title: Text(
                  session.name.isEmpty ? '会话 ${session.id}' : session.name,
                ),
                subtitle: Text(
                  [
                    if (session.ip != null && session.ip!.isNotEmpty) session.ip!,
                    if (session.lastUsedAt != null) '最近使用 ${_date(session.lastUsedAt)}',
                  ].join(' · '),
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.logout),
                  tooltip: '注销该设备',
                  onPressed: () async {
                    try {
                      await client.removeActiveSession(
                        panelUrl: account.panelUrl,
                        authData: account.authData,
                        sessionId: session.id.toString(),
                      );
                      if (context.mounted) context.showSnackBar('已注销');
                    } on PanelApiException catch (e) {
                      if (context.mounted) context.showSnackBar(e.message);
                    }
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ------------------------------------------------------------------ 套餐订单

class _TradeTab extends StatelessWidget {
  final PanelAccount account;
  final PanelClient client;

  const _TradeTab({required this.account, required this.client});

  @override
  Widget build(BuildContext context) {
    return _Section<List<PanelPlan>>(
      title: '套餐与订单',
      loader: () => client.getPlans(
        panelUrl: account.panelUrl,
        authData: account.authData,
      ),
      builder: (context, plans) {
        if (plans.isEmpty) {
          return const Center(child: Text('该面板未开放套餐购买'));
        }
        final labels = _labels();
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            for (final plan in plans)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '流量 ${_bytes(plan.transferEnable)}'
                        '${plan.deviceLimit != null ? ' · ${plan.deviceLimit} 台设备' : ''}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final entry in plan.prices.entries)
                            if (plan.sell)
                              ActionChip(
                                label: Text(
                                  '${labels[entry.key] ?? entry.key} ¥${entry.value.toStringAsFixed(2)}',
                                ),
                                onPressed: () => _buy(
                                  context,
                                  plan,
                                  entry.key,
                                ),
                              ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            const Divider(),
            TextButton.icon(
              onPressed: () => _showOrders(context),
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('查看我的订单'),
            ),
          ],
        );
      },
    );
  }

  /// 询问优惠券码；返回 null 表示用户取消。
  Future<String?> _askCoupon(
    BuildContext context,
    PanelPlan plan,
    String period,
  ) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${plan.name} · ${_labels()[period] ?? period}'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '优惠券码（可留空）',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('跳过'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('下一步'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _buy(
    BuildContext context,
    PanelPlan plan,
    String period,
  ) async {
    final coupon = await _askCoupon(context, plan, period);
    if (coupon == null || !context.mounted) return;
    if (coupon.isNotEmpty) {
      try {
        await client.checkCoupon(
          panelUrl: account.panelUrl,
          authData: account.authData,
          code: coupon,
          planId: plan.id,
          period: period,
        );
      } on PanelApiException catch (e) {
        if (context.mounted) context.showSnackBar(e.message);
        return;
      }
    }
    final methods = await client.getPaymentMethods(
      panelUrl: account.panelUrl,
      authData: account.authData,
    );
    if (!context.mounted) return;
    if (methods.isEmpty) {
      context.showSnackBar('该面板未开放支付方式');
      return;
    }
    final method = await showDialog<PanelPaymentMethod>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('${plan.name} · ${_labels()[period] ?? period}'),
        children: [
          for (final m in methods)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, m),
              child: Text(m.name),
            ),
        ],
      ),
    );
    if (method == null || !context.mounted) return;
    try {
      final tradeNo = await client.saveOrder(
        panelUrl: account.panelUrl,
        authData: account.authData,
        planId: plan.id,
        period: period,
        couponCode: coupon.isEmpty ? null : coupon,
      );
      final result = await client.checkout(
        panelUrl: account.panelUrl,
        authData: account.authData,
        tradeNo: tradeNo,
        method: method.id,
      );
      if (!context.mounted) return;
      if (result.activated) {
        context.showSnackBar('已支付并开通');
        return;
      }
      final payload = result.data is String ? result.data as String : '';
      if (payload.isEmpty) {
        context.showSnackBar('面板未返回支付信息');
        return;
      }
      if (result.isQrCode) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('扫码支付'),
            content: SelectableText(payload),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('关闭'),
              ),
            ],
          ),
        );
        return;
      }
      await globalState.openUrl(payload, needConfirm: true);
      final status = await client.getOrderStatus(
        panelUrl: account.panelUrl,
        authData: account.authData,
        tradeNo: tradeNo,
      );
      if (!context.mounted) return;
      context.showSnackBar(
        status == 3 ? '订单已完成' : '订单状态：${_orderStatus(status)}',
      );
    } on PanelApiException catch (e) {
      if (context.mounted) context.showSnackBar(e.message);
    }
  }

  Future<void> _showOrders(BuildContext context) async {
    final orders = await client.getOrders(
      panelUrl: account.panelUrl,
      authData: account.authData,
    );
    if (!context.mounted) return;
    await showExtend(
      context,
      builder: (_, type) {
        return AdaptiveSheetScaffold(
          type: type,
          title: '我的订单',
          body: orders.isEmpty
              ? const Center(child: Text('暂无订单'))
              : ListView.builder(
                  itemCount: orders.length,
                  itemBuilder: (ctx, index) {
                    final order = orders[index];
                    return ListTile(
                      title: Text(
                        order.planName ?? '套餐 #${order.planId}',
                      ),
                      subtitle: Text(
                        '${order.tradeNo} · ${_orderStatus(order.status)}'
                        ' · ${_date(order.createdAt)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Text(_money(order.totalAmount)),
                      onTap: order.pending
                          ? () async {
                              try {
                                await client.cancelOrder(
                                  panelUrl: account.panelUrl,
                                  authData: account.authData,
                                  tradeNo: order.tradeNo,
                                );
                                if (ctx.mounted) {
                                  ctx.showSnackBar('已取消');
                                }
                              } on PanelApiException catch (e) {
                                if (ctx.mounted) ctx.showSnackBar(e.message);
                              }
                            }
                          : null,
                    );
                  },
                ),
        );
      },
    );
  }
}

String _orderStatus(int status) {
  switch (status) {
    case 0:
      return '待支付';
    case 1:
      return '开通中';
    case 2:
      return '已取消';
    case 3:
      return '已完成';
    case 4:
      return '已折抵';
    default:
      return '未知';
  }
}

// ------------------------------------------------------------------ 邀请

class _InviteTab extends StatelessWidget {
  final PanelAccount account;
  final PanelClient client;

  const _InviteTab({required this.account, required this.client});

  @override
  Widget build(BuildContext context) {
    return _Section<PanelInvite>(
      title: '邀请与返佣',
      loader: () => client.getInviteInfo(
        panelUrl: account.panelUrl,
        authData: account.authData,
      ),
      builder: (context, invite) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  _stat('已邀请用户', '${invite.registeredUsers}'),
                  _stat('可用佣金', _money(invite.availableCommission)),
                  _stat('确认中佣金', _money(invite.pendingCommission)),
                  _stat('佣金比例', '${invite.commissionRate}%'),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (invite.codes.isNotEmpty)
              Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (final code in invite.codes)
                      ListTile(
                        title: SelectableText(code.code),
                        subtitle: Text('浏览 ${code.pv} 次'),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      try {
                        await client.saveInviteCode(
                          panelUrl: account.panelUrl,
                          authData: account.authData,
                        );
                        if (context.mounted) {
                          context.showSnackBar('邀请码已生成');
                        }
                      } on PanelApiException catch (e) {
                        if (context.mounted) context.showSnackBar(e.message);
                      }
                    },
                    child: const Text('生成邀请码'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _transfer(context, invite),
                    child: const Text('佣金转余额'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _showLogs(context),
              icon: const Icon(Icons.list_alt_outlined),
              label: const Text('佣金明细'),
            ),
          ],
        );
      },
    );
  }

  Widget _stat(String k, String v) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          Expanded(child: Text(k)),
          Text(v),
        ],
      ),
    );
  }

  Future<void> _transfer(BuildContext context, PanelInvite invite) async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('佣金转余额'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: '金额（单位：元，可转 ${_money(invite.availableCommission)}）',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final fen = ((double.tryParse(controller.text.trim()) ?? 0) * 100)
                  .round();
              if (fen < 1) return;
              try {
                await client.transferCommission(
                  panelUrl: account.panelUrl,
                  authData: account.authData,
                  amount: fen,
                );
                if (ctx.mounted) {
                  ctx.showSnackBar('已转入余额');
                  Navigator.pop(ctx);
                }
              } on PanelApiException catch (e) {
                if (ctx.mounted) ctx.showSnackBar(e.message);
              }
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  Future<void> _showLogs(BuildContext context) async {
    final logs = await client.getCommissionLogs(
      panelUrl: account.panelUrl,
      authData: account.authData,
    );
    if (!context.mounted) return;
    await showExtend(
      context,
      builder: (_, type) {
        return AdaptiveSheetScaffold(
          type: type,
          title: '佣金明细',
          body: logs.isEmpty
              ? const Center(child: Text('暂无佣金记录'))
              : ListView.builder(
                  itemCount: logs.length,
                  itemBuilder: (ctx, index) {
                    final log = logs[index];
                    return ListTile(
                      title: Text('+${_money(log.getAmount)}'),
                      subtitle: Text(
                        '订单 ${_money(log.orderAmount)} · ${_date(log.createdAt)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
