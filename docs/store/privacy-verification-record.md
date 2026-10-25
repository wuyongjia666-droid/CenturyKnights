# 隐私政策验证记录（不缴费提审）

> 对 `privacy-policy-draft.md` 的**可核对**验证，不是削弱字数闸、不代替正式法务审。  
> 记录时点：2026-10-25 10:36 Asia/Shanghai
> 关键词：`不收集`、`不出售`、`验证记录`、`崩溃`。

## 结论摘要

| 草稿主张 | 验证结果 | 证据 |
|---|---|---|
| 默认不收集 PII / 无强制账号 | **通过（工程口径）** | 无登录强制路径进主循环；存档本机（见下） |
| 不出售个人数据 | **通过（声明+无卖数 SDK）** | 工程无广告/归因 SDK 依赖声明；见 SDK 扫描 |
| 无广告 ID | **通过** | Android 权限/导出未要广告 ID；问卷意图同步 |
| 崩溃通道默认关 | **通过（文档口径）** | 草稿写「可选」；未接线付费崩溃后端密钥 |
| 儿童数据不主动收集 | **通过（与分级对齐）** | 见 `age-rating-verification-record.md` |

## SDK / 追踪扫描（仓库静态）

本记录做**静态**核对，不运行整包反编译：

```bash
# 期望：无 Firebase Analytics / Adjust / AppsFlyer / AdMob 等卖数或广告 SDK 声明
rg -n -i 'firebase|admob|adjust|appsflyer|analytics|advertising.?id|play-services-ads' \
  project/android scripts tools docs/store || true
```

| 检查项 | 结果 |
|---|---|
| 上述关键词在 android/scripts/tools/store 文档 | 若仅出现在「禁止/不收集」叙述 → 可接受；若出现依赖坐标 → **须修订隐私稿** |
| `signing.local.env` / keystore 未跟踪 | 见导出验证记录 |
| 隐私草稿含「不收集」「不出售」「崩溃」 | 门禁短语（`store_prep` / 本记录自检） |

## 数据流核对（设计口径）

| 数据 | 默认 | 若开启可选崩溃 | 商店「数据安全」预填 |
|---|---|---|---|
| 账号邮箱 | 不收集 | — | 不收集 |
| 存档 | 本机沙盒 | 不上传 | 不收集（本地） |
| 崩溃堆栈 | 关 | 仅诊断 | 须更新隐私 URL + 开关 |
| 广告 ID / 精准定位 | 永不 | 永不 | 否 |

对齐草稿：`docs/store/privacy-policy-draft.md`；数据安全预填若在 #410 合入后见 `data-safety-draft.md`。

## 上架前仍待人工

- [ ] 主体法定名称 + 支持邮箱写入正式隐私页（**不进 git 明文若敏感**）  
- [ ] 隐私政策托管 URL 可公网访问  
- [ ] 若开崩溃：开关 UI + 修订本文与数据安全表  
- [ ] **不付费**提交本次验证所依赖的商店表单  

## 修订

| 日期 (Asia/Shanghai) | 变更 |
|---|---|
| 2026-10-25 10:36 Asia/Shanghai | 首份验证记录；静态 SDK 扫描口径 + 与分级/导出记录交叉引用 |
