# Code signing policy

**Free code signing provided by [SignPath.io](https://about.signpath.io), certificate by [SignPath Foundation](https://signpath.org).**

## Team roles

| Role | Members |
|---|---|
| Committers and reviewers | [@ipevel](https://github.com/ipevel) |
| Approvers | [@ipevel](https://github.com/ipevel) |

Every change reaches `main` through a pull request, and `main` requires the `analyze-test` check to pass. All team members use multi-factor authentication for both GitHub and SignPath access.

## Privacy policy

This program will not transfer any information to other networked systems unless specifically requested by the user or the person installing or operating it.

Specifically:

- **Proxy traffic** goes only to the nodes the user configures, following the user's own rules.
- **Subscription and panel requests** go only to the address the user enters.
- **Latency tests and media-unlock checks** contact public third-party endpoints (`api.ip.sb`, `ip-api.com`, `api.bilibili.com` and similar) only when the user starts them.
- **Update checks** request `https://github.com/ipevel/ckbox/releases/latest` — a plain HTTPS GET that carries no device or user data. Automatic checks can be disabled in Settings; if the app has not checked for 28 days, one check runs regardless so that security updates are not missed.
- **No telemetry, analytics or crash reporting** is enabled in released builds.
- No account, device identifier or usage data is collected or uploaded.

## Signed artifacts (Windows)

| Artifact | Description |
|---|---|
| `Ckbox.exe` | Application UI (user mode) |
| `CkboxCore.exe` | Proxy core (Mihomo) |
| `CkboxHelperService.exe` | Privileged SYSTEM helper service |
| `WindowsLoopbackManager.exe` | UWP loopback exemption tool |
| `Ckbox-<version>-windows-<arch>-setup.exe` | Inno Setup installer |

Signing chain: CI builds unsigned binaries → signing service → signed binaries are downloaded back → the installer is packaged → the installer itself is signed.

Core trust chain: the core is signed first; its SHA256 is compiled into the helper service and verified before launch, so the helper only ever starts the official core.

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
- Windows: renew before expiry; on rotation, update the SHA256 whitelist compiled into the helper service.
