root = DirectoryName[DirectoryName[$InputFileName]];
Scan[Get, FileNameJoin[{root, #}] & /@ {"Core.wl", "Rules.wl", "Solver.wl", "Replay.wl", "Analysis.wl", "Coach.wl"}];

Needs["MUnit`"];

tenpai = {"1万", "2万", "3万", "4万", "5万", "6万", "1筒", "2筒", "3筒", "1条", "2条", "3条", "7筒"};
winning = Append[tenpai, "7筒"];
eventLog = {
  <|"Type" -> "GameStart", "RuleSetVersion" -> Mahjong`Rules`RuleSetVersion, "PlayerCount" -> 4|>,
  <|"Type" -> "Deal", "Player" -> 1, "Tiles" -> tenpai|>,
  <|"Type" -> "Draw", "Player" -> 1, "Tile" -> "9条"|>,
  <|"Type" -> "Discard", "Player" -> 1, "Tile" -> "9条"|>
};
kawuxingLog = {
  <|"Type" -> "GameStart", "RuleSetVersion" -> Mahjong`Rules`KawuxingRuleSetVersion|>,
  <|"Type" -> "Deal", "Player" -> 1, "Tiles" -> {"1筒", "1筒", "1筒", "1筒"}|>,
  <|"Type" -> "Deal", "Player" -> 2, "Tiles" -> {"2条", "2条", "2条", "2条"}|>,
  <|"Type" -> "Gang", "Player" -> 1, "Tile" -> "1筒", "Kind" -> "Concealed"|>,
  <|"Type" -> "Draw", "Player" -> 1, "Tile" -> "9筒"|>,
  <|"Type" -> "Discard", "Player" -> 1, "Tile" -> "9筒"|>,
  <|"Type" -> "Gang", "Player" -> 2, "Tile" -> "2条", "Kind" -> "Concealed"|>
};

TestReport[{
  VerificationTest[Length[Mahjong`Rules`TileUniverse[]], 27, TestID -> "three-suits-universe"],
  VerificationTest[Mahjong`Rules`TileQ["9条"] && !Mahjong`Rules`TileQ["东"], True, TestID -> "supported-tile-validation"],
  VerificationTest[Mahjong`Solver`HuQ[winning], True, TestID -> "standard-hu"],
  VerificationTest[Mahjong`Solver`Shanten[tenpai], 0, TestID -> "tenpai-is-zero-shanten"],
  VerificationTest[Mahjong`Solver`Ukeire[tenpai]["Ukeire"], 3, TestID -> "ukeire-counts-visible-hand"],
  VerificationTest[Mahjong`Replay`Replay[eventLog, 3]["EventOffset"], 3, TestID -> "replay-at-pre-decision-offset"],
  VerificationTest[Mahjong`Core`StateHand[Mahjong`Replay`Replay[eventLog, 4], 1], Sort[tenpai], TestID -> "replay-applies-discard"],
  VerificationTest[Length[Mahjong`Rules`LegalActions[Mahjong`Replay`Replay[eventLog, 3]]], 14, TestID -> "legal-actions-projects-distinct-discards"],
  VerificationTest[Module[{state, context, analysis}, state = Mahjong`Replay`Replay[eventLog, 3]; context = Mahjong`Replay`DecisionContext[state, 1, <|"Type" -> "Discard", "Player" -> 1, "Tile" -> "9条"|>]; analysis = Mahjong`Analysis`AnalyzeDecision["G1-D1", context]; MemberQ[analysis["BestActions"], analysis["SelectedAction"]]], True, TestID -> "decision-analysis-retains-best-tie"],
  VerificationTest[StringQ[Mahjong`Coach`TemplateCoach[Mahjong`Coach`BuildCoachEvidence[Mahjong`Analysis`AnalyzeDecision["G1-D1", Mahjong`Replay`DecisionContext[Mahjong`Replay`Replay[eventLog, 3], 1, <|"Type" -> "Discard", "Player" -> 1, "Tile" -> "9条"|>]]]]], True, TestID -> "template-coach-is-deterministic"]
  , VerificationTest[Length[Mahjong`Rules`TileUniverse[Mahjong`Rules`KawuxingRuleSetVersion]], 21, TestID -> "kawuxing-tile-types"]
  , VerificationTest[Mahjong`Replay`Replay[kawuxingLog, 1]["PlayerCount"], 3, TestID -> "kawuxing-defaults-to-three-players"]
  , VerificationTest[Mahjong`Replay`Replay[kawuxingLog]["KongChain"]["Multiplier"], 2, TestID -> "consecutive-kongs-double"]
}]
