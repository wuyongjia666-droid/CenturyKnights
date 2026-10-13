# 岁课自动结算（按性格）

> 日期：2026-10-13。生日卡不再让玩家点左右；按孩子性格自动落一边，只读回执。

## 为什么

人生事件已经改成随机只读。岁课留给 1–15 岁家中孩子：一年一张，但「父母替孩子点」打断了节奏。用户要求按小孩性格自动选，手不再点。

## 左右语义（卡面字段）

| 侧 | 口吻 | 常见字段 |
|---|---|---|
| **左 / follow** | 稳妥、照料、纠正、抓住 | `care`、`pay`、`wil`/`per`/`skl`+、习痕 `watch`/`copy`/`ledger`/`lamp` |
| **右 / let** | 大胆、冒险、忍着、甩掉 | `trait: scarred/malnourished`、`str`/`agi`/`vit`+、习痕 `seize`/`slip`/`furnace`、`survivor` |

夭折档（`yao`）两侧多半都是碑词；仍按风险分排序，稳妥侧偏好 `halt_march` / 士气损失更小的碑。

## 性格轴

**大胆**加分：禀性 `brave`/`temper`/`scarred`/`iron_gut`/`sturdy`/`night_owl`/`lucky`；习痕 seize/slip/furnace/hone/bridge；力敏体高于 8；早教武路；可见血征。

**稳妥**加分：禀性 `scholar`/`keen_eye`/`charmer`/`heir_mark`/`malnourished`；习痕 watch/copy/ledger/lamp/lie_age/tide；意感知能高于 8；早教文路。

`personality_bias = bold − careful`。`> 0.75` 选风险最高选项；`< −0.75` 选风险最低；中间用种子 `hash(id|year|card_id|sui_pick)` 打散，读档不变。

## 结算流

1. 生日月 `on_month` 抽卡 → `fire_and_resolve_card`
2. 按偏好顺序试 `resolve`（看护锁 / 私囊不够则试下一侧）
3. 成功写入 `sui_inbox`（标题、正文、落哪一侧、效果提示），**不留** `sui_pending`
4. 旧档未决的 `sui_pending` 在 `ensure` / 月初排空
5. 城堡待办「未读岁课」→ `sui_yearcard` 只读回执，「知道了」ack

## 与人生事件

人生事件（`life_events`）另 PR 改随机；岁课本 PR 只动 `sui_ke.*` 与回执页，文件不冲突。
