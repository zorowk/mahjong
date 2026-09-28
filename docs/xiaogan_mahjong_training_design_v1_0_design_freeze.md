# 孝感麻将训练系统实施方案 v1.0-design-freeze
## Design Frozen / Ready for Phase 0

> 原型技术：Wolfram Language / Mathematica  
> 产品目标：训练新手的牌效判断与复盘能力。  
> 架构原则：**思想可以复杂，但核心软件结构必须简单。**  
> 当前阶段：只验证“结构化动作评价 → 稳定复盘”这一条链路。

> 当前状态：**v1.0-design-freeze**。本文档只允许做勘误和术语一致性修正；任何架构变化必须进入后续独立设计版本，不得修改本冻结基线。

---

# 1. 产品目标

系统不是为了做一个功能完整的麻将娱乐平台，而是为了验证：

> 一局结束后，系统能否可靠找出 3～5 个真正值得新手复盘的牌效决策，并用明确、可验证的证据解释为什么。

第一阶段只关注：

- 规则正确；
- 对局可重放；
- 每个真实决策可重新分析；
- 能计算向听数、有效进张和候选动作排序；
- 能挑出少量高价值复盘点；
- AI 只能基于结构化证据解释，不自行发明麻将概率或心理结论。

第一阶段不验证：

- 完整胜率；
- 点炮概率；
- EV；
- Opponent Model；
- Monte Carlo；
- 心理画像；
- SkillProfile；
- 自动训练计划；
- 长期能力评分。

这些能力只有在基础动作评价被验证可靠后才进入系统。

---

# 2. 产品主链路

当前产品链路：

```text
PlayerDecision
      ↓
DecisionAnalysis
      ↓
ReviewSelector
      ↓
CoachEvidence
      ↓
LLM Explanation
```

未来长期数据积累后再增加：

```text
DecisionAnalysis[]
        ↓
PatternBuilder
        ↓
LearnerPattern[]
        ↓
TrainingPlan
        ↓
ReEvaluation
```

更高级的不完全信息推断最后加入：

```text
Inference
├── Belief
├── OpponentModel
└── MonteCarlo
```

`Inference` 不作为 MVP 的依赖。

---

# 3. 四个工程域

核心系统只划分为四个真实依赖域。

## 3.1 Core

负责“牌局真实发生了什么”。

```text
Core
├── RuleSet
├── GameState
├── Observation
├── Transition
├── LegalActions
└── Replay
```

注意：

这些是工程职责，不代表必须各自实现成 class、table 或 service。

MVP 里可以直接收敛成一个 `GameEngine`：

```text
GameEngine
├── initialState(ruleSet)
├── legalActions(state)
├── apply(state, action)
├── observe(state, player)
├── result(state)
└── replay(eventLog, eventOffset)
```

内部可以使用：

```text
Rule
Solver
Scoring
```

但不要提前拆出：

```text
RuleEngine
TransitionEngine
LegalActionGenerator
ObservationService
ReplayService
```

除非真实代码复杂度已经证明有必要。

---

## 3.2 Analysis

负责“某次实际决策，从牌效角度看怎么样”。

```text
Analysis
├── Shanten
├── Ukeire
├── ActionEvaluation
└── DecisionAnalysis
```

核心接口：

```text
Evaluator.evaluate(decisionContext)
    -> ActionEvaluation[]
```

MVP 的评价器只需要：

```text
ShantenUkeireEvaluator
```

以后可以新增：

```text
ProbabilityEvaluator
RiskEvaluator
EVEvaluator
```

但不改变上层数据结构。

---

## 3.3 Learning

负责“多局以后，哪些错误在反复出现”。

```text
Learning
├── Pattern
├── LearningCurve
└── ReEvaluation
```

第一阶段不需要真正实现持久化 `LearnerModel`。

更简单的方式：

```text
DecisionAnalysis[]
        ↓
PatternBuilder
        ↓
LearnerPattern[]
```

`LearnerModel` 暂时只是查询结果或视图。

只有未来性能需要时，再考虑 materialized view。

---

## 3.4 Application

负责“用户最后看到什么”。

```text
Application
├── ReviewSelector
├── CoachEvidence
├── Explanation
└── TrainingPlan
```

其中 MVP 只需要：

```text
ReviewSelector
CoachEvidence
Explanation
```

`TrainingPlan` 放到第二或第三阶段。

---

# 4. 高级能力独立为 Inference

高级模型不进入核心 MVP。

```text
Inference
├── Belief
├── OpponentModel
└── MonteCarlo
```

未来它们可以被某个 Evaluator 使用，例如：

```text
MonteCarloEvaluator
OpponentAwareEvaluator
```

但是：

```text
Core
Analysis
Learning
Application
```

都不能反向依赖某个具体 Inference 实现。

原则：

> 高级推断是插件能力，不是系统存在的前提。

---

# 5. Source of Truth 只有两个

系统尽量只承认两个真正的历史事实来源：

```text
RuleSetVersion
EventLog
```

其他内容原则上都应该支持重新生成：

```text
GameState
Observation
LegalActions
DecisionContext
ActionEvaluation
DecisionAnalysis
LearnerPattern
CoachEvidence
```

这意味着：

```text
solver v1 → v2
evaluator v1 → v3
```

时，可以直接：

```text
Replay
→ ReAnalyze
```

