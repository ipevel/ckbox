# Ckbox 代码签名政策

> 步骤 7（签名接入）占位。ckbox 必须使用**自有证书**，不复刻 Bettbox 的 SignPath 项目与 Android LiClash 证书。

## Windows

- 目标：申请 **SignPath Foundation**（免费开源签名）或自建 CA + 自有证书。
- 待填：SignPath organization-id / project-slug。
- 签名对象：CkboxCore.exe、CkboxHelperService.exe、Ckbox.exe、安装器（Inno Setup）。

## Android

- 目标：自有 keystore（A4 缺陷修复：显式 v2 + v3 签名，保留 lineage）。
- keystore 由 CI 从 secrets 注入，本地不落盘、不提交。

## 密钥轮换（P1）

- Android v3 lineage + proof-of-rotation，为未来密钥轮换留证据链。
