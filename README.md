# 孝感麻将训练系统原型

冻结设计的 Wolfram Language 原型。已有卡五星三人对局、可重放牌谱、打张分析及本机网页：

`EventLog -> Replay -> DecisionContext -> Shanten/Ukeire -> DecisionAnalysis -> ReviewSelector -> TemplateCoach`

## 当前规则边界

`xiaogan-kawuxing-1.1` 实现筒、条、中发白共 84 张的三人局：庄家 14 张、闲家 13 张，碰、三类杠、过、胡、抢加杠、一炮双响、亮倒、流局和结算。Solver 支持标准牌型、副露及七对；Evaluator 目前只评价打张，不评价碰杠或胡牌取舍。

规则以 [rules/1.md](rules/1.md) 为基线。海捞冲突和亮倒限制采用明确的原型约定，尚待规则负责人确认；底分为 1、无封顶，不代表现金结算。三龙七对计分未定义，不擅自补番型。详见 [规则决策](docs/kawuxing_rules_decisions.md)。旧 `xiaogan-training-core-0.1` 和 `xiaogan-kawuxing-1.0` 保留兼容，不改写其语义。

详见 [src/MetricSemantics.md](src/MetricSemantics.md)。每一种实际牌局必须记录一个不可变的 `RuleSetVersion`；新增或修正规则需要新版本。

运行时可读取 `Mahjong`Rules`RuleSetManifest` 与 `Mahjong`Analysis`AnalysisRevisionManifest` 作为版本清单；发布后只新增版本，不能改写既有标识符对应的语义。

## 运行测试

在 Mathematica / Wolfram Desktop 中执行：

```wl
Get[FileNameJoin[{NotebookDirectory[], "src", "Tests", "AllTests.wls"}]]
```

命令行环境可用时：

```sh
/Applications/Wolfram.app/Contents/MacOS/wolframscript -code 'Get["src/Tests/AllTests.wls"];Exit[0]'
```

本机 Wolfram 15.0.1 验证 62/62 通过，分为旧训练回归、卡五星规则、复盘应用三组。需要已授权的本机 Wolfram；测试耗时受 Kernel 启动和机器性能影响。

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

打开 `http://127.0.0.1:5173` 查看固定牌例；打开 `http://127.0.0.1:5173/game` 使用实时对局、牌谱导入/下载、历史重放和整局打张复盘。练习桌由用户控制三家，不是自动对手。也可直接执行 `node web/server.mjs`（在项目根目录）。

网页使用无框架 HTML/CSS/JavaScript，无第三方运行依赖，包管理使用 pnpm。Node 只提供本地 HTTP 和进程桥接，数学与规则仍由 WL 实现。实时接口每个请求启动一个 Kernel（30 秒超时、最多两个并行），只监听本机回环地址，不是公开部署服务。

默认 Wolfram 路径为 `/Applications/Wolfram.app/Contents/MacOS/wolframscript`；其他安装位置通过 `WOLFRAMSCRIPT` 环境变量指定。客户端 JSON 不被求值为 WL 代码。

网页数据验证：在 `web/` 下执行 `npx --yes pnpm@10.20.0 test`。生成的 `web/data/training-example.json` 是可重建的示例产物。

实时接口验证：`node --test web/integration.test.mjs`，需要可运行的 Wolfram。当前 revision 为 `2026-10-kawuxing-v3`。

TemplateCoach 可直接运行；`LLMCoach[evidence, generator]` 提供仅传入政策和证据的适配入口，尚未配置真实外部模型，也未完成人工解释评审。跨局模式、训练计划、胜率和 EV 不属于当前完成范围。完整进度见 [实施路线图](docs/implementation_roadmap.md)。
