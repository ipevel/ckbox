# Code signing policy

**Windows 产物未做代码签名**；Android 使用自有 keystore 签名。

## 当前签名状态

| 平台 | 状态 | 说明 |
|---|---|---|
| Android | 已签名 | 自有 keystore（PKCS12，`CN=Ckbox`），v2 + v3 方案 |
| Windows | **未签名** | CI 直接产出未签名二进制与安装器 |

Windows 未签名的后果：首次运行 `setup.exe` 或主程序时，SmartScreen 可能提示「Windows 已保护你的电脑」，需点「更多信息 → 仍要运行」；若系统开启了**智能应用控制**，未签名程序可能被直接拦截，需在「Windows 安全中心 → 应用和浏览器控制 → 智能应用控制」中关闭后才能运行。关闭智能应用控制后无法在不重装系统的前提下重新开启，请自行权衡。

## Team roles

| Role | Members |
|---|---|
| Committers and reviewers | [@ipevel](https://github.com/ipevel) |
| Approvers | [@ipevel](https://github.com/ipevel) |

Every change reaches `main` through a pull request, and `main` requires the `analyze-test` check to pass. All team members use multi-factor authentication for GitHub access.

## Privacy policy

This program will not transfer any information to other networked systems unless specifically requested by the user or the person installing or operating it.

Specifically:

- **Proxy traffic** goes only to the nodes the user configures, following the user's own rules.
- **Subscription and panel requests** go only to the address the user enters.
- **Latency tests and media-unlock checks** contact public third-party endpoints (`api.ip.sb`, `ip-api.com`, `api.bilibili.com` and similar) only when the user starts them.
- **Update checks** request `https://github.com/ipevel/ckbox/releases/latest` — a plain HTTPS GET that carries no device or user data. Automatic checks can be disabled in Settings; if the app has not checked for 28 days, one check runs regardless so that security updates are not missed.
- **No telemetry, analytics or crash reporting** is enabled in released builds.
- No account, device identifier or usage data is collected or uploaded.

## Windows artifacts

| Artifact | Description |
|---|---|
| `Ckbox.exe` | Application UI (user mode) |
| `CkboxCore.exe` | Proxy core (Mihomo) |
| `CkboxHelperService.exe` | Privileged SYSTEM helper service |
| `WindowsLoopbackManager.exe` | UWP loopback exemption tool |
| `Ckbox-<version>-windows-<arch>-setup.exe` | Inno Setup installer |

以上产物**均未做代码签名**，由 CI 直接构建产出。

**完整性校验（非签名）**：提权服务在启动内核前会校验 `CkboxCore.exe` 的 SHA256，该值与构建时写入的白名单一致才允许启动，因此服务只会拉起随包发布的内核；这不是数字签名，不能替代操作系统层面的签名信任。

## Android

- Own keystore (PKCS12, `CN=Ckbox`); v2 + v3 signature schemes, v1 disabled.
- v3 lineage keeps a proof-of-rotation chain for future key rotation.
- A release build fails instead of silently falling back to debug signing.
- The keystore is injected from GitHub Secrets; no key material exists in the repository.

### Required secrets

| Secret | Content |
|---|---|
| `KEYSTORE` | base64 of the keystore file |
| `KEY_ALIAS` | key alias |
| `STORE_PASSWORD` | keystore password |
| `KEY_PASSWORD` | key password |

## Key rotation

- Android: v3 lineage + proof-of-rotation, seamless for users.
- Windows: 无签名证书需要轮换；更换内核构建时同步更新提权服务内嵌的 SHA256 白名单。