而不需要修改原始历史数据。

---

# 6. EventLog 是事实，不保存重复状态

牌局保存：

```text
Game
├── gameId
├── ruleSetVersion
├── createdAt
└── events[]
```

Event 示例：

```text
GAME_START
DEAL
DRAW
DISCARD
PENG
GANG
PASS
HU
GAME_END
```

事件本身只记录实际发生的内容。

例如：

```wl
<|
    "Type" -> "Discard",
    "Player" -> 1,
    "Tile" -> "3条"
|>
```

不在事件里重复保存：

```text
完整手牌
完整 Observation
所有合法动作
所有数学指标
```

这些都可以通过 Replay 重建。


## 6.1 随机结果必须进入 EventLog

所有影响状态转移、且不能从旧状态和玩家动作唯一推出的随机结果，都必须作为事实记录。

错误：

```text
Draw(player=1)
```

正确：

```text
Draw(
    player=1,
    tile=5筒
)
```

发牌同理。

因此 Replay 不重新执行 RNG。

Replay 的语义永远是：

```text
旧状态
+
已发生事实事件
→
新状态
```

而不是：

```text
seed
→
重新随机
→
希望得到一样结果
```

Random seed 可以用于调试或生成新局，但不能作为历史 Replay 的唯一依据。


---

# 7. DecisionIndex 是 EventLog 的轻量投影

不要再维护：

```text
DecisionState
MathematicalObservation
```

两个高度重叠的对象。

MVP 只需要：

```text
DecisionIndex
├── id
├── gameId
├── eventOffset
├── playerId
└── selectedAction
```

其中：

- `eventOffset` 用来重建当时牌局状态；
- `playerId` 决定观察视角；
- `selectedAction` 是实际行为；
- `outcomeRef` 可选，用于关联后续结果，但不参与当时决策评价。

关系：

```text
EventLog
    ↓ projection
DecisionIndex
```

`DecisionIndex` 只是为了查询方便保存的轻量索引，不是新的事实来源。

真正的 Source of Truth 仍然只有：

```text
RuleSetVersion
EventLog
```


## 7.1 eventOffset 的精确定义

统一规定：

```text
eventOffset =
last committed event before the player decision
```

例如：

```text
Event #57:
DRAW 5筒

Decision:
选择打3条

Event #58:
DISCARD 3条
```

则：

```text
eventOffset = 57
```

所以：

```text
Replay(eventOffset)
```

恢复的永远是：

> 玩家真正做决定之前能够看到的状态。

禁止某些 Decision 使用 action 前 offset、另一些使用 action 后 offset。


---

# 8. Observation 不作为长期事实保存

理论上玩家在第 \(t\) 步拥有：

\[
O_t
\]

但工程上不需要把完整 `Observation` 永久复制到每个 Decision。

通过：

```text
Replay(eventOffset)
    ↓
GameState
    ↓
observe(state, player, ruleSet)
```

即可重建。

`Observation` 必须是 Rule-defined Projection。

不要实现成：

```text
TrueState - opponentHands
```

因为规则可能决定：

```text
亮倒
公开副露
特殊状态
公开分数
动作历史
其他可见标记
```

哪些属于玩家可见信息。

因此：

> Observation 是规则定义下的可见世界投影，而不是简单字段删除。

如果未来性能不足，再增加 cache。

第一阶段不要为了“方便分析”提前制造大量快照。

原则：

> 数学概念不等于软件实体。

---

# 9. InformationHistory 只保留在理论中

理论上可以写：

\[
I_t=(O_{1:t},A_{1:t-1})
\]

但不实现：

```text
InformationHistory
```

实体。

因为：

```text
EventLog
+
Replay
+
Observation projection
```

已经能够恢复需要的信息。

---

# 10. DecisionContext 是运行时 projection，不是持久化实体

为了分析一次 Decision，运行时可以生成：

```text
DecisionContext
├── state
├── observation
├── legalActions
└── selectedAction
```

但是：

```text
DecisionContext
```

只存在于分析过程。

不要求入库。

这样既方便 Evaluator，又不会引入新的事实来源。

---

# 11. ActionMetrics 改成 ActionEvaluation

避免一个不断膨胀的：

```text
ActionMetrics
```

垃圾桶。

统一为：

```text
ActionEvaluation
├── action
├── sortKey
├── features
└── evaluatorVersion
```

MVP：

```text
features:
├── shanten
├── ukeire
└── effectiveTiles
```

未来某个更高级 Evaluator 可以输出：

```text
features:
├── pWin
├── pDealIn
└── objectiveEV
```

上层只依赖：

```text
sortKey
features
```

MVP 约定：

```text
sortKey = {
    Shanten,
    -Ukeire
}
```

并统一规定：

> `sortKey` 越小越优。

即：

```text
1. Shanten 更小优先
2. Shanten 相同，Ukeire 更大优先
```

第一版不再使用 `Score`，避免正负号方向和“分数越大还是越小”的歧义。

而不依赖具体算法。

---

# 12. Evaluator 是可替换策略

统一接口：

```text
Evaluator.evaluate(decisionContext)
    -> ActionEvaluation[]
```

MVP：

```text
ShantenUkeireEvaluator
```

未来：

```text
ProbabilityEvaluator
MonteCarloEvaluator
OpponentAwareEvaluator
EVEvaluator
```

