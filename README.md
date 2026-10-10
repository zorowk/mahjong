# 孝感麻将训练系统原型

冻结设计的 Wolfram Language 实现起点。当前已有一个通过测试的训练子集原型和本地固定牌例网页：

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

当前已使用本机 Wolfram 15.0.1 验证 21 个测试通过。优化后的完整 MUnit 求值约 3 秒（不含 Kernel 启动），测量依赖机器和缓存状态。

## 本地网页训练

在项目根目录生成 WL 分析数据（使用 `Get` 加载，避免当前命令行环境的中文编码问题）：

```sh
/Applications/Wolfram.app/Contents/MacOS/wolframscript -code 'Get["src/ExportTrainingExample.wls"]'
```

然后启动网页：

```sh
cd web
npx --yes pnpm@10.20.0 dev
```

打开 `http://127.0.0.1:5173`，选择一张牌并确认，即可查看候选打张、有效进张和可追溯的模板复盘。也可直接执行 `node web/server.mjs`（在项目根目录）。

这一阶段网页使用无框架 HTML/CSS/JavaScript，无第三方运行依赖，包管理配置与锁文件使用 pnpm。后续加入多局导航和实时 Kernel 接口时再引入 React；当前所有数学结果和中文复盘由 WL 生成，浏览器只显示固定牌例的预计算结果。

网页数据验证：在 `web/` 下执行 `npx --yes pnpm@10.20.0 test`。生成的 `web/data/training-example.json` 是可重建的示例产物。

当前分析仅支持 `xiaogan-training-core-0.1` 的门清手牌。卡五星规则事件已有初步实现，但副露与七对尚未接入评价器，因此对卡五星分析请求会返回明确 Failure。网页未公开部署，也未调用外部 LLM。
