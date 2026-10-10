# 孝感麻将训练系统实施路线图

> 基线：`xiaogan_mahjong_training_design_v1_0_design_freeze.md`
>
> 更新日期：2026-10-10
>
> 实现保留 Wolfram Language；冻结设计文档不修改。

## 当前完成范围

核心链路已可在本机运行：

`RuleSetVersion + EventLog -> Replay -> DecisionContext -> Evaluator -> ReviewSelector -> CoachEvidence -> TemplateCoach`

| 阶段 | 已实现 | 尚需完成 |
| --- | --- | --- |
| Phase 0 规则与指标 | 筒条箭牌、标准牌型、七对/龙七对/双龙七对、副露、向听与有效进张；计分组合；正反例测试 | 确认海捞与亮倒歧义；补正式规则样例与三龙七对定义 |
| Phase 1 完整对局 | 84 张事实牌墙，14/13/13 发牌，摸打碰杠，响应队列、胡牌优先、双响、抢杠、亮倒、流局与零和结算；完整流局日志重放 | 增加来自规则负责人的真实和牌/复杂杠链牌谱回归 |
| Phase 2 决策分析 | 前动作 offset 的 DecisionIndex；副露/七对打张分析；并列最优、competition ranking、版本 manifest | 碰杠等非打张动作需要独立定义评价语义；当前明确不评价 |
| Phase 3 复盘 | diversity 筛选、模板解释、同证据的 LLM 适配入口；实时网页、导入/下载/时间轴/整局复盘 | 真实 LLM 配置、证据忠实性人工评审、交互式浏览器 QA |

当前规则版本：`xiaogan-kawuxing-1.1`。当前分析版本：`2026-10-kawuxing-v3`。历史规则与 v1/v2 分析 manifest 保留，不覆盖旧标识符。1.1 中的原型约定如需变更，必须发布新规则版本。

源码仍放 `src/`；网页放 `web/`。Node 只做 HTTP 与 Kernel 桥接，不迁移数学实现。所有牌墙随机结果进入 EventLog，Replay 不运行 RNG。

## 验证入口

```sh
/Applications/Wolfram.app/Contents/MacOS/wolframscript -code 'Get["src/Tests/AllTests.wls"];Exit[0]'
node --test web/test.mjs
node --test web/integration.test.mjs
node web/server.mjs
```

`AllTests.wls` 汇总训练回归、卡五星规则和应用测试。集成测试实际启动 Wolfram，覆盖 UTF-8 JSON、发牌、打张分析、响应过牌、自动摸牌、历史重放、整局复盘和非法牌谱。

本次验证：Wolfram 15.0.1 下 62/62 通过，实时 Kernel/HTTP 集成 2/2 通过，固定牌例数据检查 1/1 通过；JavaScript 语法检查及 `git diff --check` 通过。未执行交互式浏览器 QA，不把接口通过等同于视觉/交互验收。

固定牌例可用 `src/ExportTrainingExample.wls` 重建。打开 `/game` 使用实时桌；三个玩家都由用户手动控制。页面没有自动对手，也未公开部署。

## 最近实施步骤

1. 确认 `rules/1.md` 中“无海捞”与末张翻倍的冲突，以及亮倒后的杠限制。当前约定见规则决策文档，不伪装为已确认事实。
2. 收集完整真实牌谱，覆盖清一色、四归一、卡五星、连续杠和各种结算组合；逐个把期望结果写入测试。补交互式浏览器验证。
3. 提供选定 LLM 的显式适配函数，只接收 `CoachPolicy + CoachEvidence`。不自动安装供应商或使用未知凭据。与模板解释对照评审准确性、稳定性、可读性、幻觉率及成本。
4. 对一个完整结束的牌局验收：可重放、任意打张可分析、选出少量明显问题、每个技术结论可追溯。问题不足时不强行凑 3～5 个；当前两类 issue 每类最多两个，最多选四个。

## 后续阶段（尚未实现）

### Phase 4：重复模式

在基础决策分析经真实样例验证、数据足够后实现纯投影 `PatternBuilder[DecisionAnalysis[]] -> LearnerPattern[]`。输出 condition、issue、relevantCount、repeatedCount、evidenceRefs 和 analysisRevision；不输出人格或 SkillScore，不混合分析版本。

### Phase 5：专项训练与重新评价

基于可信 Pattern 生成题目与完成规则，用相同条件和版本比较训练前后的错误率。TrainingPlan 属于 Application，不新增事实来源。

### Phase 6：高级推断

基础产品价值验证后，才通过新的 Evaluator 接入 Belief、OpponentModel、MonteCarlo、胜率、点炮概率或 EV。必须先定义指标及不确定性，不能由 LLM 编造。

## 完成定义

代码链路能运行不等于产品假设已验证。正式 MVP 验收还要求地方规则确认、真实牌谱测试和解释质量评审。上述后续阶段不是本次代码补齐的范围，不提前宣称“所有计划完成”。