Application 和 Learning 都不能假设某个 Evaluator 一定存在某个字段。

它们只能：

- 读取 evaluator 提供的 features；
- 根据 analysisRevision 知道当前使用的模型版本；
- 选择支持的解释策略。

---

# 13. MVP 不制造 EstimatedDecisionLoss

如果当前只有：

```text
Shanten
Ukeire
```

就不要输出：

```text
EstimatedDecisionLoss = 0.18
```

因为这个数字没有统一定义。

MVP 直接使用：

```text
selectedAction
bestActions[]
ShantenDelta
UkeireDelta
selectedRank
evaluationAmbiguity
```

例如：

```text
Selected: 3条
Best: 9筒
ShantenDelta: 0
UkeireDelta: -8
selectedRank: 4 / 11
```

这已经足够让新手理解：

> 这手没有增加向听数，但损失了 8 张有效进张。

只有未来真正定义统一：

\[
Q(a)
\]

后，再引入：

\[
\hat L
=
\hat Q(a^*)
-
\hat Q(a_{selected})
\]

---

# 14. DecisionAnalysis 是唯一分析结果对象

```text
DecisionAnalysis
├── decisionId
├── actionEvaluations[]
├── bestActions[]
├── selectedAction
├── selectedRank
├── evaluationAmbiguity
└── analysisRevision
```

`bestActions[]` 允许多个动作并列最优。

例如：

```text
打3条:
Shanten = 1
Ukeire = 18

打9筒:
Shanten = 1
Ukeire = 18
```

则：

```text
bestActions = [打3条, 打9筒]
```

判断：

```text
selectedAction ∈ bestActions
```

即可认为：

```text
optimal under current evaluator
```

不要人为制造唯一标准答案。

这里不重复保存完整 Observation。

需要解释时：

```text
decisionId
→ Decision
→ Replay
→ Observation
```

即可恢复。

---

# 15. evaluationAmbiguity 只回答“当前 evaluator 是否容易区分候选动作”

`evaluationAmbiguity` 不是牌局的客观难度。

它只表示：

> 在当前 `analysisRevision` 对应的 evaluator 下，候选动作是否容易被明显区分。

例如当前 evaluator 只看：

```text
Shanten
Ukeire
```

那么：

```text
evaluationAmbiguity = low
```

只意味着：

> 当前牌效模型认为差异明显。

以后增加：

```text
PDealIn
EV
OpponentModel
```

结论可能变化。

MVP 可以根据候选 `ActionEvaluation[]` 直接判断：

```text
如果最优集合与次优集合 Shanten 不同
→ low

如果 Shanten 相同但 Ukeire 差距明显
→ low / medium

如果多个候选几乎等价
→ high
```


---

# 16. MVP 不持久化 uncertainty

当前 MVP 的：

```text
Shanten
Ukeire
```

是确定性计算。

因此第一版不在 `DecisionAnalysis` 和 `CoachEvidence` 中持久化：

```text
uncertainty
confidence
```

未来引入：

```text
MonteCarlo
ProbabilityModel
Pattern statistics
```

后，再由对应 evaluator 输出自己的不确定性描述。

原则：

> 不为了未来接口完整而提前制造字段。

---

# 17. CoachEvidence 是数学模型与 LLM 之间的防火墙

LLM 不直接读取整局数据库。

先经过：

```text
DecisionAnalysis
      ↓
ReviewSelector
      ↓
CoachEvidence
      ↓
LLM
```

CoachEvidence 只保留解释需要的信息：

```text
CoachEvidence
├── subject
├── evidence[]
├── interpretation
└── constraints[]
```

例如：

```yaml
subject:
  G42-D18

evidence:
  - selected: 3条
  - alternative: 9筒
  - same_shanten: true
  - selected_ukeire: 14
  - alternative_ukeire: 22

interpretation:
  TileEfficiency

constraints:
  - do_not_infer_psychology
```

CoachEvidence 不复制完整 DecisionAnalysis。

---

# 18. CoachPolicy 是系统政策，不重复存进证据

系统统一维护：

```text
CoachPolicy
├── noCausalClaim
├── noPsychDiagnosis
├── noFutureKnowledge
├── noModelAsTruth
└── noOutcomeBias
```

运行时：

```text
Prompt =
CoachPolicy
+
CoachEvidence
```

只有某条证据特有的限制，才进入：

```text
constraints[]
```

例如：

```text
- current_evaluator_only_measures_tile_efficiency
```

---

# 19. ReviewSelector 使用规则排序，不使用综合分数

第一阶段 ReviewSelector 不做复杂 AI，也不创造：

```text
ReviewScore = 0.73
```

候选复盘点可以先过滤：

```text
selectedAction ∉ bestActions
AND
evaluationAmbiguity != high
```

然后按词典序排序：

```text
1. ShantenDelta descending
2. UkeireLoss descending
3. selectedRank descending
4. evaluationAmbiguity ascending
```

其中：

```text
ShantenDelta =
selectedShanten - bestShanten

UkeireLoss =
bestComparableUkeire - selectedUkeire
```

当 `ShantenDelta > 0` 时，优先解释向听退步。

只有在可比较的同向听候选之间，`UkeireLoss` 才作为主要牌效差异。

不要把不同语义强行压成一个统一浮点分数。

---

# 19.1 selectedRank 的并列规则

采用 competition ranking：

