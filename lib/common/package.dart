import 'package:package_info_plus/package_info_plus.dart';

extension PackageInfoExtension on PackageInfo {
  // 必须保留 `Clash.Meta` 段：面板（Xboard / v2board）按 UA 是否含 clash 决定
  // 返回 YAML 还是 base64，缺了会导致订阅导入报「cannot unmarshal !!str into RawConfig」。
  String get ua => 'ckbox/$version Clash.Meta';
}
