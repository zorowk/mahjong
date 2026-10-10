sourceDir = DirectoryName[DirectoryName[$InputFileName]];
Scan[Get, FileNameJoin[{sourceDir, #}] & /@ {"Core.wl", "Rules.wl", "Solver.wl", "Replay.wl", "Analysis.wl", "Coach.wl"}];
review[id_, delta_, loss_, rank_, ambiguous_: "low"] := <|"DecisionId" -> id, "SelectedAction" -> <|"Type" -> "Discard", "Tile" -> "1筒"|>,
  "BestActions" -> {<|"Type" -> "Discard", "Tile" -> "9条"|>}, "ShantenDelta" -> delta, "UkeireDelta" -> -loss, "SelectedRank" -> rank, "EvaluationAmbiguity" -> ambiguous|>;
evidence = <|"Subject" -> "D1", "Evidence" -> <|"Selected" -> "1筒", "Alternative" -> "9条", "SameShanten" -> True,
  "SelectedShanten" -> 1, "AlternativeShanten" -> 1, "SelectedUkeire" -> 14, "AlternativeUkeire" -> 22|>, "Interpretation" -> "TileEfficiency", "Constraints" -> {"current_evaluator_only_measures_tile_efficiency"}|>;
TestReport[{
  VerificationTest[Mahjong`Replay`Replay[{123}], Failure["InvalidEventLog", <||>], TestID -> "malformed-event-rejected"],
  VerificationTest[Lookup[Mahjong`Analysis`SelectReviews[{review["efficiency", 0, 30, 8], review["regression", 1, -8, 2]}], "DecisionId"], {"regression", "efficiency"}, TestID -> "shanten-before-ukeire"],
  VerificationTest[Mahjong`Analysis`SelectReviews[{review["ambiguous", 0, 2, 3, "high"]}], {}, TestID -> "ambiguous-not-reviewed"],
  VerificationTest[Length[Mahjong`Analysis`SelectReviews[review[ToString[#], 0, #, #] & /@ Range[8]]], 2, TestID -> "diversity-at-most-two-per-issue"],
  VerificationTest[Mahjong`Analysis`SelectReviews[{Join[review["optimal", 0, 0, 1], <|"BestActions" -> {<|"Type" -> "Discard", "Tile" -> "1筒"|>}|>]}], {}, TestID -> "optimal-not-reviewed"],
  VerificationTest[StringContainsQ[Mahjong`Coach`TemplateCoach[evidence], {"14", "22", "当前牌效模型"}], True, TestID -> "template-explains-source-numbers"],
  VerificationTest[Module[{received, result}, result = Mahjong`Coach`LLMCoach[evidence, Function[prompt, received = prompt; "证据解释"]]; {Keys[received], received["Evidence"] === evidence, result["RequiresEvidenceReview"]}], {{"Policy", "Evidence", "Instruction"}, True, True}, TestID -> "llm-provider-only-gets-policy-and-evidence"],
  VerificationTest[FailureQ[Mahjong`Coach`LLMCoach[evidence, Function[prompt, 42]]], True, TestID -> "nontext-llm-output-rejected"],
  VerificationTest[Module[{game, action, indexes}, game = Mahjong`Rules`CreateGame["index-test", 42]; action = First[Mahjong`Rules`LegalActions[Mahjong`Replay`Replay[game["Events"]]]];
    game = Join[game, <|"Events" -> Append[game["Events"], action]|>]; indexes = Mahjong`Replay`DecisionIndex[game]; {First[indexes]["EventOffset"], First[indexes]["SelectedAction"] === action}], {4, True}, TestID -> "decision-index-is-pre-action-offset"]
}]