```text
1, 1, 1, 4
```

而不是：

```text
1, 2, 3, 4
```

如果三个动作在当前 evaluator 下完全等价，它们必须具有相同 rank。

字段统一为：

```text
selectedRank
```

避免 AI 把数学等价动作错误描述成“第一名”和“第二名”。

---

# 19.2 不长期保存 Top1Top2Gap

不要设计通用：

```text
Top1Top2Gap
```

因为：

```text
Shanten 差 1
```

与：

```text
Ukeire 差 8
```

不是同一种量。

需要时运行时计算：

```text
topGap:
    shantenDelta
    ukeireDelta
```

或者直接从：

```text
ActionEvaluation[]
```

判断 `evaluationAmbiguity`。

未来 ProbabilityEvaluator / EVEvaluator 加入后，也不需要继承一个语义模糊的历史字段。

---

# 19.3 重复错误使用 diversity rule，不使用 penalty

如果一局有很多同类问题：

```text
先正常排序 CandidateReview
↓
再 greedy select
↓
同一 issue 最多选择 N 个
```

例如：

```text
maxPerIssue = 2
```

最终一局可以得到：

```text
2 个牌效错误
1 个向听退步
1 个其他明显问题
```

而不是 5 个几乎相同的低 Ukeire 例子。

这样比 `duplicatePenalty` 更容易理解、实现和测试。

---

# 20. LLM 只做解释

LLM 的职责：

```text
解释
总结
组织语言
给出新手能理解的建议
```

LLM 不负责：

```text
胡牌判断
向听计算
有效进张计算
最佳动作计算
概率估计
心理诊断
```

例如数学层提供：

```text
selected = 3条
alternative = 9筒
same shanten
ukeire 14 vs 22
```

LLM 只转成：

> 这手两种打法都维持一向听，但打 3 条后只剩 14 张有效进张，而打 9 筒能保留 22 张，所以这一步主要损失在牌效率，而不是向听数。

---


# 20.1 同时实现 TemplateCoach baseline

`CoachEvidence` 已经高度结构化，因此简单牌效解释不一定需要 LLM。

Phase 3 同时实现：

```text
TemplateCoach
LLMCoach
```

两者输入完全相同：

```text
CoachEvidence
```

例如：

```text
same shanten
selected ukeire = 14
alternative ukeire = 22
```

TemplateCoach 可以直接生成：

> 两种打法都保持一向听，但打3条后有效进张只有14张，打9筒可以保留22张，因此打3条明显降低了牌效率。

比较：

```text
准确性
稳定性
可读性
用户理解程度
幻觉率
成本
```

如果最终发现：

```text
简单牌效复盘
→ TemplateCoach

复杂长期模式解释
→ LLMCoach
```

这是系统简化成功，而不是能力不足。

# 21. RuleSet 首先是行为，不是配置集合

不要把规则设计成巨大配置：

```text
allowRobbingKong = true
allowMultipleHu = false
liangdaoMode = ...
...
```

MVP 规则主要表现为行为：

```text
Rule
├── initialState()
├── legalActions()
├── apply()
├── isHu()
├── score()
└── terminalState()
```

保存的元数据只需要：

```text
RuleSetId
RuleSetVersion
```

如果某些小参数确实需要配置，可以内部使用。

但外部架构不要把“规则”理解成几十个 bool 的集合。

---

# 22. GameEngine 不提前拆 service

MVP 推荐：

```text
GameEngine
├── legalActions(state)
├── apply(state, action)
├── observe(state, player)
├── result(state)
└── replay(eventLog, offset)
```

内部：

```text
Rule
Solver
Scoring
```

不要先拆成：

```text
RuleEngine
TransitionEngine
LegalActionGenerator
ReplayEngine
StateProjectionService
```

只有出现明确的独立变化原因后再拆。

---

# 23. LearnerModel 暂时不持久化

第一阶段：

```text
DecisionAnalysis[]
        ↓
PatternBuilder
        ↓
LearnerPattern[]
```

即可。

不要先做：

```text
LearnerModel
├── SkillProfile
├── RiskPreference
├── BiasProfile
├── AttentionProfile
├── Calibration
└── ...
```

否则很快出现一致性问题：

```text
DecisionAnalysis 更新
→ LearnerModel 是否失效？

Evaluator 变更
→ SkillProfile 是否重算？

AnalysisRevision 变化
→ LearningCurve 是否重建？
```

MVP 不需要解决这些问题。

---

# 24. SkillProfile 第一版删除

不输出：

```text
tileEfficiency = 0.72
defense = 0.41
```

因为这些分数还缺少：

- 归一化定义；
- 难度校正；
- 跨版本可比性；
- 不同 evaluator 的兼容规则。

第一阶段只输出更可靠的 Pattern。

例如：

```text
Condition:
一向听

Pattern:
经常选择明显减少有效进张的动作

RelevantCount:
24

RepeatedCount:
8
```

这已经足够指导训练。

---

# 25. LearnerPattern 是“重复问题”，不是人格模型

建议：

```text
LearnerPattern
├── id
├── condition
├── issue
├── relevantCount
├── repeatedCount
├── evidenceRefs[]
└── analysisRevision
```

例如：

```text
condition:
  same_shanten_candidates

issue:
  frequently_selects_lower_ukeire

relevantCount:
  24

repeatedCount:
  8
```

