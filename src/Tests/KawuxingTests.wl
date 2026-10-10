sourceDir = DirectoryName[DirectoryName[$InputFileName]];
Scan[Get, FileNameJoin[{sourceDir, #}] & /@ {"Core.wl", "Rules.wl", "Solver.wl", "Replay.wl", "Analysis.wl", "Coach.wl"}];
v = Mahjong`Rules`CurrentKawuxingVersion;
seven = {"1筒", "1筒", "2筒", "2筒", "3筒", "3筒", "4筒", "4筒", "6条", "6条", "中", "中", "白", "白"};
dragon = {"1筒", "1筒", "1筒", "1筒", "2筒", "2筒", "4筒", "4筒", "6条", "6条", "中", "中", "白", "白"};
honorWin = {"中", "中", "中", "发", "发", "发", "白", "白", "白", "1筒", "2筒", "3筒", "9条", "9条"};
openMelds = {<|"Type" -> "Peng", "Tile" -> "中"|>};
openHand = {"1筒", "2筒", "3筒", "4筒", "5筒", "6筒", "7条", "8条", "9条", "发", "发"};
baseGame = Mahjong`Rules`CreateGame["test", 42];
baseState = Mahjong`Replay`Replay[baseGame["Events"]];
pihu = {"1筒", "2筒", "3筒", "4筒", "5筒", "6筒", "7条", "8条", "9条", "1条", "2条", "3条", "白", "白"};
score[hand_, tile_] := Mahjong`Rules`WinScore[hand, {}, <|"Tile" -> tile|>];
respondState[huHand_] := Join[baseState, <|"Hands" -> <|1 -> {}, 2 -> Most[huHand], 3 -> Most[huHand]|>, "Melds" -> <|1 -> {}, 2 -> {}, 3 -> {}|>,
  "Phase" -> "Response", "LastDiscard" -> <|"Player" -> 1, "Tile" -> Last[huHand]|>, "Discards" -> <|1 -> {Last[huHand]}, 2 -> {}, 3 -> {}|>, "Responders" -> {2, 3}, "Responses" -> {}|>];

TestReport[{
  VerificationTest[Mahjong`Solver`HuQ[seven, {}, v], True, TestID -> "seven-pairs-hu"],
  VerificationTest[Mahjong`Solver`Shanten[Most[dragon], {}, v], 0, TestID -> "quad-counts-as-two-pairs"],
  VerificationTest[score[dragon, "白"]["Multiplier"], 8, TestID -> "dragon-seven-pairs-x8"],
  VerificationTest[score[honorWin, "9条"]["Patterns"]["大三元"], 8, TestID -> "big-three-dragons"],
  VerificationTest[score[pihu, "白"]["Multiplier"], 1, TestID -> "pihu-base-unit-one"],
  VerificationTest[score[{"中", "中", "中", "发", "发", "发", "白", "白", "1筒", "2筒", "3筒", "7条", "8条", "9条"}, "9条"]["Patterns"]["小三元"], 4, TestID -> "small-three-dragons"],
  VerificationTest[score[{"1筒", "1筒", "2筒", "2筒", "3筒", "3筒", "4筒", "4筒", "6筒", "6筒", "7筒", "7筒", "9筒", "9筒"}, "9筒"]["Multiplier"], 16, TestID -> "pure-seven-pairs-multiply"],
  VerificationTest[score[pihu, "5筒"]["Patterns"]["卡五星"], 2, TestID -> "winning-five-in-456-is-kawuxing"],
  VerificationTest[score[{"5筒", "5筒", "5筒", "5筒", "4筒", "6筒", "1条", "2条", "3条", "6条", "7条", "8条", "发", "发"}, "5筒"]["Patterns"]["暗四归一"], 4, TestID -> "concealed-four-return-one"],
  VerificationTest[Mahjong`Rules`WinScore[openHand, {<|"Type" -> "Peng", "Tile" -> "5筒"|>}, <|"Tile" -> "5筒"|>]["Patterns"]["明四归一"], 2, TestID -> "exposed-four-return-one"],
  VerificationTest[MemberQ[Lookup[Mahjong`Rules`LegalActions[respondState[pihu], 2], "Type"], "Hu"], False, TestID -> "pihu-cannot-win-on-discard"],
  VerificationTest[Module[{s}, s = Join[baseState, <|"Hands" -> <|1 -> pihu, 2 -> {}, 3 -> {}|>, "LastDraw" -> <|"Tile" -> "白", "Supplement" -> False|>|>]; MemberQ[Lookup[Mahjong`Rules`LegalActions[s], "Type"], "Hu"]], True, TestID -> "pihu-can-self-draw"],
  VerificationTest[Module[{s, tiles}, s = baseState; tiles = Join[Flatten[Values[s["Hands"]]], s["Wall"]]; Sort[tiles] === Sort[baseGame["Events"][[1]]["Wall"]]], True, TestID -> "deal-conserves-all-physical-tiles"],
  VerificationTest[Module[{wall, counts, log, s, tiles}, counts = Counts[baseGame["Events"][[1]]["Wall"]];
    wall = Join[pihu, Flatten[KeyValueMap[ConstantArray[#1, #2 - Count[pihu, #1]] &, counts]]];
    log = {<|"Type" -> "GameStart", "RuleSetVersion" -> v, "Dealer" -> 1, "Wall" -> wall|>}; s = Mahjong`Replay`Replay[log];
    Do[tiles = Take[s["Wall"], If[p == 1, 14, 13]]; AppendTo[log, <|"Type" -> "Deal", "Player" -> p, "Tiles" -> tiles|>]; s = Mahjong`Replay`Replay[log], {p, 3}];
    AppendTo[log, <|"Type" -> "Hu", "Player" -> 1|>]; s = Mahjong`Replay`Replay[log];
    {s["Terminal"], s["Result"]["Mode"], Values[s["Balances"]], s["Result"]["NextDealer"]}], {True, "SelfDraw", {2, -1, -1}, 1}, TestID -> "valid-full-wall-dealer-self-draw-replay-and-settlement"],
  VerificationTest[Module[{s, o, actions}, s = Join[baseState, <|"Hands" -> <|1 -> pihu, 2 -> {}, 3 -> {}|>|>];
    s = Mahjong`Rules`ApplyEvent[s, <|"Type" -> "Liangdao", "Player" -> 1, "Tile" -> "白"|>]; o = Mahjong`Rules`Observe[s, 2];
    s = Join[s, <|"Phase" -> "Draw", "CurrentPlayer" -> 1|>]; s = Mahjong`Rules`ApplyEvent[s, <|"Type" -> "Draw", "Player" -> 1, "Tile" -> First[s["Wall"]]|>];
    actions = Mahjong`Rules`LegalActions[s]; {o["RevealedHands"][1] === Sort[Most[pihu]], Length[Select[actions, #["Type"] === "Discard" &]], FreeQ[Lookup[actions, "Type"], "Gang" | "Peng" | "Liangdao"]}], {True, 1, True}, TestID -> "liangdao-reveals-and-locks-hand"],
  VerificationTest[score[{"1筒", "1筒", "1筒", "1筒", "2筒", "2筒", "2筒", "2筒", "4筒", "4筒", "6条", "6条", "白", "白"}, "白"]["Multiplier"], 16, TestID -> "double-dragon-seven-pairs-x16"],
  VerificationTest[Mahjong`Solver`HuQ[openHand, openMelds, v], True, TestID -> "open-standard-hu"],
  VerificationTest[Mahjong`Solver`Shanten[Most[openHand], openMelds, v], 0, TestID -> "open-tenpai"],
  VerificationTest[Mahjong`Solver`Ukeire[Most[openHand], Join[Most[openHand], Mahjong`Solver`MeldTiles[openMelds]], openMelds, v]["Ukeire"], 3, TestID -> "open-visible-counts"],
  VerificationTest[Mahjong`Solver`HuQ[{"中", "发", "白", "1筒", "2筒", "3筒", "4筒", "5筒", "6筒", "7条", "8条", "9条", "2条", "2条"}, {}, v], False, TestID -> "dragons-cannot-form-sequence"],
  VerificationTest[Length[baseState["Wall"]], 44, TestID -> "initial-wall-has-44-remaining"],
  VerificationTest[Length[Mahjong`Core`StateHand[baseState, 1]], 14, TestID -> "dealer-starts-with-14"],
  VerificationTest[FailureQ[Mahjong`Rules`ApplyEvent[baseState, <|"Type" -> "Draw", "Player" -> 2, "Tile" -> "1筒"|>]], True, TestID -> "cannot-draw-out-of-turn"],
  VerificationTest[Module[{s}, s = Mahjong`Rules`ApplyEvent[respondState[seven], <|"Type" -> "Hu", "Player" -> 2|>]; s = Mahjong`Rules`ApplyEvent[s, <|"Type" -> "Hu", "Player" -> 3|>]; {s["Terminal"], s["Result"]["NextDealer"], Total[Values[s["Balances"]]], Length[s["Result"]["Wins"]]}], {True, 1, 0, 2}, TestID -> "double-hu-zero-sum-and-discarder-dealer"],
  VerificationTest[Module[{s}, s = Mahjong`Rules`ApplyEvent[respondState[seven], <|"Type" -> "Pass", "Player" -> 2|>]; s = Mahjong`Rules`ApplyEvent[s, <|"Type" -> "Pass", "Player" -> 3|>]; {s["Phase"], s["CurrentPlayer"]}], {"Draw", 2}, TestID -> "two-passes-advance-to-next-draw"],
  VerificationTest[Module[{s}, s = Mahjong`Rules`ApplyEvent[respondState[seven], <|"Type" -> "Pass", "Player" -> 2|>]; FailureQ[Mahjong`Rules`ApplyEvent[s, <|"Type" -> "Pass", "Player" -> 2|>]]], True, TestID -> "duplicate-response-rejected"],
  VerificationTest[Module[{s}, s = Join[baseState, <|"Hands" -> <|1 -> {"1筒", "1筒", "1筒", "1筒"}, 2 -> {}, 3 -> {}|>|>]; s = Mahjong`Rules`ApplyEvent[s, <|"Type" -> "Gang", "Player" -> 1, "Tile" -> "1筒", "Kind" -> "Concealed"|>]; {s["Phase"], s["Balances"][1], s["Balances"][2], s["Balances"][3]}], {"SupplementDraw", 4, -2, -2}, TestID -> "concealed-kong-two-payers"],
  VerificationTest[Module[{s}, s = Join[respondState[seven], <|"Hands" -> <|1 -> {}, 2 -> {"白", "白", "白"}, 3 -> {}|>|>]; s = Mahjong`Rules`ApplyEvent[s, <|"Type" -> "Gang", "Player" -> 2, "Tile" -> "白", "Kind" -> "Exposed"|>]; s = Mahjong`Rules`ApplyEvent[s, <|"Type" -> "Pass", "Player" -> 3|>]; {s["Phase"], s["Discards"][1], s["Balances"][1], s["Balances"][2], s["Balances"][3]}], {"SupplementDraw", {}, -2, 2, 0}, TestID -> "exposed-kong-only-discarder-pays-and-river-consumed"],
  VerificationTest[Module[{s}, s = Join[baseState, <|"Hands" -> <|1 -> {"白"}, 2 -> Most[seven], 3 -> {}|>, "Melds" -> <|1 -> {<|"Type" -> "Peng", "Tile" -> "白"|>}, 2 -> {}, 3 -> {}|>|>];
    s = Mahjong`Rules`ApplyEvent[s, <|"Type" -> "Gang", "Player" -> 1, "Tile" -> "白", "Kind" -> "Added"|>]; s = Mahjong`Rules`ApplyEvent[s, <|"Type" -> "Hu", "Player" -> 2|>]; s = Mahjong`Rules`ApplyEvent[s, <|"Type" -> "Pass", "Player" -> 3|>];
    {s["Result"]["Mode"], First[s["Melds"][1]]["Type"], s["Hands"][1], s["KongChain"]["Payments"]}], {"RobKong", "Peng", {}, {}}, TestID -> "rob-added-kong-cancels-upgrade-and-kong-payment"],
  VerificationTest[Module[{s}, s = Join[respondState[seven], <|"Hands" -> <|1 -> {}, 2 -> {"白", "白"}, 3 -> Most[seven]|>|>]; s = Mahjong`Rules`ApplyEvent[s, <|"Type" -> "Peng", "Player" -> 2, "Tile" -> "白"|>]; s = Mahjong`Rules`ApplyEvent[s, <|"Type" -> "Hu", "Player" -> 3|>]; {s["Terminal"], s["Melds"][2]}], {True, {}}, TestID -> "hu-priority-over-peng"],
  VerificationTest[Module[{s, o}, s = Join[baseState, <|"Melds" -> <|1 -> {}, 2 -> {<|"Type" -> "ConcealedGang", "Tile" -> "中"|>}, 3 -> {}|>|>]; o = Mahjong`Rules`Observe[s, 1]; {!MemberQ[o["VisibleTiles"], "中"], !KeyExistsQ[First[o["Melds"][2]], "Tile"], !KeyExistsQ[o, "Wall"]}], {True, True, True}, TestID -> "observation-hides-opponent-kong-and-wall"],
  VerificationTest[Module[{log, s, action, p}, log = baseGame["Events"]; s = baseState;
    Do[If[s["Terminal"], Break[]];
      If[MemberQ[{"Draw", "SupplementDraw"}, s["Phase"]], action = <|"Type" -> "Draw", "Player" -> s["CurrentPlayer"], "Tile" -> If[s["Phase"] === "SupplementDraw", Last[s["Wall"]], First[s["Wall"]]]|>,
        If[s["Phase"] === "Response", p = First[Complement[s["Responders"], Lookup[s["Responses"], "Player", {}]]]; action = <|"Type" -> "Pass", "Player" -> p|>, action = First[Select[Mahjong`Rules`LegalActions[s], #["Type"] === "Discard" &]]]];
      AppendTo[log, action]; s = Mahjong`Rules`ApplyEvent[s, action]; If[FailureQ[s], Break[]], {300}];
    {AssociationQ[s] && TrueQ[s["Terminal"]], SameQ[KeyDrop[s, "EventOffset"], KeyDrop[Mahjong`Replay`Replay[log], "EventOffset"]], Total[Values[s["Balances"]]]}], {True, True, 0}, TestID -> "full-dealt-to-exhaustion-replay" ]
}]
