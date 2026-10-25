# 数据安全表验证记录（不缴费提审）

> 对 `data-safety-draft.md` 的**可核对**验证；与 `privacy-verification-record.md` 对齐。  
> 记录时点：2026-10-25 11:12 Asia/Shanghai  
> 关键词：`不收集`、`数据安全`、`不出售`、`验证记录`。

## 结论摘要

| 草稿主张 | 验证结果 | 证据 |
|---|---|---|
| 是否收集用户数据 → **否**（默认单机） | **通过（工程+文档口径）** | 隐私验证记录；无强制账号；存档本机 |
| 是否分享 / 出售 → **否** | **通过** | 无卖数 SDK 依赖；「不出售」贯穿隐私/listing |
| 广告 ID / 精准位置 → **永不** | **通过** | 静态扫描无 AdMob / advertising-id 依赖坐标 |
| 购买记录 → **无内购** | **通过** | listing / Play / MS 稿均写「无内购」；无 billing SKU |
| 崩溃日志 → 默认关 | **通过（文档口径）** | 草稿「可选」；密钥不进 git |

## 与隐私 / listing 交叉核对

| 主张 | 隐私验证 | 数据安全草稿 | listing |
|---|---|---|---|
| 不收集 | 通过 | 「否」 | 买断单机、存档本机 |
| 不出售 | 通过 | 「否」 | 无广告口径 |
| 无内购 | — | 「无内购」行 | `listing-copy-zh.md` / `en` / Play·MS |
| 崩溃可选 | 通过 | 仅当显式开启 | support 短答同口径 |

## 静态扫描（复跑）

```bash
# 期望：android/scripts/tools/store 无卖数或广告 SDK 依赖坐标
# （story 里的 adjust op / HTML 图标名不算）
rg -n -i 'firebase|admob|appsflyer|play-services-ads|advertising.?id' \
  project/android scripts tools docs/store || true
```

2026-10-25 扫描：命中仅出现在「禁止/不收集」叙述与无关 story `adjust` 操作符 → **可接受**。

## 上架前仍待人工

- [ ] Play Console「数据安全」表正式勾选与本文一致后**再**保存（本轨**不付费**提交）  
- [ ] 若开崩溃：更新本文 + `privacy-policy-draft.md` + 应用内开关  
- [ ] 与正式隐私 URL 一并挂出  

## 修订

| 日期 (Asia/Shanghai) | 变更 |
|---|---|
| 2026-10-25 11:12 Asia/Shanghai | 首份；对齐 #414 隐私/分级/导出验证记录族 |