不直接加入：

```text
psychologicalCause
personality
riskType
```

心理学解释属于未来研究层。

---

# 26. TrainingPlan 属于 Application

未来增加：

```text
TrainingPlan
├── target
├── evidenceRefs
├── exercises[]
├── metric
└── completionRule
```

例如：

```text
target:
  improve same-shanten discard selection

exercises:
  - 20 discard-choice problems

metric:
  lower repeatedCount / relevantCount

completionRule:
  error rate < 15% over next 30 relevant decisions
```

Exercise 是 TrainingPlan 的组成部分。

不需要独立 Training Layer。

---

# 27. ReEvaluation 也不需要独立服务层

本质上只是：

```text
旧 Pattern
+
新 DecisionAnalysis[]
        ↓
重新聚合
```

例如：

```text
Before:
8 / 24

After:
3 / 22
```

即可判断同类问题是否改善。

---

# 28. 版本管理统一成 AnalysisRevision

不要让每个业务对象携带：

```text
solverVersion
evaluationModelVersion
opponentModelVersion
policyVersion
...
```

定义：

```text
AnalysisRevision
```

例如：

```text
2026-09-static-v3
```

manifest：

```yaml
analysisRevision: 2026-09-static-v3

rules:
  xiaogan: 1.1

solver:
  shanten: v2

evaluator:
  shanten-ukeire: v7
```

业务分析结果只保存：

```text
analysisRevision
```

降低版本组合复杂度。

注意：

`RuleSetVersion` 仍属于原始牌局事实，因为它决定当时玩的是什么规则。

`AnalysisRevision` 属于派生分析版本。


## 28.1 AnalysisRevision 必须 immutable

已经发布并被历史 `DecisionAnalysis` 引用的 `AnalysisRevision`，其 manifest 永远不能修改。

例如：

```text
2026-09-static-v3
```

一旦定义：

```yaml
rules:
  xiaogan-1.1

solver:
  shanten-v2

evaluator:
  shanten-ukeire-v7
```

以后不能偷偷把：

```text
shanten-v2
```

替换成：

```text
shanten-v2.1
```

必须创建新的：

```text
2026-09-static-v4
```

否则历史分析无法复现。

## 28.2 RuleSetVersion 同样 immutable

例如：

```text
xiaogan-1.1
```

一旦被某局 EventLog 引用，就不能改变其规则语义。

如果修正规则实现或语义：

```text
xiaogan-1.1
→
xiaogan-1.1.1
```

或者：

```text
xiaogan-1.2
```

旧牌局永远按照原 RuleSetVersion 重放。

这是 Source of Truth 成立的前提。


---

# 29. 事实与派生数据严格分开

## 事实

```text
RuleSetVersion
EventLog
```

`DecisionIndex` 是从 EventLog 投影出来的轻量索引，只用于查询，不构成新的 Source of Truth。

## 派生

```text
GameState
Observation
LegalActions
DecisionContext
ActionEvaluation
DecisionAnalysis
LearnerPattern
CoachEvidence
TrainingPlan
```

原则：

> 派生数据可以删除并重新生成，事实不能靠推导猜回来。

---

# 30. 缓存是优化，不是模型

如果以后发现：

```text
Replay 太慢
Observation 重建太慢
ActionEvaluation 太贵
```

可以增加：

```text
StateCache
ObservationCache
AnalysisCache
```

但缓存必须满足：

```text
delete cache
→ 系统仍然正确
```

这可以避免缓存变成新的 Source of Truth。

---

# 31. Mathematica 原型目录

第一阶段建议只有：

```text
Mahjong/
    Core.wl
    Rules.wl
    Solver.wl
    Analysis.wl
    Replay.wl
    Coach.wl
    Tests/
```

可能职责：

```text
Core.wl
    GameEngine
    state/action/event 基础结构

Rules.wl
    孝感麻将规则

Solver.wl
    hu
    shanten
    ukeire

Analysis.wl
    evaluator
    decision analysis
    review selector

Replay.wl
    event replay
    decision reconstruction

Coach.wl
    CoachEvidence
    CoachPolicy
    LLM prompt / explanation
```

先不要建立：

```text
mahjong-game/
mahjong-decision/
mahjong-observation/
mahjong-learner/
mahjong-coach/
mahjong-training/
mahjong-inference/
```

等真实依赖增长以后再拆。

---

# 32. Wolfram 中的数据表示保持简单

优先使用：

```wl
Association
List
Dataset
```

而不是一开始构建大量自定义 Symbol 类型。

例如事件：

```wl
<|
    "Type" -> "Discard",
    "Player" -> 1,
    "Tile" -> "3条"
|>
```

DecisionIndex：

```wl
<|
    "Id" -> "G42-D18",
    "GameId" -> "G42",
    "EventOffset" -> 57,
    "PlayerId" -> 1,
    "SelectedAction" -> <|"Type" -> "Discard", "Tile" -> "3条"|>
|>
```

ActionEvaluation：

```wl
<|
    "Action" -> <|"Type" -> "Discard", "Tile" -> "9筒"|>,
    "SortKey" -> {1, -22},
    "Features" -> <|
        "Shanten" -> 1,
        "Ukeire" -> 22,
        "EffectiveTiles" -> {...}
    |>,
    "EvaluatorVersion" -> "shanten-ukeire-v1"
|>
```

