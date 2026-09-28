# 孝感麻将训练系统原型

冻结设计的 Wolfram Language 实现起点。当前完成一个可执行的 MVP 垂直切片：

`EventLog -> Replay -> DecisionContext -> Shanten/Ukeire -> DecisionAnalysis -> ReviewSelector -> TemplateCoach`

## 当前规则边界

`xiaogan-training-core-0.1` 仅实现用于验证牌效链路的封闭训练子集：三门数牌（万、筒、条）、每种四张、四面子一雀头、摸牌和打牌。没有把未核实的孝感地方规则（花牌、癞子、特殊和牌、副露、结算）当作已支持功能。

详见 [src/MetricSemantics.md](src/MetricSemantics.md)。每一种实际牌局必须记录一个不可变的 `RuleSetVersion`；新增或修正规则需要新版本。

运行时可读取 `Mahjong`Rules`RuleSetManifest` 与 `Mahjong`Analysis`AnalysisRevisionManifest` 作为版本清单；发布后只新增版本，不能改写既有标识符对应的语义。

## 运行测试

在 Mathematica / Wolfram Desktop 中执行：

```wl
Get[FileNameJoin[{NotebookDirectory[], "src", "Tests", "RunTests.wl"}]]
```

命令行环境可用时：

```sh
wolframscript -file src/Tests/RunTests.wl
```
