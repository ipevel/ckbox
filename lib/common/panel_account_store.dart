import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/panel_account.dart';

/// 面板账号本地存储。
///
/// 用 SharedPreferences 持久化多个面板账号（JSON 序列化）。
/// 凭据（authData）与订阅 token 仅存本地，不打印不落盘日志。
class PanelAccountStore {
  static const _storageKey = 'ckbox_panel_accounts';

  Future<List<PanelAccount>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<Object?>;
      return list
          .whereType<Map>()
          .map((e) => PanelAccount.fromJson(Map<String, Object?>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<PanelAccount> accounts) async {
    final prefs = await SharedPreferences.getInstance();
    final list = accounts.map((e) => e.toJson()).toList();
    await prefs.setString(_storageKey, jsonEncode(list));
  }

  /// 新增或更新账号（按 id 匹配）。
  Future<void> upsert(PanelAccount account) async {
    final accounts = await load();
    final idx = accounts.indexWhere((e) => e.id == account.id);
    if (idx >= 0) {
      accounts[idx] = account;
    } else {
      accounts.add(account);
    }
    await save(accounts);
  }

  Future<void> remove(String id) async {
    final accounts = await load();
    accounts.removeWhere((e) => e.id == id);
    await save(accounts);
  }
}