MVP 的动作排序直接使用词典序 `SortKey`：

```text
先最小化 Shanten
再最大化 Ukeire
```

甚至不必强行压成单个浮点数。

---

# 33. MVP 的动作排序统一使用 SortKey

第一版完全不需要：

\[
Q(a)=0.732
\]

统一定义：

```text
SortKey = {
    Shanten,
    -Ukeire
}
```

约定：

```text
SortKey 越小越优
```

即：

```text
1. Shanten 更小优先
2. Shanten 相同，Ukeire 更大优先
```

工程上可以直接：

```wl
SortBy[actionEvaluations, #["SortKey"] &]
```

不要同时维护另一种 `Score` 方向约定。

---

# 34. 第一版 evaluationAmbiguity 保持朴素

例如：

```text
if shanten(top1) != shanten(top2):
    evaluationAmbiguity = low

else if ukeireGap >= 6:
    evaluationAmbiguity = low

else if ukeireGap >= 3:
    evaluationAmbiguity = medium

else:
    evaluationAmbiguity = high
```

以后再根据数据调整。

不要一开始引入：

```text
Entropy
Bayesian uncertainty
confidence model
```

---

# 35. MVP ReviewSelector 只做规则排序

例如：

```text
CandidateReview
=
selectedAction ∉ bestActions
AND
evaluationAmbiguity != high
```

优先级：

```text
1. ShantenDelta > 0
2. UkeireDelta 大
3. selectedRank 差
4. 同类错误不要重复出现太多次
```

最后：

```text
Take[sorted, UpTo[5]]
```

够了。

---

# 36. MVP 只验证一个产品假设

阶段 1 假设：

> 结构化动作评价是否能够让 AI 给出稳定、可验证、比原始牌谱更好的复盘？

成功标准：

- 数学证据可以人工检查；
- AI 不需要看隐藏未来；
- 同一分析结果重复生成解释时核心结论一致；
- 用户能理解为什么这一步更差；
- 一局只挑出少量真正有价值的问题。

如果这一点做不好，后面的长期学习模型没有意义。

---

# 37. 第二阶段产品假设

只有阶段 1 成立后，才验证：

> 多局 DecisionAnalysis 是否能够发现稳定重复的弱点？

这时才增加：

```text
PatternBuilder
LearnerPattern
LearningCurve
```

核心仍然不是评分，而是：

```text
什么问题
在什么条件下
重复出现多少次
是否正在改善
```

---

# 38. 第三阶段产品假设

再验证：

> 针对这些 LearnerPattern 生成的专项训练，是否真的改善同类决策？

这时加入：

```text
TrainingPlan
ReEvaluation
```

而不是一开始就把训练系统全部建完。

---

# 39. 第四阶段才考虑 Inference

等基础牌效训练确实有价值以后，再加入：

```text
Belief
OpponentModel
MonteCarlo
PWin
PDealIn
EV
```

这时才真正进入：

```text
不完全信息
风险
对手推断
高级博弈
```

而且这些能力仍然应该以：

```text
new Evaluator
```

的方式接入，而不是重写整个系统。

---

# 40. 心理学只保留为未来解释约束

心理学仍然重要，但不进入 MVP 核心对象。

以后可以基于长期 Pattern 研究：

- outcome bias；
- loss aversion；
- over-attack after near-tenpai；
- recent-loss behavior；
- attention shift。

但是工程规则是：

```text
先观察行为
再做统计
最后才允许提出心理学解释
```

不能：

```text
从一次出牌
→ 推断心理状态
```

所以 MVP 的 CoachPolicy 默认：

```text
noPsychDiagnosis = true
```

---

# 41. 数学、经济学、心理学、哲学的位置重新定义

这些理论不再映射成软件层。

它们的作用分别是：

## 数学

帮助定义：

```text
如何计算
如何比较
如何验证
```

## 经济学 / 决策论

未来帮助定义：

```text
风险
收益
机会成本
效用
```

## 心理学

未来帮助解释：

```text
为什么某类偏差反复出现
```

## 哲学

约束：

```text
不能用事后信息评价当时决策
不能把模型输出当真理
不能把结果等同于决策质量
```

它们是：

> 设计思想与约束。

不是：

> 必须存在的 class。

---

# 42. Source of Truth 关系图

```text
        RuleSetVersion
              │
              ▼
           EventLog
              │
              ▼
            Replay
              │
              ▼
          GameState
              │
       ┌──────┴──────┐
       ▼             ▼
 Observation    LegalActions
       └──────┬──────┘
              ▼
       DecisionContext
              │
              ▼
          Evaluator
              │
              ▼
      DecisionAnalysis
              │
              ▼
       ReviewSelector
              │
              ▼
        CoachEvidence
              │
              ▼
             LLM
```

其中真正的持久事实尽量只有：

```text
RuleSetVersion
EventLog
```

---

# 43. MVP 最终架构

```text
                    RuleSet
                       │
                       ▼
EventLog ─────────> Game Core
                       │
                       ▼
                Decision Analysis
                       │
                       ▼
                 ReviewSelector
                       │
                       ▼
                  CoachEvidence
                       │
                       ▼
                      LLM
```

除此之外都不是 MVP 必需。

---

# 44. MVP 最终功能列表

真正第一版只实现：

