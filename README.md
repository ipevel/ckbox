# ⚡ Ckbox

**Ckbox 是一款多平台代理客户端（Android + Windows），基于 Bettbox 架构的完全重写，内核对齐 Clash.Meta（mihomo）。**

> 许可证：GPL-3.0（与参考源 Bettbox 及来源血统 FlClash/LiClash 兼容）
> 参考源：Bettbox v1.19.5（https://github.com/appshubcc/Bettbox）

## 定位

Ckbox = **「Bettbox 完整架构的照搬 + 面板账号体系的唯一新增」**。

- 双端统一 Flutter UI
- 内核：Bettbox 自 fork 的 Clash.Meta
- Windows 提权：Rust SYSTEM 常驻服务 + HMAC 命名管道 RPC
- 新增：面板账号登录 / 订阅管理 / 应用内自更新

## 项目状态

**当前：代码迁移完成 + 面板账号体系核心已实现。** 待编译验证与签名申请。

按 `ckbox-spec/ckbox-实施规格.md` 的执行顺序：

1. ✅ 建仓 + 许可（GPL-3.0）+ CI 骨架 + 签名流水线占位
2. ✅ 内核先行（core/ + Clash.Meta 迁移，纳入版本控制）
3. ✅ Dart 层搬迁（lib 127,936 行 + plugins 27,659 行，标识替换）
4. ✅ Rust 特权服务（按「取舍照搬不修」口径，含 D2-D6 缺陷照搬）
5. ✅ Windows 端组装（runner + Inno Setup + 打包）
6. ✅ Android 端组装（Kotlin + JNI + Manifest，包名 com.ckbox.app）
7. ⬜ 签名接入（SignPath 申请 + keystore 生成，占位已就绪，需用户）
8. ✅ 产品增量：面板账号体系（模型 + 客户端 + 存储 + 登录 UI）

> 口径：26 条缺陷按用户「取舍照搬不修」全部照原样保留，仅做标识替换（bettbox→ckbox）。

## 规格文档

- 实施规格：`ckbox-spec/ckbox-实施规格.md`
- 面板接口深读：`ckbox-spec/ckbox-面板接口深读.md`
- 上游同步基线：`ckbox-spec/ckbox-bettbox同步基线.md`（**只追 Bettbox 稳定版，不追测试版**）

## 上游跟随

- 当前跟随 Bettbox **v1.19.5**（稳定版），策略见同步基线文档。
- 只追 `vX.Y.Z` 稳定版，不追 `-pre*`/`-test` 测试版；同步由维护者触发。

## 构建

待双端组装完成后补充（CI 骨架见 `.github/workflows/build.yaml`）。
