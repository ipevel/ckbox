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
      final accounts = <PanelAccount>[];
      for (final item in list) {
        if (item is! Map) continue;
        try {
          accounts.add(
            PanelAccount.fromJson(Map<String, Object?>.from(item)),
          );
        } catch (_) {
          // 单条损坏不牵连其余账号
        }
      }
      return accounts;
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

  /// 设为当前活跃账号（其余账号取消活跃）。
  Future<void> setActive(String id) async {
    final accounts = await load();
    await save(
      accounts.map((e) => e.copyWith(isActive: e.id == id)).toList(),
    );
  }

  /// 当前活跃账号；没有标记时取第一个。
  Future<PanelAccount?> active() async {
    final accounts = await load();
    if (accounts.isEmpty) return null;
    for (final account in accounts) {
      if (account.isActive) return account;
    }
    return accounts.first;
  }

  /// 标记或清除「凭据失效，需重新登录」。
  Future<void> markNeedsRelogin(String id, bool value) async {
    final accounts = await load();
    final idx = accounts.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    accounts[idx] = accounts[idx].copyWith(needsRelogin: value);
    await save(accounts);
  }

  /// 记录一次成功刷新的时间。
  Future<void> touchRefresh(String id, int timestamp) async {
    final accounts = await load();
    final idx = accounts.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    accounts[idx] = accounts[idx].copyWith(lastRefreshAt: timestamp);
    await save(accounts);
  }
}
