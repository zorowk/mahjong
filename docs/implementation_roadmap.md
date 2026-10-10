# 孝感麻将训练系统实施路线图

> 基线：`xiaogan_mahjong_training_design_v1_0_design_freeze.md`  
> 更新日期：2026-09-28  
> 原则：不修改冻结的核心事实模型；新增能力以新 `RuleSetVersion`、`AnalysisRevision`、Solver、Evaluator 或 Coach 接入。

### 2026-10-10 实施更新

- 保留 WL 作为核心实现语言；不迁移 Python。
- 求解器使用数值数组和派生缓存；增加边张、可见牌耗尽、非法输入及 Replay 失败传播用例。MUnit 当前 21/21 通过，测试内计时约 3 秒。
- 当前 revision 为 `2026-10-static-v2`，保留原 v1 manifest；边张搭子修正后不能混用两个版本的结果。
- `web/` 已提供固定牌例的本地训练页；数据由 `src/ExportTrainingExample.wls` 生成，支持选牌、候选排序、模板解释与证据查看。
- 当前网页读取 WL 预计算结果，尚未接入实时 Kernel；网页采用无依赖实现与 pnpm 项目配置，后续复杂页面再引入 React。
- 下一步优先完善卡五星 Solver（箭牌、七对、副露）和合法动作/响应流程，再接实时 Kernel 接口。

## 1. 当前状态

目前不是“全部实现完毕”，而是完成了一个可读、可测试的 MVP 骨架和牌效分析的最小垂直切片。

| 项目 | 状态 | 说明 |
| --- | --- | --- |
| EventLog 与 Replay | 已实现（子集） | 支持 `GameStart`、`Deal`、`Draw`、`Discard`、`GameEnd`。事件中的摸牌牌张是事实，不重跑随机数。 |
| Observation 与 LegalActions | 已实现（子集） | 仅覆盖当前轮到玩家打牌时的不同打张。 |
| Hu / Shanten / Ukeire | 已实现（子集） | 三门数牌、四副、门清、四面子一雀头。 |
| DecisionAnalysis | 已实现 | 包括候选评价、并列最优、competition ranking、向听/进张差异与 ambiguity。 |
| ReviewSelector / TemplateCoach | 已实现 | 按冻结文档的规则筛选；模板解释不依赖 LLM。 |
| LLMCoach | 仅有 prompt 投影 | 没有调用模型，也没有模型配置或端到端验证。 |
| MUnit 测试 | 已执行通过 | 2026-09-28 使用 Wolfram 15.0.1 执行，10/10 通过；完整候选动作分析仍需要性能优化。 |
| 完整孝感规则 | 未实现 | 不能把当前 `xiaogan-training-core-0.1` 当作地方规则的正式实现。 |

当前源码位于 `src/`，测试入口为 `src/Tests/RunTests.wl`。

## 2. 当前明确不支持的能力

以下能力不应在现阶段的输入中静默使用：

- 花牌、癞子、字牌、特殊和牌；
- 吃、碰、杠、抢杠、多人和、流局及完整结算；
- 牌墙、庄家、轮次、补花等完整对局状态；
- 真实对局导入、数据库或持久化 API；
- 外部 LLM 调用；
- 跨局 PatternBuilder、LearnerPattern、TrainingPlan；
- 胜率、放铳率、EV、Monte Carlo、对手模型和心理推断。

## 3. 实施顺序

### P0-A：让当前基线真正可执行

目标：先验证已有代码和指标语义，而不是继续堆叠功能。

1. 已在 Wolfram 15.0.1 环境执行 `src/Tests/RunTests.wl`，当前 10/10 通过。
2. 为 Hu、Shanten、Ukeire 增加边界案例：四张同牌、嵌张、边张、复合搭子、并列最优、可见牌耗尽。
3. 为每个案例同时记录“期望语义”和“期望结果”，不能只以某个第三方库输出为准。
4. 为 Shanten/Ukeire 的递归计算建立基准测试；当前完整测试约需 92 秒，后续在不改变指标语义的前提下优化。

验收：MUnit 全绿；每一个已实现指标都能在 `src/MetricSemantics.md` 找到对应定义和测试样例。

### P0-B：确认孝感规则语义并版本化

目标：将“训练核心子集”与真正的孝感规则清楚分开。

1. 收集权威或经确认的规则资料，并写成逐条的规则决策记录。
2. 对每条规则标注：影响牌集合、初始发牌、合法动作、状态转移、和牌判断、结算，或仅影响展示。
3. 确认是否有癞子、花牌、特殊和牌、吃碰杠限制、流局与结算等差异。
4. 创建新的不可变 `RuleSetVersion`，例如 `xiaogan-1.0`；不得改写现有 `xiaogan-training-core-0.1` 的语义。
5. 为每条地方规则增加正反例测试。

验收：规则清单经产品/规则负责人确认；所有实现规则都有测试；不支持的规则被显式拒绝或标记。

### P1：完整可重放对局

目标：在不改变 EventLog 为事实来源的前提下支持一局真实流程。

