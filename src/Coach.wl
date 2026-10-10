BeginPackage["Mahjong`Coach`", {"Mahjong`Analysis`"}]

CoachPolicy::usage = "CoachPolicy contains system-wide explanatory constraints.";
BuildCoachEvidence::usage = "BuildCoachEvidence[analysis] projects only explainable mathematical evidence.";
TemplateCoach::usage = "TemplateCoach[evidence] produces a deterministic Chinese explanation.";
LLMCoachPrompt::usage = "LLMCoachPrompt[evidence] returns constrained input for an external LLM, not a model call.";
LLMCoach::usage = "LLMCoach[evidence, generator] invokes an explicitly supplied provider with policy and evidence only.";

Begin["`Private`"]

CoachPolicy = <|"noCausalClaim" -> True, "noPsychDiagnosis" -> True, "noFutureKnowledge" -> True, "noModelAsTruth" -> True, "noOutcomeBias" -> True|>;

BuildCoachEvidence[analysis_Association] := Module[{selected, alternative, evaluations, lookup, s, a},
  selected = analysis["SelectedAction"]; alternative = First[analysis["BestActions"]]; evaluations = analysis["ActionEvaluations"];
  lookup[action_] := SelectFirst[evaluations, SameQ[# ["Action"], action] &]; s = lookup[selected]["Features"]; a = lookup[alternative]["Features"];
  <|"Subject" -> analysis["DecisionId"], "Evidence" -> <|"Selected" -> selected["Tile"], "Alternative" -> alternative["Tile"], "SameShanten" -> (s["Shanten"] == a["Shanten"]), "SelectedShanten" -> s["Shanten"], "AlternativeShanten" -> a["Shanten"], "SelectedUkeire" -> s["Ukeire"], "AlternativeUkeire" -> a["Ukeire"]|>, "Interpretation" -> If[s["Shanten"] == a["Shanten"], "TileEfficiency", "ShantenRegression"], "Constraints" -> {"current_evaluator_only_measures_tile_efficiency"}|>
];

TemplateCoach[evidence_Association] := Module[{e = evidence["Evidence"]},
  If[TrueQ[e["SameShanten"]] && e["SelectedUkeire"] == e["AlternativeUkeire"],
    Return["打" <> e["Selected"] <> "属于当前牌效模型的最优动作集合。向听数为" <> ToString[e["SelectedShanten"]] <> "，有效进张为" <> ToString[e["SelectedUkeire"]] <> "张；并列最优动作同样可以选择。"]];
  If[TrueQ[e["SameShanten"]],
    "这一手主要问题是牌效率。打" <> e["Selected"] <> "和打" <> e["Alternative"] <> "都保持" <> ToString[e["SelectedShanten"]] <> "向听，但前者有效进张为" <> ToString[e["SelectedUkeire"]] <> "张，后者为" <> ToString[e["AlternativeUkeire"]] <> "张；在当前牌效模型下，打" <> e["Alternative"] <> "能保留更多改善手牌的机会。",
    "这一手会让向听数从" <> ToString[e["AlternativeShanten"]] <> "增加到" <> ToString[e["SelectedShanten"]] <> "。在当前牌效模型下，打" <> e["Alternative"] <> "可以避免这一步退步。"
  ]
];

LLMCoachPrompt[evidence_Association] := <|"Policy" -> CoachPolicy, "Evidence" -> evidence, "Instruction" -> "仅解释给定证据；不得推断心理、胜率、点炮概率或未展示的未来信息；明确说明结论只适用于当前牌效评价器。"|>;

LLMCoach[evidence_Association, generator_] := Module[{text},
  text = Quiet[Check[generator[LLMCoachPrompt[evidence]], $Failed]];
  If[!StringQ[text] || StringLength[StringTrim[text]] == 0, Return[Failure["InvalidCoachResponse", <||>]]];
  <|"Subject" -> evidence["Subject"], "Explanation" -> text, "Source" -> "LLM", "RequiresEvidenceReview" -> True|>
];

End[]
EndPackage[]
