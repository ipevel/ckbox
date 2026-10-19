# ⚡ Ckbox

**Ckbox 是一款多平台代理客户端（Android + Windows），以 Flutter 构建界面，以 Mihomo（Clash.Meta）作为内核。**

> 许可证：GPL-3.0

## 定位

Ckbox 关注隐私、安全与使用细节，提供稳定流畅的 TUN/VPN 体验：

- **双端统一**：Android 与 Windows 共用一套 Flutter UI
- **内核**：Mihomo（Clash.Meta）内核，支持 TUN / 代理 / DNS / 规则分流
- **Windows 提权**：SYSTEM 常驻服务 + HMAC 命名管道 RPC，UI 进程保持用户态
- **面板集成**：内置面板账号登录与订阅管理
- **跨端保活**：前台服务、磁贴、开机自启、应用更新唤醒等多重保障

## 核心特性

* **开箱即用**：稳定的权限处理与 TUN/VPN 体验，大量预置优化细节。
* **精雕细琢**：打磨每处 UI 与交互细节，前台流畅，移动端低能耗。
* **安全守护**：内核遵循各平台最小权限原则，Windows 端内核与提权服务受可执行文件白名单校验保护。
* **性能优先**：支持原生 ARM64，提供硬件分级与深度优化。
* **增强工具**：多平台无感智能启停、一键禁用 QUIC、托盘菜单增强、媒体解锁检测、脚本引擎等。

## 架构

| 层 | 技术 |
|---|---|
| UI | Flutter（Dart） |
| 内核 | Mihomo / Clash.Meta（Go） |
| Windows 提权服务 | Rust（SCM 服务 + HMAC 命名管道） |
| Android 宿主 | Kotlin + JNI |

Windows 端由四个进程组成：用户态 UI、内核进程、SYSTEM 提权服务、UWP 回环豁免工具；内核与 UI 通过 `external-controller` 通信，UI 与提权服务通过命名管道通信。

## Code signing policy

Android 使用自有 keystore 签名；**Windows 产物未做代码签名**，首次运行可能被 SmartScreen 或智能应用控制拦截，需手动允许。签名范围、完整性校验、团队角色与隐私说明见 [SIGNING-POLICY.md](SIGNING-POLICY.md)。

## 致谢

Ckbox 站在开源社区的肩膀上。

- **[Mihomo / Clash.Meta](https://github.com/MetaCubeX/mihomo)** — 内核
- **[FlClash](https://github.com/chen08209/FlClash)** — 界面血统
- **[Bettbox](https://github.com/appshubcc/Bettbox)** — 本项目在其基础上重构演进，感谢原作者的开源工作

本项目遵循 GPL-3.0 发布。

## 开发

```bash
# 依赖
flutter pub get

# 静态分析 / 测试
flutter analyze
flutter test

# 构建
dart setup.dart android --arch arm64
dart setup.dart windows --arch amd64
```

CI 见 `.github/workflows/build.yaml`。
