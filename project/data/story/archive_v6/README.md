# archive_v6

`lint_corpus.json` 是对白 lint 的永久反例，用来证明规则真的会响。

NAR-02 把旧的模板章搬进这个目录时，请保留该文件。门禁只要求 `data/story/chapters/` 零违规；本目录预期有违规，测试若发现这里一片干净，会失败。

NAR-02 的决定：**不保留旧卷重玩入口。** `scenes/story/chapter1.tscn` … `chapter234.tscn` 与对应脚本已删除。模板 JSON 仍留在 `data/chapterN.json`，因为 CORE-01 的 `CKStoryState` 按这个路径懒加载，`story_state_check` 会读第 11 章。那些 JSON 是封存文本，不是主线。播放器不读它们。
