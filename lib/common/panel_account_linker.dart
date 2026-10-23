import 'package:ckbox/state.dart';

import '../models/models.dart';

/// 面板账号与订阅（Profile）之间的关联。
///
/// 关联按 subscribeUrl 派生、不额外落库：订阅 URL 本身就是账号与订阅之间的契约。
/// 这样既不用给 Profile 模型加字段，也不会因订阅被删而留下脏 id。
class PanelAccountLinker {
  const PanelAccountLinker._();

  /// 该账号已导入的订阅。
  static List<Profile> profilesOf(PanelAccount account) {
    if (account.subscribeUrl.isEmpty) return const [];
    return globalState.config.profiles
        .where((e) => e.url == account.subscribeUrl)
        .toList();
  }

  /// 订阅 URL 变化后回写已导入的订阅，并重新拉取配置。
  ///
  /// 面板重置订阅 token（/user/resetSecurity）后旧 URL 失效，靠这里恢复。
  /// 返回被修复的订阅数量。
  static Future<int> rebind({
    required String oldUrl,
    required String newUrl,
  }) async {
    if (oldUrl.isEmpty || oldUrl == newUrl) return 0;
    final matched = globalState.config.profiles
        .where((e) => e.url == oldUrl)
        .toList();
    for (final profile in matched) {
      final updated = profile.copyWith(url: newUrl);
      await globalState.appController.addProfile(updated);
      await globalState.appController.updateProfile(updated);
    }
    return matched.length;
  }

  /// 登录/重登录后的订阅接入。
  ///
  /// 已有同 URL 订阅则复用；否则若给了旧 URL 且存在对应订阅则改址；
  /// 最后才新建。避免重登录时重复导入同一个订阅。
  static Future<void> attach({required String newUrl, String? oldUrl}) async {
    if (newUrl.isEmpty) return;
    final profiles = globalState.config.profiles;
    if (profiles.any((e) => e.url == newUrl)) return;
    if (oldUrl != null && oldUrl.isNotEmpty) {
      final rebound = await rebind(oldUrl: oldUrl, newUrl: newUrl);
      if (rebound > 0) return;
    }
    await globalState.appController.addProfileFormURL(newUrl);
  }

  /// 确保该账号的订阅已导入；缺失时创建。
  ///
  /// 不触发导航，可在后台调用。失败返回 null。
  static Future<Profile?> ensureProfile(PanelAccount account) async {
    if (account.subscribeUrl.isEmpty) return null;
    final existing = profilesOf(account);
    if (existing.isNotEmpty) return existing.first;
    try {
      final profile = await Profile.normal(url: account.subscribeUrl).update();
      await globalState.appController.addProfile(profile);
      return profile;
    } catch (_) {
      return null;
    }
  }
}
