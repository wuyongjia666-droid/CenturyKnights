# 商店上架前总清单（不缴费）

## A. 工程可重复出包

- [ ] `bash scripts/build_windows.sh` 本机或 CI 成功  
- [ ] `bash scripts/build_android.sh` 本机或 CI 成功  
- [ ] `main-<sha8>` Release 双平台附件齐全  
- [ ] `python3 tools/ci/store_prep_check.py` 绿  
- [ ] `python3 tools/ci/store_packaging_dry_check.py` 绿  
- [ ] `python3 tools/ci/store_verify_records_check.py` 绿  
- [ ] 隐私/分级/导出**验证记录**过目（`*-verification-record.md`）  
- [ ] `python3 tools/ci/export_size_report.py` 绿  

## B. 崩溃 / 性能

- [ ] CI `ci` 聚合绿  
- [ ] mobile/desktop gate 绿  
- [ ] 横屏 AVD 冒烟无 P0（统一试玩时勾）  
- [ ] perf 未破 `tools/ci/perf_budget.json`（或已书面调预算）  

## C. 商店页（文案已有草稿）

- [ ] 短描述 / 完整描述定稿（见 `listing-copy-zh.md` / `listing-copy-en.md`）  
- [ ] Play / MS 完整字段稿过目（`play-listing-full.md` / `ms-store-listing-full.md`）  
- [ ] 隐私政策草稿 + 分级意图（`privacy-policy-draft.md` / `age-rating-draft.md`）  
- [ ] 五张截图按清单拍齐（`screenshots-checklist.md`）  
- [ ] 数据安全表预填过目（`data-safety-draft.md`；默认不收集）  
- [ ] 支持联系方式草稿过目（`support-contact-draft.md`）  
- [ ] 隐私政策 URL（若收崩溃日志）  
- [ ] 分级问卷草稿  

## D. 明确不做（今日授权）

- [x] 不付费正式提审  
- [x] 不 force-push  
- [x] 不提交 keystore / 密码  
- [x] 不开 Steam 页（路线 Steam 延后）

## E. 内容体量（与字数闸对齐）

- [ ] 季#1 NOVEL ≥12000 汉字（对标《那个字》/《回执上的灯》）  
- [ ] 季#2 NOVEL ≥12000 汉字（`store_prep` / scaffold 硬闸，禁止削弱）  
- [ ] 季#3 NOVEL ≥12000 汉字  
- [ ] Play / MS / listing-copy / privacy 非提纲：过目可粘贴  
- [ ] 统一试玩前自包 E2E（另刀）；本清单不代替玩

## F. 合入纪律

- [x] 禁止靠删掉 NOVEL too-thin 断言「变绿」  
- [x] 字数闸只升不降；要绿就写满中篇  
- [ ] CI `ci` 聚合绿后再自合  