```text
1. RuleEngine / GameEngine
2. Game + Replay
3. LegalActions
4. Hu / Shanten / Ukeire
5. ShantenUkeireEvaluator
6. DecisionAnalysis
7. ReviewSelector
8. CoachEvidence
9. TemplateCoach
10. LLMCoach
```

甚至：

```text
LearnerPattern
```

都可以先不做。

---

# 45. MVP 验收标准

一局结束后，系统必须能够：

## 45.1 重放

```text
EventLog
+
RuleSetVersion
```

完整重建牌局。

## 45.2 重建任意决策

给定：

```text
gameId
eventOffset
playerId
```

可以恢复：

```text
Observation
LegalActions
SelectedAction
```

## 45.3 分析所有候选打张

至少计算：

```text
Shanten
Ukeire
EffectiveTiles
```

## 45.4 生成 DecisionAnalysis

能够明确得到：

```text
bestActions[]
selectedAction
ShantenDelta
UkeireDelta
selectedRank
evaluationAmbiguity
```

## 45.5 选择复盘点

一局挑出：

```text
3～5
```

个真正明显的问题。

## 45.6 生成可验证解释

解释中的所有技术结论，都可以追溯回：

```text
CoachEvidence
```

而不是 LLM 自己生成。

---

# 46. 一个完整 MVP 示例

玩家实际：

```text
打3条
```

Replay 得到当前状态。

Evaluator 输出：

```text
9筒
Shanten = 1
Ukeire = 22

3条
Shanten = 1
Ukeire = 14

7条
Shanten = 1
Ukeire = 17
```

DecisionAnalysis：

```yaml
decisionId: G42-D18

selectedAction:
  discard: 3条

bestActions:
  - discard: 9筒

shantenDelta: 0
ukeireDelta: -8
selectedRank: 3
evaluationAmbiguity: low
analysisRevision: 2026-09-static-v1
```

CoachEvidence：

```yaml
subject:
  G42-D18

evidence:
  - selected: 3条
  - alternative: 9筒
  - same_shanten: true
  - selected_ukeire: 14
  - alternative_ukeire: 22

interpretation:
  TileEfficiency

constraints:
  - current_evaluator_only_measures_tile_efficiency
```

LLM：

> 这一手主要问题是牌效率。打 3 条和打 9 筒都保持一向听，但打 3 条后只剩 14 张有效进张，而打 9 筒能保留 22 张。也就是说，你没有让牌型退步，但明显减少了未来改善手牌的机会。

整个链路没有：

```text
EV
心理推断
胜率
点炮概率
SkillScore
```

但已经能产生明确训练价值。

---

# 47. 第二阶段再增加 PatternBuilder

当累计足够多 DecisionAnalysis 后：

```text
DecisionAnalysis[]
        ↓
PatternBuilder
        ↓
LearnerPattern[]
```

例如：

```yaml
condition:
  same_shanten_candidates

issue:
  selects_lower_ukeire

relevantCount:
  24

repeatedCount:
  8

evidenceRefs:
  - G12-D7
  - G18-D14
  - G22-D6
```

用户看到：

> 最近 24 次“向听数相同、需要比较有效进张”的决策中，有 8 次选择了明显较差的打张。

这比：

```text
牌效率 62 分
```

更可靠。

---

# 48. 长期高级数据以后再加

之前讨论的：

- 波动；
- variance；
- tail risk；
- relative risk；
- odds ratio；
- interaction effect；
- rolling statistics；
- change point；
- learning rate；
- calibration drift；

都仍然有价值。

但它们应该满足两个条件：

```text
1. 已经有足够历史数据
2. 已经存在稳定、可解释的基础 DecisionAnalysis
```

因此这些不删除理论价值，只从核心架构中后置。

---

# 49. 不提前建立高阶统计实体

以后需要高阶统计时，优先：

```text
DecisionAnalysis[]
    ↓
Wolfram Dataset
    ↓
query / aggregate / model
```

而不是马上创建：

```text
VarianceProfile
TailRiskProfile
RelativeRiskProfile
LearningRateProfile
```

除非实际产品需求证明这些结果需要持久化。

---

# 50. Mathematica 的优势仍然保留

虽然架构被大幅简化，但使用 Wolfram 仍然有意义。

它特别适合：

```text
Dataset
GroupBy
Counts
SortBy
MovingAverage
Quantile
Correlation
LinearModelFit
EstimatedDistribution
```

也就是说：

> 工程结构简单，不等于分析能力简单。

我们只是避免把每一种数学概念都变成软件对象。

---

# 51. 未来替换能力

该结构必须允许：

## 替换 Solver

```text
ShantenSolver v1
→ ShantenSolver v2
```

原始 EventLog 不变。

## 替换 Evaluator

```text
ShantenUkeireEvaluator
→ ProbabilityEvaluator
```

上层仍然接收：

```text
ActionEvaluation[]
```

## 替换 AI

```text
LLM A
→ LLM B
```

CoachEvidence 不变。

## 替换规则

新牌局选择：

```text
RuleSetVersion = xiaogan-1.2
```

旧牌局仍然按照旧版本重放。

---

# 52. 删除对象的判断标准

以后每新增：

```text
class
struct
table
layer
module
metric
```

都先问：

> 如果删除这个东西，系统是否仍然能够完整表达同一事实？

如果答案是：

```text
可以
```

那么它大概率不应该进入核心系统。

