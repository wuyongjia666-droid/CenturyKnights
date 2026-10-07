# Release v0.2.0-polish

- URL: https://github.com/wuyongjia666-droid/CenturyKnights/releases/tag/v0.2.0-polish
- Asset: https://github.com/wuyongjia666-droid/CenturyKnights/releases/download/v0.2.0-polish/CenturyKnights-windows-v0.2.0-polish.zip
- ZIP SHA256: `6a0707204f24ef632a35499aaff57092b9d62577f5a371b2b139bbb148e45c87`
- EXE SHA256: `9455c23be776f3d46d41e8e782b7a3dad35ab902d823d48ba269a56e062710da`

## 升级亮点
1. **人物立绘 / 棋子**：程序生成原创肖像与战棋 token（发色/瞳色/职业甲/武器剪影），团长金环，敌军可辨。
2. **战旗**：纹章色绑定姓氏燕尾旗，主菜单/立姓/章节/战斗顶栏可见。
3. **第零章加长**：13 个节拍（0.0–0.6 含中间叙事），对白与选择明显加长。
4. **精品 UI**：Theme/StyleBox、羊皮纸面板、枢纽双行导航、空态文案、委任榜扩到 6 单。
5. **战斗手感**：移动蓝格、攻击红格、伤害飘字、回合横幅、HP 条、选中脉冲、胜负面板。
6. 教学战平衡仍约 **4 vs 2**（v0.1.3）。

## Verify
```
./scripts/run_ci.sh
# smoke + layout + tactics_e2e + full_chain_e2e PASS
```
