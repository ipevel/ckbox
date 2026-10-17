# Ckbox 代码签名政策

> ckbox 使用**自有证书**签名，不使用任何第三方项目的签名身份。

## Windows

- **签名身份**：自有代码签名证书（OV/EV）。
- **签名对象**：
  - `Ckbox.exe` — 主程序（用户态 UI）
  - `CkboxCore.exe` — 内核进程
  - `CkboxHelperService.exe` — SYSTEM 提权服务
  - Inno Setup 安装器
- **签名链路**：CI 构建产出未签名二进制 → 提交签名服务 → 下载已签名产物 → 打包安装器 → 安装器自身再签名。
- **内核信任链**：内核先签名，其 SHA256 编译进提权服务，启动前校验，确保被启动的始终是官方内核。
- 待办：申请 SignPath Foundation（免费开源签名）或自建 CA，拿到 `organization-id` / `project-slug` 后填入 `.github/workflows/build.yaml`。

## Android

- **签名身份**：自有 keystore（PKCS12，`CN=Ckbox`）。
- **签名方案**：显式启用 **v2 + v3**，关闭 v1。v3 的 lineage 为未来密钥轮换保留证据链。
- **禁止降级**：无 keystore 时 release 构建直接失败，不允许静默回落到 debug 签名产出「伪 release」包。
- **密钥管理**：keystore 由 CI 从 GitHub Secrets 注入，仓库内不存在任何密钥文件。

### 所需 Secrets

| Secret | 内容 |
|---|---|
| `KEYSTORE` | keystore 文件的 base64 编码 |
| `KEY_ALIAS` | 密钥别名 |
| `STORE_PASSWORD` | keystore 密码 |
| `KEY_PASSWORD` | key 密码 |

## 密钥轮换

- Android 通过 v3 lineage + proof-of-rotation 完成密钥轮换，用户端平滑过渡。
- Windows 证书到期前续签，轮换时同步更新内核信任链中的 SHA256 白名单。
