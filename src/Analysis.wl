BeginPackage["Mahjong`Analysis`", {"Mahjong`Rules`", "Mahjong`Solver`", "Mahjong`Replay`"}]

AnalysisRevision::usage = "AnalysisRevision identifies this immutable evaluator manifest.";
AnalysisRevisionManifest::usage = "AnalysisRevisionManifest identifies every versioned dependency of the evaluator.";
EvaluateActions::usage = "EvaluateActions[decisionContext] returns ActionEvaluation associations.";
AnalyzeDecision::usage = "AnalyzeDecision[decisionId, decisionContext] creates the sole derived decision-analysis object.";
SelectReviews::usage = "SelectReviews[analyses] filters and lexicographically selects diverse, clear review points.";

Begin["`Private`"]

AnalysisRevision = "2026-09-static-v1";
AnalysisRevisionManifest = <|"AnalysisRevision" -> AnalysisRevision, "Rules" -> <|"xiaogan" -> RuleSetVersion|>, "Solver" -> <|"shanten" -> "standard-structure-v1"|>, "Evaluator" -> <|"shanten-ukeire" -> "v1"|>|>;
actionEqualQ[a_, b_] := SameQ[KeySort[a], KeySort[b]];

EvaluateActions[context_Association] := Module[{hand, visible, actions},
  hand = context["Observation"]["Hand"]; visible = context["Observation"]["VisibleTiles"]; actions = context["LegalActions"];
  Map[
    Function[action, Module[{after, u},
      after = DeleteCases[hand, action["Tile"], {1}, 1];
      u = Ukeire[after, visible];
      <|"Action" -> action, "SortKey" -> {Shanten[after], -u["Ukeire"]}, "Features" -> <|"Shanten" -> Shanten[after], "Ukeire" -> u["Ukeire"], "EffectiveTiles" -> u["EffectiveTiles"]|>, "EvaluatorVersion" -> "shanten-ukeire-v1"|>
    ]], actions]
];

ambiguity[evaluations_] := Module[{sorted = SortBy[evaluations, # ["SortKey"] &], a, b, gap},
  If[Length[sorted] < 2, Return["low"]]; a = sorted[[1, "Features"]]; b = sorted[[2, "Features"]];
  If[a["Shanten"] != b["Shanten"], Return["low"]]; gap = a["Ukeire"] - b["Ukeire"];
  Which[gap >= 6, "low", gap >= 3, "medium", True, "high"]
];

AnalyzeDecision[decisionId_String, context_Association] := Module[{evaluations, sorted, bestKey, best, selected, bestFeature, selectedFeature, rank},
  evaluations = EvaluateActions[context]; If[evaluations === {}, Return[Failure["NoLegalActions", <||>]]];
  sorted = SortBy[evaluations, # ["SortKey"] &]; bestKey = sorted[[1, "SortKey"]]; best = Select[sorted, # ["SortKey"] === bestKey &];
  selected = SelectFirst[sorted, actionEqualQ[# ["Action"], context["SelectedAction"]] &, Missing["SelectedActionNotLegal"]];
  If[MissingQ[selected], Return[Failure["SelectedActionNotLegal", <||>]]];
  bestFeature = best[[1, "Features"]]; selectedFeature = selected["Features"];
  rank = 1 + Count[sorted, e_ /; OrderedQ[{e["SortKey"], selected["SortKey"]}] && e["SortKey"] =!= selected["SortKey"]];
  <|"DecisionId" -> decisionId, "ActionEvaluations" -> sorted, "BestActions" -> best[[All, "Action"]], "SelectedAction" -> context["SelectedAction"], "SelectedRank" -> rank, "ShantenDelta" -> selectedFeature["Shanten"] - bestFeature["Shanten"], "UkeireDelta" -> selectedFeature["Ukeire"] - bestFeature["Ukeire"], "EvaluationAmbiguity" -> ambiguity[sorted], "AnalysisRevision" -> AnalysisRevision|>
];

issueType[analysis_] := If[analysis["ShantenDelta"] > 0, "shanten_regression", "lower_ukeire_same_shanten"];
SelectReviews[analyses_List, max_Integer : 5, maxPerIssue_Integer : 2] := Module[{candidates, sorted, selected = <||>, result = {}, issue},
  candidates = Select[analyses, !MemberQ[# ["BestActions"], # ["SelectedAction"]] && # ["EvaluationAmbiguity"] =!= "high" &];
  sorted = SortBy[candidates, {-# ["ShantenDelta"], -Max[0, -# ["UkeireDelta"]], -# ["SelectedRank"], Switch[# ["EvaluationAmbiguity"], "low", 0, "medium", 1, _, 2]} &];
  Do[issue = issueType[analysis]; If[Lookup[selected, issue, 0] < maxPerIssue, AppendTo[result, analysis]; selected = Join[selected, <|issue -> Lookup[selected, issue, 0] + 1|>]], {analysis, sorted}];
  Take[result, UpTo[max]]
];

End[]
EndPackage[]
