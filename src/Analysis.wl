BeginPackage["Mahjong`Analysis`", {"Mahjong`Rules`", "Mahjong`Solver`", "Mahjong`Replay`"}]

AnalysisRevision::usage = "AnalysisRevision identifies this immutable evaluator manifest.";
AnalysisRevisionManifest::usage = "AnalysisRevisionManifest identifies every versioned dependency of the evaluator.";
AnalysisRevisionManifests::usage = "AnalysisRevisionManifests retains immutable historical and current dependency manifests.";
EvaluateActions::usage = "EvaluateActions[decisionContext] returns ActionEvaluation associations.";
AnalyzeDecision::usage = "AnalyzeDecision[decisionId, decisionContext] creates the sole derived decision-analysis object.";
SelectReviews::usage = "SelectReviews[analyses] filters and lexicographically selects diverse, clear review points.";
AnalyzeGame::usage = "AnalyzeGame[game, player] reconstructs and evaluates actual discard decisions before selecting reviews.";

Begin["`Private`"]

AnalysisRevision = "2026-10-kawuxing-v3";
AnalysisRevisionManifest = <|"AnalysisRevision" -> AnalysisRevision, "Rules" -> <|"training" -> RuleSetVersion, "xiaogan" -> CurrentKawuxingVersion|>, "Solver" -> <|"shanten" -> "open-seven-pairs-v3"|>, "Evaluator" -> <|"shanten-ukeire" -> "v3"|>|>;
AnalysisRevisionManifests = <|
  "2026-09-static-v1" -> <|"AnalysisRevision" -> "2026-09-static-v1", "Rules" -> <|"xiaogan" -> RuleSetVersion|>, "Solver" -> <|"shanten" -> "standard-structure-v1"|>, "Evaluator" -> <|"shanten-ukeire" -> "v1"|>|>,
  "2026-10-static-v2" -> <|"AnalysisRevision" -> "2026-10-static-v2", "Rules" -> <|"xiaogan" -> RuleSetVersion|>, "Solver" -> <|"shanten" -> "standard-structure-v2"|>, "Evaluator" -> <|"shanten-ukeire" -> "v2"|>|>,
  AnalysisRevision -> AnalysisRevisionManifest
|>;
actionEqualQ[a_, b_] := SameQ[KeySort[a], KeySort[b]];

EvaluateActions[context_Association] := Module[{hand, visible, actions, version, melds},
  version = context["State"]["RuleSetVersion"];
  If[!MemberQ[{RuleSetVersion, CurrentKawuxingVersion}, version],
    Return[Failure["UnsupportedAnalysisRuleSet", <|"MessageTemplate" -> "Current evaluator supports training and kawuxing 1.1 discard decisions only."|>]]];
  hand = context["Observation"]["Hand"]; visible = context["Observation"]["VisibleTiles"];
  melds = context["State"]["Melds"][context["Observation"]["Player"]];
  actions = Select[context["LegalActions"], #["Type"] === "Discard" &];
  Map[
    Function[action, Module[{after, u},
      after = DeleteCases[hand, action["Tile"], {1}, 1];
      u = Ukeire[after, visible, melds, version];
      <|"Action" -> action, "SortKey" -> {Shanten[after, melds, version], -u["Ukeire"]}, "Features" -> <|"Shanten" -> Shanten[after, melds, version], "Ukeire" -> u["Ukeire"], "EffectiveTiles" -> u["EffectiveTiles"]|>, "EvaluatorVersion" -> "shanten-ukeire-v3"|>
    ]], actions]
];

ambiguity[evaluations_] := Module[{sorted = SortBy[evaluations, # ["SortKey"] &], a, b, gap},
  sorted = DeleteDuplicatesBy[sorted, #["SortKey"] &];
  If[Length[sorted] < 2, Return["low"]]; a = sorted[[1, "Features"]]; b = sorted[[2, "Features"]];
  If[a["Shanten"] != b["Shanten"], Return["low"]]; gap = a["Ukeire"] - b["Ukeire"];
  Which[gap >= 6, "low", gap >= 3, "medium", True, "high"]
];

AnalyzeDecision[decisionId_String, context_Association] := Module[{evaluations, sorted, bestKey, best, selected, bestFeature, selectedFeature, rank},
  evaluations = EvaluateActions[context]; If[FailureQ[evaluations], Return[evaluations]]; If[evaluations === {}, Return[Failure["NoLegalActions", <||>]]];
  sorted = SortBy[evaluations, # ["SortKey"] &]; bestKey = sorted[[1, "SortKey"]]; best = Select[sorted, # ["SortKey"] === bestKey &];
  selected = SelectFirst[sorted, actionEqualQ[# ["Action"], context["SelectedAction"]] &, Missing["SelectedActionNotLegal"]];
  If[MissingQ[selected], Return[Failure["SelectedActionNotLegal", <||>]]];
  bestFeature = best[[1, "Features"]]; selectedFeature = selected["Features"];
  rank = 1 + Count[sorted, e_ /; OrderedQ[{e["SortKey"], selected["SortKey"]}] && e["SortKey"] =!= selected["SortKey"]];
  <|"DecisionId" -> decisionId, "ActionEvaluations" -> sorted, "BestActions" -> best[[All, "Action"]], "SelectedAction" -> context["SelectedAction"], "SelectedRank" -> rank, "ShantenDelta" -> selectedFeature["Shanten"] - bestFeature["Shanten"], "UkeireDelta" -> selectedFeature["Ukeire"] - bestFeature["Ukeire"], "EvaluationAmbiguity" -> ambiguity[sorted], "AnalysisRevision" -> AnalysisRevision|>
];

issueType[analysis_] := If[analysis["ShantenDelta"] > 0, "shanten_regression", "lower_ukeire_same_shanten"];
SelectReviews[analyses_List] := SelectReviews[analyses, 5, 2];
SelectReviews[analyses_List, max_Integer] := SelectReviews[analyses, max, 2];

SelectReviews[analyses_List, max_Integer, maxPerIssue_Integer] := Module[{candidates, sorted, selected = <||>, result = {}, issue},
  candidates = Select[analyses, !MemberQ[# ["BestActions"], # ["SelectedAction"]] && # ["EvaluationAmbiguity"] =!= "high" &];
  sorted = SortBy[candidates, {-# ["ShantenDelta"], If[#["ShantenDelta"] == 0, -Max[0, -# ["UkeireDelta"]], 0], -# ["SelectedRank"], Switch[# ["EvaluationAmbiguity"], "low", 0, "medium", 1, _, 2]} &];
  Do[issue = issueType[analysis]; If[Lookup[selected, issue, 0] < maxPerIssue, AppendTo[result, analysis]; selected = Join[selected, <|issue -> Lookup[selected, issue, 0] + 1|>]], {analysis, sorted}];
  Take[result, UpTo[max]]
];

AnalyzeGame[game_Association, player_Integer] := Catch[Module[{decisions, analyses, state, a},
  decisions = Select[Mahjong`Replay`DecisionIndex[game], #["PlayerId"] == player && #["SelectedAction"]["Type"] === "Discard" &];
  analyses = Map[Function[d, state = Mahjong`Replay`Replay[game["Events"], d["EventOffset"]]; If[FailureQ[state], Throw[state]];
    a = AnalyzeDecision[d["Id"], Mahjong`Replay`DecisionContext[state, player, d["SelectedAction"]]]; If[FailureQ[a], Throw[a]]; a], decisions];
  <|"DecisionAnalyses" -> analyses, "Reviews" -> SelectReviews[analyses]|>
]];

End[]
EndPackage[]
