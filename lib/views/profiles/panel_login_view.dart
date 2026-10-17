import 'package:flutter/material.dart';

import '../../common/common.dart';
import '../../models/models.dart';
import '../../state.dart';

/// 面板登录视图（ckbox 面板账号体系 UI 入口）。
///
/// 输入面板地址 + 邮箱 + 密码，调用 [PanelClient] 登录并获取订阅 URL，
/// 存入 [PanelAccountStore]，再通过 [onLogin] 回调把订阅 URL 交给上层
/// 创建 Profile。支持 Xboard（Sanctum）与 v2board（JWT）两种面板。
class PanelLoginView extends StatefulWidget {
  /// 登录成功回调，参数为订阅 URL。
  final Future<void> Function(String subscribeUrl) onLogin;

  const PanelLoginView({super.key, required this.onLogin});

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

  Future<void> _login() async {
    final panelUrl = _panelUrlController.text.trim();
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
        id: DateTime.now().millisecondsSinceEpoch.toString(),
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
      );
      await _store.upsert(account);

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

  @override
  Widget build(BuildContext context) {
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
