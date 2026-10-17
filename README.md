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

**当前：规划 / 建仓阶段。**

实施按 `ckbox-spec/ckbox-实施规格.md` 的执行顺序推进：

1. ✅ 建仓 + 许可 + CI 骨架
2. ⬜ 内核先行（core/ + Clash.Meta 迁移）
3. ⬜ Dart 层搬迁（lib/ + 标识替换）
4. ⬜ Rust 特权服务重写
5. ⬜ Windows 端组装
6. ⬜ Android 端组装
7. ⬜ 签名接入
8. ⬜ 产品增量（面板/订阅/自更新）

## 规格文档

- 实施规格：`ckbox-spec/ckbox-实施规格.md`
- 面板接口深读：`ckbox-spec/ckbox-面板接口深读.md`

## 构建

待双端组装完成后补充（CI 骨架见 `.github/workflows/build.yaml`）。
