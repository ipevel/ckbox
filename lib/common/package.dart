import 'package:package_info_plus/package_info_plus.dart';

extension PackageInfoExtension on PackageInfo {
  // Clash.Meta 不可删：面板按 UA 含 clash 判定订阅返回 YAML 还是 base64。
  String get ua => 'ckbox/$version Clash.Meta';
}
