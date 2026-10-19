import 'package:ckbox/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';

import '../../common/common.dart';
import '../../models/models.dart';

/// 面板登录视图（ckbox 面板账号体系 UI 入口）。
///
/// 输入面板地址 + 邮箱 + 密码，调用 [PanelClient] 登录并获取订阅 URL，
/// 存入 [PanelAccountStore]，再通过 [onLogin] 回调把订阅 URL 交给上层
/// 创建 Profile。支持 Xboard（Sanctum）与 v2board（JWT）两种面板。
class PanelLoginView extends StatefulWidget {
  /// 登录成功回调，参数为订阅 URL。
  final Future<void> Function(String subscribeUrl) onLogin;

  /// 重登录时传入既有账号 id，凭据就地更新而不新建账号。
  final String? existingId;

  const PanelLoginView({super.key, required this.onLogin, this.existingId});

  @override
  State<PanelLoginView> createState() => _PanelLoginViewState();
}

class _PanelLoginViewState extends State<PanelLoginView> {
  final _panelUrlController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _client = PanelClient();
  final _store = PanelAccountStore();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _panelUrlController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String get _panelUrl => _panelUrlController.text.trim();

  Future<void> _login() async {
    final panelUrl = _panelUrl;
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (panelUrl.isEmpty || !panelUrl.startsWith('http')) {
      setState(() => _error = '请输入有效的面板地址（http/https）');
      return;
    }
    if (email.isEmpty) {
      setState(() => _error = '请输入邮箱');
      return;
    }
    if (password.isEmpty) {
      setState(() => _error = '请输入密码');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final login = await _client.login(
        panelUrl: panelUrl,
        email: email,
        password: password,
      );
      final sub = await _client.getSubscribe(
        panelUrl: panelUrl,
        authData: login.authData,
      );

      final account = PanelAccount(
        id: widget.existingId ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        panelUrl: PanelClient.normalizePanelUrl(panelUrl),
        email: email,
        authData: login.authData,
        isXboard: login.isXboard,
        subscribeToken: sub.subscribeToken ?? login.token,
        subscribeUrl: sub.subscribeUrl,
        expireAt: sub.expireAt,
        totalTraffic: sub.transferEnable,
        upload: sub.upload,
        download: sub.download,
        isActive: widget.existingId != null,
        needsRelogin: false,
      );
      await _store.upsert(account);
      final accounts = await _store.load();
      if (!accounts.any((e) => e.isActive)) {
        await _store.setActive(account.id);
      }

      if (!mounted) return;
      await widget.onLogin(sub.subscribeUrl);
    } on PanelApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = '登录失败：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 忘记密码：邮箱验证码 + 新密码。
  void _openResetPassword() {
    final emailController = TextEditingController();
    final codeController = TextEditingController();
    final passwordController = TextEditingController();
    final panelUrl = _panelUrl;

    showExtend(
      context,
      builder: (sheetContext, type) {
        return AdaptiveSheetScaffold(
          type: type,
          title: '重置密码',
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _buildField(
                controller: emailController,
                icon: Icons.email_outlined,
                label: '注册邮箱',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildField(
                      controller: codeController,
                      icon: Icons.confirmation_number_outlined,
                      label: '邮箱验证码',
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      try {
                        await _client.sendEmailVerify(
                          panelUrl: panelUrl,
                          email: emailController.text.trim(),
                        );
                        if (sheetContext.mounted) {
                          sheetContext.showSnackBar('验证码已发送');
                        }
                      } on PanelApiException catch (e) {
                        if (sheetContext.mounted) {
                          sheetContext.showSnackBar(e.message);
                        }
                      }
                    },
                    child: const Text('发送'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildField(
                controller: passwordController,
                icon: Icons.lock_outline,
                label: '新密码（至少 8 位）',
                obscure: true,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () async {
                  try {
                    await _client.forgetPassword(
                      panelUrl: panelUrl,
                      email: emailController.text.trim(),
                      emailCode: codeController.text.trim(),
                      password: passwordController.text,
                    );
                    if (sheetContext.mounted) {
                      sheetContext.showSnackBar('密码已重置，请重新登录');
                      Navigator.pop(sheetContext);
                    }
                  } on PanelApiException catch (e) {
                    if (sheetContext.mounted) {
                      sheetContext.showSnackBar(e.message);
                    }
                  }
                },
                child: const Text('重置密码'),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 注册新账号。邀请码与邮箱验证码按面板开关决定是否必填。
  void _openRegister() {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final inviteController = TextEditingController();
    final codeController = TextEditingController();
    final panelUrl = _panelUrl;

    showExtend(
      context,
      builder: (sheetContext, type) {
        return AdaptiveSheetScaffold(
          type: type,
          title: '注册面板账号',
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _buildField(
                controller: emailController,
                icon: Icons.email_outlined,
                label: '邮箱',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              _buildField(
                controller: passwordController,
                icon: Icons.lock_outline,
                label: '密码（至少 8 位）',
                obscure: true,
              ),
              const SizedBox(height: 12),
              _buildField(
                controller: inviteController,
                icon: Icons.card_giftcard_outlined,
                label: '邀请码（面板需要时填）',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildField(
                      controller: codeController,
                      icon: Icons.confirmation_number_outlined,
                      label: '邮箱验证码',
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      try {
                        await _client.sendEmailVerify(
                          panelUrl: panelUrl,
                          email: emailController.text.trim(),
                        );
                        if (sheetContext.mounted) {
                          sheetContext.showSnackBar('验证码已发送');
                        }
                      } on PanelApiException catch (e) {
                        if (sheetContext.mounted) {
                          sheetContext.showSnackBar(e.message);
                        }
                      }
                    },
                    child: const Text('发送'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () async {
                  try {
                    await _client.register(
                      panelUrl: panelUrl,
                      email: emailController.text.trim(),
                      password: passwordController.text,
                      inviteCode: inviteController.text.trim(),
                      emailCode: codeController.text.trim(),
                    );
                    if (sheetContext.mounted) {
                      sheetContext.showSnackBar('注册成功，请回到登录页登录');
                      Navigator.pop(sheetContext);
                    }
                  } on PanelApiException catch (e) {
                    if (sheetContext.mounted) {
                      sheetContext.showSnackBar(e.message);
                    }
                  }
                },
                child: const Text('注册'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPanelUrl = _panelUrl.startsWith('http');
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _buildField(
          controller: _panelUrlController,
          icon: Icons.language,
          label: '面板地址',
          hint: 'https://panel.example.com',
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 12),
        _buildField(
          controller: _emailController,
          icon: Icons.email_outlined,
          label: '邮箱',
          hint: 'you@example.com',
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),
        _buildField(
          controller: _passwordController,
          icon: Icons.lock_outline,
          label: '密码',
          hint: '••••••••',
          obscure: true,
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _loading ? null : _login,
          icon: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.login),
          label: Text(_loading ? '登录中…' : '登录并导入订阅'),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: hasPanelUrl ? _openResetPassword : null,
              child: const Text('忘记密码'),
            ),
            TextButton(
              onPressed: hasPanelUrl ? _openRegister : null,
              child: const Text('注册账号'),
            ),
          ],
        ),
        if (!hasPanelUrl)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              '先填写面板地址才能重置密码或注册',
              style: TextStyle(fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required IconData icon,
    required String label,
    String? hint,
    bool obscure = false,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      autofillHints: obscure ? [AutofillHints.password] : null,
      decoration: InputDecoration(
        prefixIcon: Icon(icon),
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