1. 扩展事件与 `ApplyEvent`：发牌、摸牌、打牌、吃、碰、杠、过、和、流局、终局。
2. 扩展 `GameState`：牌墙、回合、公开副露、庄家/局况，以及规则要求的公开标记。
3. 为每个事件实现前置条件验证；非法事件必须返回 `Failure`。
4. 实现 `result(state)`，把和牌/流局/结算结果和状态转移分开。
5. 使用完整 EventLog 做从 offset 0 到终局、以及任意 offset 的重放一致性测试。

验收：同一 EventLog 在任意时点重放均得到确定状态；不依赖 RNG；任何决策前 offset 均可还原合法动作与玩家观察。

### P2：完整牌效分析

目标：让 Evaluator 覆盖 P1 支持的真实决策，而上层接口保持不变。

1. 让 `HuQ`、`Shanten` 支持确认后的地方牌型和副露结构，或对不支持的结构返回明确 Failure。
2. 完善 `Ukeire` 的已见牌计算：自己的手牌、河牌、公开副露、亮倒及规则指定的公开信息。
3. 统一不同动作后的评价入口；打、吃、碰、杠等动作都产出 `ActionEvaluation`。
4. 验证 `SortKey = {Shanten, -Ukeire}` 的比较边界：只有同向听的候选才把进张差异作为主要证据。
5. 把 `DecisionIndex` 做成 EventLog 的可重建投影，而不是第三个事实来源。

验收：给定 `gameId + eventOffset + playerId + selectedAction`，可生成可复核的 `DecisionAnalysis`；并列最优动作不会被误报为错误。

### P3：复盘输出与 LLM 对照

目标：验证“结构化证据能否带来稳定解释”这一 MVP 产品假设。

1. 为 `ReviewSelector` 增加覆盖样例：向听退步优先、同向听进张损失、high ambiguity 排除、同类问题最多 N 个。
2. 固化 `CoachEvidence` schema，并确保其中不复制隐藏手牌、未来事件或结果偏见信息。
3. 保留 `TemplateCoach` 作为基线；为解释文本加 snapshot 测试。
4. 接入 LLM 时仅传入 `CoachPolicy + CoachEvidence`，记录模型标识、请求版本与原始输出，但不让模型计算指标。
5. 建立人工评审集，对 TemplateCoach 和 LLMCoach 比较准确性、稳定性、可读性、幻觉率与成本。

验收：同一份证据重复生成时，核心技术结论一致；每一项数字都可追溯回 `DecisionAnalysis`；解释不包含心理诊断、胜率或未来信息。

### P4：真实牌谱导入与分析批处理

目标：让 MVP 可用于真实对局而不改变事实/派生数据边界。

1. 定义输入格式适配器，把外部牌谱转换为 `RuleSetVersion + EventLog`。
2. 导入时做规则版本、事件顺序、牌张总数和公开信息校验。
3. 从 EventLog 重新投影 DecisionIndex，并批量生成指定 `AnalysisRevision` 的分析结果。
4. 将派生结果缓存为可删除产物；缓存键至少包含 game、decision、rule version 和 analysis revision。
5. 加入端到端样例牌谱与回归测试。

验收：删除全部派生缓存后，仍能从原始 EventLog 完整重建分析与复盘。

### P5：跨局模式与专项训练

目标：在积累足够可信的 `DecisionAnalysis` 后，验证重复问题是否可被识别和改善。

1. 实现运行时 `PatternBuilder[DecisionAnalysis[]] -> LearnerPattern[]`。
2. 先只聚合明确、可解释的条件，例如 `same_shanten_candidates` 下选择较低 Ukeire。
3. 输出 relevantCount、repeatedCount、evidenceRefs、analysisRevision；不输出人格或综合技能分。
4. 在足够数据后再增加 TrainingPlan 与 ReEvaluation，比较前后相同条件的错误率。

验收：每个 Pattern 都能列出证据决策；改用新的 AnalysisRevision 时能重新聚合，且旧结果不会被伪装为可直接比较。

### P6：高级推断（最后）

目标：仅在基础牌效和训练效果被验证后，新增风险和不完全信息分析。

候选：Belief、OpponentModel、MonteCarlo、PWin、PDealIn、EV。

约束：它们只能以新的 Evaluator 接入，不能反向改变 EventLog、Replay 或现有 `DecisionAnalysis` 的事实语义；不确定性必须由对应模型明确定义。

## 4. 最近三项建议工作

按风险和价值排序，下一步应是：

1. 配置可执行的 Wolfram Kernel 并跑通当前 MUnit 测试。
2. 确认孝感麻将的正式规则来源，完成 P0-B 的规则决策表。
3. 在已确认规则下扩展 P1 的事件、状态与重放测试。

在前两项完成前，不建议接入 LLM、数据库、PatternBuilder 或 Monte Carlo，因为它们会掩盖基础事实和评价是否可靠的问题。

## 5. 完成定义

MVP 完成不等于所有阶段完成。MVP 的完成条件是：

1. 已确认规则版本下的一局 EventLog 能完整重放；
2. 任意实际决策能恢复当时 Observation 和 LegalActions；
3. 全部候选动作有可检查的 Shanten、Ukeire 和排序；
4. 系统能从一局中选择少量清晰问题；
5. TemplateCoach 与 LLMCoach（如接入）都只能依据 CoachEvidence 解释；
6. 端到端测试与规则测试可在 CI 或固定 Wolfram 环境中重复执行。
