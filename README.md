# 百年骑士·同型原创 / CenturyKnights

**原作同型玩法研究项目**（系统级致敬，非素材/剧情/地图 1:1 复制，非破解反编译）。

- 引擎：Godot 4.3
- 工作标题（中）：百年骑士·同型原创
- 工程 ID（英）：CenturyKnights
- 垂直切片：约 30–45 分钟「第零章·灰旗初升」加长闭环（程序立绘/战旗 → 战棋 → 招募 → 城堡 → 联姻遗传 → 岁月）

## 快速运行

```bash
cd project
godot --path .
# 冒烟
godot --headless --path . --scene res://tests/smoke_runner.tscn
# 战棋 e2e（模拟点击选→移→攻）
godot --headless --path . --scene res://tests/tactics_e2e.tscn
# CI 全套（失败非 0）
../scripts/run_ci.sh
```

## Windows 试玩包

见 GitHub Releases 最新：`CenturyKnights-windows-v0.4.1.zip`（战技+第三~三章地图+氛围音乐+多帧战旗棋子；教学战仍约 4 vs 2）。

## 20 分钟怎么玩

1. **新的旗号** → 起姓起名选纹章色  
2. 第零章对白推进 → **隘口之夜**战棋教学（歼灭）  
3. **烽火酒馆**招募 1 人  
4. 进入 **灰旗堡** 枢纽  
5. **联姻廷**：看「子嗣期望」→ 成婚  
6. 推进一月 **初啼**，打开族谱看血胤混合条  
7. **岁月沙漏**跳至丰收月 → 生成 **王朝手记**

## 目录

| 路径 | 说明 |
|------|------|
| `project/` | Godot 工程 |
| `_bmad-output/planning-artifacts/` | GDD / epics / sprint |
| `docs/style-bible.md` | 美术风格占位稿 |
| `exports/` | Windows 导出（本地） |

## 边界

- 原创剧情、地名、家族名、UI 文案（简体中文）
- 禁止：反编译、搬运对标资产与原文、复用 GeneRanch