第二个问题：

> 这个东西是不是可以由 EventLog + RuleSetVersion + AnalysisRevision 重新计算？

如果答案是：

```text
可以
```

它应该优先被视为：

```text
projection / cache / derived data
```

而不是 Source of Truth。

---

# 53. 数据设计原则

最终坚持：

```text
事实只记录一次
分析结果可以重算
缓存随时可以删除
模型版本集中管理
AI 不拥有事实判断权
```

具体来说：

```text
RuleSetVersion
EventLog
```

是根。

```text
DecisionAnalysis
```

是某个 AnalysisRevision 下的派生结果。

```text
CoachEvidence
```

是解释投影。

```text
LearnerPattern
```

是长期聚合。

它们的地位不能混淆。

---

# 54. 最终实施顺序

## Phase 0：规则、指标语义和算法验证

先定义：

```text
Tile representation
Rule semantics
FormalMetricSemantics
```

然后实现并测试：

```text
Hu
Shanten
Ukeire
LegalActions
```

尤其必须先精确定义 `Ukeire`：

```text
什么叫有效进张？
是否只统计降低向听数的牌？
同向听但改善结构是否算？
已见牌如何扣除？
自己手牌中的同牌如何扣除？
副露后如何计算？
地方特殊规则是否改变有效牌定义？
```

原则：

> 所有 MVP 指标都必须有明确文字定义 + 自动测试样例。

不要只验证算法与某个外部库结果一致。

首先要验证：

> 大家到底在算同一个东西。

## Phase 1：完整对局

```text
GameEngine
EventLog
Replay
```

## Phase 2：决策分析

```text
DecisionIndex
DecisionContext
Evaluator
DecisionAnalysis
```

## Phase 3：复盘

```text
ReviewSelector
CoachEvidence
TemplateCoach
LLMCoach
```

两种 Coach 使用完全相同的 `CoachEvidence`。

到这里才是 MVP 完成。

## Phase 4：多局重复模式

```text
PatternBuilder
LearnerPattern
```

## Phase 5：专项训练

```text
TrainingPlan
ReEvaluation
```

## Phase 6：高级推断

```text
Belief
OpponentModel
MonteCarlo
Probability
EV
```

---

# 55. 当前明确不做

为了防止 MVP 再次膨胀，第一版明确不做：

```text
SkillProfile
心理画像
RiskPreference
ProbabilityCalibration
PWin
PDealIn
EV
MonteCarlo
OpponentModel
BeliefState 持久化
完整 LearnerModel
复杂 TrainingPlan
高级统计 Dashboard
```

不是这些不重要。

而是：

> 它们现在还不是验证产品价值的最短路径。

---

# 56. 最终工程哲学

这个系统可以拥有很复杂的理论背景：

- 概率；
- 博弈；
- 心理；
- 经济学；
- 决策论；
- 信息论；
- 行为统计。

但是核心工程结构应该始终保持：

```text
事实
↓
重建
↓
分析
↓
筛选
↓
解释
```

也就是：

```text
EventLog
↓
Replay
↓
DecisionAnalysis
↓
ReviewSelector
↓
CoachEvidence
↓
LLM
```

未来需要更多能力时：

> 增加新的分析器，而不是重写核心事实模型。

---

# 57. 一句话定义

> **用最少的核心对象记录真实牌局，用可替换的数学 Evaluator 重新分析玩家决策，再把少量可验证证据交给 AI 解释；先把“一局复盘是否真的有训练价值”做对，再逐步扩展长期学习和高级博弈模型。**

---

# 58. 最重要的原则

> **数学可以复杂，数据可以丰富，理论可以深，但 Source of Truth、对象模型和依赖关系必须尽可能简单。**

以及：

> **不要在还没有复杂度之前，设计复杂度的解决方案。**

---

# 59. 设计冻结：进入实现

到 v1.0-design-freeze 为止，设计冻结，不再做新的架构重构。

核心链路冻结为：

```text
RuleSetVersion + EventLog
        ↓
      Replay
        ↓
   DecisionContext
        ↓
      Evaluator
        ↓
  DecisionAnalysis
        ↓
   ReviewSelector
        ↓
    CoachEvidence
        ↓
    Explanation
```

未来扩展：

```text
new Solver
new Evaluator
new Inference
new Coach
```

都通过替换或增加分析器完成。

不要修改核心事实模型。

实现顺序：

```text
Phase 0
├── Tile representation
├── Rule semantics
├── FormalMetricSemantics
├── Hu tests
├── Shanten tests
├── Ukeire tests
└── LegalActions tests

Phase 1
├── EventLog
├── GameEngine.apply
└── Replay

Phase 2
├── DecisionIndex
├── DecisionContext
├── ShantenUkeireEvaluator
└── DecisionAnalysis

Phase 3
├── ReviewSelector
├── CoachEvidence
├── TemplateCoach
└── LLMCoach
```

到这里完成 MVP。

最终原则保持：

```text
事实只记录一次
派生结果可以重算
缓存可以全部删除
版本必须不可变
规则决定观察世界
Evaluator 决定分析标准
LLM 只解释证据
能排序就不要创造综合分数
能投影就不要制造新实体
能模板解决就不要强依赖 LLM
```

> **下一阶段的目标不再是设计一个更漂亮的架构，而是用代码和测试证明这个架构真的成立。**
