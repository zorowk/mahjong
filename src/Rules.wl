BeginPackage["Mahjong`Rules`", {"Mahjong`Core`"}]

TileUniverse::usage = "TileUniverse[ruleSetVersion] returns that version's supported tile types.";
TileQ::usage = "TileQ[tile] is true for a supported tile string.";
RuleSetVersion::usage = "RuleSetVersion is the immutable identifier for this ruleset implementation.";
KawuxingRuleSetVersion::usage = "KawuxingRuleSetVersion identifies the three-player Xiaogan Kaxingwu ruleset.";
CurrentKawuxingVersion::usage = "CurrentKawuxingVersion is the strict playable ruleset; earlier versions retain their replay behavior.";
RuleSetManifest::usage = "RuleSetManifest records the immutable scope of RuleSetVersion.";
RuleSetManifestFor::usage = "RuleSetManifestFor[version] returns an immutable ruleset manifest.";
LegalActions::usage = "LegalActions[state] returns legal actions visible in the current state.";
ApplyEvent::usage = "ApplyEvent[state, event] applies a committed fact event without RNG.";
ApplyAction::usage = "ApplyAction[state, action] validates and applies a player action.";
Observe::usage = "Observe[state, player] projects the rule-defined visible world for that player.";
WinScore::usage = "WinScore[hand, melds, context] computes maximum compatible multipliers in base units.";
GameResult::usage = "GameResult[state] returns terminal settlement.";
CreateGame::usage = "CreateGame[id, seed] generates a shuffled, dealt game whose random facts are all in Events.";

Begin["`Private`"]

RuleSetVersion = "xiaogan-training-core-0.1";
RuleSetManifest = <|"RuleSetVersion" -> RuleSetVersion, "TileSet" -> "three-numbered-suits", "CopiesPerTile" -> 4, "HuStructure" -> "four-melds-one-pair", "Unsupported" -> {"flowers", "wildcards", "honors", "seven-pairs", "meld-calls", "scoring"}|>;
KawuxingRuleSetVersion = "xiaogan-kawuxing-1.0";
CurrentKawuxingVersion = "xiaogan-kawuxing-1.1";
kawuxingManifest = <|"RuleSetVersion" -> KawuxingRuleSetVersion, "Players" -> 3, "TileSet" -> "two-numbered-suits-and-dragons", "CopiesPerTile" -> 4, "NoChi" -> True, "Claims" -> {"Peng", "ExposedGang", "AddedGang", "ConcealedGang", "Hu"}, "KongReplacement" -> "SupplementDraw", "MultipleHu" -> "OneDiscardMayHaveTwoWinners", "KongChain" -> "Each consecutive gang doubles its own multiplier; all payments accumulate", "Scoring" -> "Pending separate scorer"|>;
RuleSetManifestFor[RuleSetVersion] := RuleSetManifest;
RuleSetManifestFor[KawuxingRuleSetVersion] := kawuxingManifest;
RuleSetManifestFor[CurrentKawuxingVersion] := <|"RuleSetVersion" -> CurrentKawuxingVersion, "Players" -> 3, "CopiesPerTile" -> 4, "NoChi" -> True, "Pihu" -> "SelfDrawOnly", "BaseUnit" -> 1, "Cap" -> "None", "SeaBottomBonus" -> False, "Source" -> "rules/1.md", "ConflictResolution" -> "Line 21 takes precedence over line 79: last draw still allows ordinary Hu, no sea-bottom multiplier"|>;
RuleSetManifestFor[_] := Failure["UnknownRuleSetVersion", <||>];
TileUniverse[] := TileUniverse[RuleSetVersion];
TileUniverse[RuleSetVersion] := TileUniverse[RuleSetVersion] = Flatten[Table[ToString[n] <> suit, {suit, {"万", "筒", "条"}}, {n, 9}]];
TileUniverse[KawuxingRuleSetVersion] := TileUniverse[KawuxingRuleSetVersion] = Join[Flatten[Table[ToString[n] <> suit, {suit, {"筒", "条"}}, {n, 9}]], {"中", "发", "白"}];
TileUniverse[CurrentKawuxingVersion] := TileUniverse[KawuxingRuleSetVersion];
TileUniverse[_] := {};
TileQ[tile_String] := TileQ[tile, RuleSetVersion];
TileQ[tile_String, version_String] := MemberQ[TileUniverse[version], tile];
TileQ[_] := False;

failure[tag_, data_: <||>] := Failure[tag, Join[<|"MessageTemplate" -> tag|>, data]];
replaceHand[state_, player_, hand_] := Join[state, <|"Hands" -> Join[state["Hands"], <|player -> Sort[hand]|>]|>];
replaceDiscards[state_, player_, discards_] := Join[state, <|"Discards" -> Join[state["Discards"], <|player -> discards|>]|>];
replaceMelds[state_, player_, melds_] := Join[state, <|"Melds" -> Join[state["Melds"], <|player -> melds|>]|>];
nextPlayer[state_, player_] := Mod[player, state["PlayerCount"]] + 1;
validPlayerQ[state_, player_] := IntegerQ[player] && 1 <= player <= state["PlayerCount"];
appendHand[state_, player_, tile_] := replaceHand[state, player, Append[StateHand[state, player], tile]];
removeTiles[hand_, tile_, n_] := Nest[DeleteCases[#, tile, {1}, 1] &, hand, n];
appendMeld[state_, player_, meld_] := replaceMelds[state, player, Append[state["Melds"][player], meld]];
defaultPlayerCount[version_] := Lookup[RuleSetManifestFor[version], "Players", 4];
kongEvent[state_, player_, tile_, kind_] := Module[{chain, multiplier, payment},
  chain = state["KongChain"]; multiplier = If[TrueQ[chain["Open"]], 2 chain["Multiplier"], 1];
  payment = <|"Player" -> player, "Tile" -> tile, "Kind" -> kind, "Multiplier" -> multiplier|>;
  Join[state, <|"KongChain" -> <|"Open" -> True, "Multiplier" -> multiplier, "Payments" -> Append[chain["Payments"], payment]|>, "CurrentPlayer" -> player, "Phase" -> "SupplementDraw", "LastDiscard" -> Missing["Claimed"]|>]
];

LegalActions[state_Association] := Module[{player, hand},
  If[state["RuleSetVersion"] === CurrentKawuxingVersion, Return[strictActions[state, state["CurrentPlayer"]]]];
  If[TrueQ[state["Terminal"]] || state["Phase"] =!= "Discard", Return[{}]];
  player = state["CurrentPlayer"]; hand = StateHand[state, player];
  (<|"Type" -> "Discard", "Player" -> player, "Tile" -> #|> &) /@ DeleteDuplicates[hand]
];

ApplyEvent[state_Association, event_Association] := Module[{type = Lookup[event, "Type", Missing[]], player, tile, tiles, next, kind, source, base, melds, wasSupplement},
  If[state["RuleSetVersion"] === CurrentKawuxingVersion || (type === "GameStart" && Lookup[event, "RuleSetVersion", None] === CurrentKawuxingVersion), Return[strictApply[state, event]]];
  Switch[type,
    "GameStart",
      With[{version = Lookup[event, "RuleSetVersion", RuleSetVersion]}, InitialState[version, Lookup[event, "PlayerCount", defaultPlayerCount[version]]]],
    "Deal",
      player = Lookup[event, "Player", Missing[]]; tiles = Lookup[event, "Tiles", Missing[]];
      If[!validPlayerQ[state, player] || !ListQ[tiles] || !And @@ (TileQ[#, state["RuleSetVersion"]] & /@ tiles), Return[failure["InvalidDeal"]]];
      Join[replaceHand[state, player, Join[StateHand[state, player], tiles]], <|"Phase" -> "Draw"|>],
    "Draw",
      player = Lookup[event, "Player", Missing[]]; tile = Lookup[event, "Tile", Missing[]];
      If[!validPlayerQ[state, player] || !TileQ[tile, state["RuleSetVersion"]], Return[failure["InvalidDraw"]]];
      wasSupplement = state["Phase"] === "SupplementDraw";
      Join[appendHand[state, player, tile], <|"CurrentPlayer" -> player, "Phase" -> "Discard", "KongChain" -> Join[state["KongChain"], <|"Open" -> wasSupplement|>]|>],
    "Discard",
      player = Lookup[event, "Player", Missing[]]; tile = Lookup[event, "Tile", Missing[]];
      If[!validPlayerQ[state, player] || !TileQ[tile, state["RuleSetVersion"]] || state["Phase"] =!= "Discard" || state["CurrentPlayer"] =!= player || !MemberQ[StateHand[state, player], tile], Return[failure["InvalidDiscard"]]];
      next = nextPlayer[state, player];
      Join[replaceDiscards[replaceHand[state, player, DeleteCases[StateHand[state, player], tile, {1}, 1]], player, Append[state["Discards"][player], tile]], <|"CurrentPlayer" -> next, "Phase" -> "Draw", "LastDiscard" -> <|"Player" -> player, "Tile" -> tile|>|>],
    "Peng",
      player = Lookup[event, "Player", Missing[]]; tile = Lookup[event, "Tile", Missing[]]; source = state["LastDiscard"];
      If[state["RuleSetVersion"] =!= KawuxingRuleSetVersion || !validPlayerQ[state, player] || !AssociationQ[source] || source["Tile"] =!= tile || Count[StateHand[state, player], tile] < 2, Return[failure["InvalidPeng"]]];
      Join[appendMeld[replaceHand[state, player, removeTiles[StateHand[state, player], tile, 2]], player, <|"Type" -> "Peng", "Tile" -> tile, "From" -> source["Player"]|>], <|"CurrentPlayer" -> player, "Phase" -> "Discard", "LastDiscard" -> Missing["Claimed"]|>],
    "Gang",
      player = Lookup[event, "Player", Missing[]]; tile = Lookup[event, "Tile", Missing[]]; kind = Lookup[event, "Kind", Missing[]]; source = state["LastDiscard"]; melds = state["Melds"][player];
      If[state["RuleSetVersion"] =!= KawuxingRuleSetVersion || !validPlayerQ[state, player], Return[failure["InvalidGang"]]];
      Switch[kind,
        "Concealed", If[Count[StateHand[state, player], tile] < 4, Return[failure["InvalidConcealedGang"]]]; base = appendMeld[replaceHand[state, player, removeTiles[StateHand[state, player], tile, 4]], player, <|"Type" -> "ConcealedGang", "Tile" -> tile|>],
        "Exposed", If[!AssociationQ[source] || source["Tile"] =!= tile || Count[StateHand[state, player], tile] < 3, Return[failure["InvalidExposedGang"]]]; base = appendMeld[replaceHand[state, player, removeTiles[StateHand[state, player], tile, 3]], player, <|"Type" -> "ExposedGang", "Tile" -> tile, "From" -> source["Player"]|>],
        "Added", If[Count[StateHand[state, player], tile] < 1 || !AnyTrue[melds, # ["Type"] === "Peng" && # ["Tile"] === tile &], Return[failure["InvalidAddedGang"]]]; base = replaceMelds[replaceHand[state, player, removeTiles[StateHand[state, player], tile, 1]], player, Replace[melds, m_ /; m["Type"] === "Peng" && m["Tile"] === tile :> Join[m, <|"Type" -> "AddedGang"|>, 1]]],
        _, Return[failure["UnknownGangKind"]]
      ]; kongEvent[base, player, tile, kind],
    "GameEnd",
      Join[state, <|"Terminal" -> True, "Phase" -> "Finished", "Result" -> Lookup[event, "Result", <||>]|>],
    _, failure["UnsupportedEvent", <|"Type" -> type|>]
  ]
];
ApplyEvent[_, _] := failure["InvalidEvent"];

ApplyAction[state_Association, action_Association] := ApplyEvent[state, action];
ApplyAction[_, _] := failure["InvalidAction"];

Observe[state_Association, player_Integer] /; validPlayerQ[state, player] := If[state["RuleSetVersion"] === CurrentKawuxingVersion, strictObserve[state, player], <|
  "Player" -> player,
  "Hand" -> StateHand[state, player],
  "Discards" -> state["Discards"],
  "CurrentPlayer" -> state["CurrentPlayer"],
  "Phase" -> state["Phase"],
  "Terminal" -> state["Terminal"],
  "VisibleTiles" -> Join[StateHand[state, player], Flatten[Values[state["Discards"]]]]
|>];
Observe[_, player_] := failure["InvalidObservationPlayer", <|"Player" -> player|>];

LegalActions[state_Association, player_Integer] := If[state["RuleSetVersion"] === CurrentKawuxingVersion, strictActions[state, player], If[player === state["CurrentPlayer"], LegalActions[state], {}]];
GameResult[state_Association] := state["Result"];
CreateGame[id_String, seed_Integer] := BlockRandom[Module[{wall, events, s, tiles},
  SeedRandom[seed]; wall = RandomSample[Flatten[ConstantArray[#, 4] & /@ TileUniverse[CurrentKawuxingVersion]]];
  events = {<|"Type" -> "GameStart", "RuleSetVersion" -> CurrentKawuxingVersion, "Dealer" -> 1, "Wall" -> wall|>};
  s = strictInitial[First[events]];
  Do[tiles = Take[s["Wall"], If[p == 1, 14, 13]]; AppendTo[events, <|"Type" -> "Deal", "Player" -> p, "Tiles" -> tiles|>]; s = strictApply[s, Last[events]], {p, 3}];
  <|"GameId" -> id, "RuleSetVersion" -> CurrentKawuxingVersion, "Events" -> events|>
]];

(* Scoring is deterministic and uses actual winning decompositions. *)
WinScore[hand_List, melds_List, ctx_Association] := Module[{decompositions, candidates, tile, before, full, flags, score},
  decompositions = Mahjong`Solver`HuDecompositions[hand, melds, CurrentKawuxingVersion];
  If[decompositions === {}, Return[failure["NotHu"]]];
  tile = Lookup[ctx, "Tile", None]; before = removeTiles[hand, tile, 1]; full = Join[hand, Mahjong`Solver`MeldTiles[melds]];
  flags = Select[{"Liangdao", "KongDraw", "KongDiscard", "RobKong"}, TrueQ[Lookup[ctx, #, False]] &];
  candidates = Map[Function[d, Module[{f = <||>, groups, triplets, dragonTrips, pure, factor, k5},
    pure = !AnyTrue[full, MemberQ[{"中", "发", "白"}, #] &] && Length[DeleteDuplicates[StringTake[#, -1] & /@ full]] == 1;
    If[pure, f = Join[f, <|"清一色" -> 4|>]];
    If[d["Kind"] === "SevenPairs",
      If[d["Quads"] > 2, Return[failure["UndefinedTripleDragonSevenPairs"]]];
      f = Join[f, <|Switch[d["Quads"], 0, "七对", 1, "龙七对", _, "双龙七对"] -> 4*2^d["Quads"]|>],
      groups = Join[d["Groups"], ConstantArray[#["Tile"], 3] & /@ melds];
      triplets = First /@ Select[groups, Length[DeleteDuplicates[#]] == 1 &];
      If[Length[triplets] == 4, f = Join[f, <|"碰碰胡" -> 2|>]];
      dragonTrips = Count[triplets, "中" | "发" | "白"];
      If[dragonTrips == 3, f = Join[f, <|"大三元" -> 8|>]];
      If[dragonTrips == 2 && MemberQ[{"中", "发", "白"}, d["Pair"]], f = Join[f, <|"小三元" -> 4|>]];
      If[Length[melds] == 4, f = Join[f, <|"手抓一" -> 4|>]];
      k5 = MemberQ[{"5筒", "5条"}, tile] && MemberQ[d["Groups"], {"4" <> StringTake[tile, -1], tile, "6" <> StringTake[tile, -1]}];
      If[k5, f = Join[f, <|"卡五星" -> 2|>]];
      If[Count[before, tile] == 3, f = Join[f, <|"暗四归一" -> 4|>]];
      If[AnyTrue[melds, #["Tile"] === tile && #["Type"] === "Peng" &], f = Join[f, <|"明四归一" -> 2|>]]
    ];
    Do[f = Join[f, <|Switch[flag, "Liangdao", "亮倒", "KongDraw", "杠上开花", "KongDiscard", "杠上炮", "RobKong", "抢杠胡"] -> 2|>], {flag, flags}];
    factor = Times @@ Values[f]; <|"Multiplier" -> factor, "Patterns" -> f, "Decomposition" -> d|>
  ]], decompositions];
  candidates = Select[candidates, !FailureQ[#] &]; If[candidates === {}, Return[failure["UndefinedScoring"]]];
  First[Reverse[SortBy[candidates, #["Multiplier"] &]]]
];

strictInitial[event_] := Module[{wall, dealer, s},
  wall = Lookup[event, "Wall", {}]; dealer = Lookup[event, "Dealer", 1];
  If[!MemberQ[{1, 2, 3}, dealer] || !ListQ[wall] || Sort[wall] =!= Sort[Flatten[ConstantArray[#, 4] & /@ TileUniverse[CurrentKawuxingVersion]]], Return[failure["InvalidInitialWall"]]];
  s = InitialState[CurrentKawuxingVersion, 3];
  Join[s, <|"Dealer" -> dealer, "CurrentPlayer" -> dealer, "Wall" -> wall, "Dealt" -> {}, "Responses" -> {}, "Responders" -> {},
    "PendingGang" -> Missing["None"], "LastDraw" -> Missing["None"], "Liangdao" -> AssociationThread[Range[3], ConstantArray[False, 3]],
    "LockedHands" -> <||>, "Balances" -> AssociationThread[Range[3], ConstantArray[0, 3]]|>]
];
scoreContext[s_, p_, tile_, mode_] := <|"Tile" -> tile, "Liangdao" -> s["Liangdao"][p],
  "KongDraw" -> (mode === "SelfDraw" && AssociationQ[s["LastDraw"]] && TrueQ[s["LastDraw"]["Supplement"]]),
  "KongDiscard" -> (mode === "Discard" && TrueQ[s["KongChain"]["Open"]]), "RobKong" -> (mode === "RobKong")|>;
canWin[s_, p_, tile_, mode_] := Module[{h, score},
  h = If[mode === "SelfDraw", StateHand[s, p], Append[StateHand[s, p], tile]];
  score = WinScore[h, s["Melds"][p], scoreContext[s, p, tile, mode]];
  !FailureQ[score] && (mode === "SelfDraw" || score["Multiplier"] > 1)
];
strictActions[s_, p_] := Module[{h, source, tile, actions, mode, drawn},
  If[!validPlayerQ[s, p] || TrueQ[s["Terminal"]], Return[{}]]; h = StateHand[s, p];
  If[s["Phase"] === "Response",
    If[!MemberQ[s["Responders"], p] || AnyTrue[s["Responses"], #["Player"] === p &], Return[{}]];
    source = s["LastDiscard"]; tile = source["Tile"]; mode = If[AssociationQ[s["PendingGang"]], "RobKong", "Discard"];
    actions = {<|"Type" -> "Pass", "Player" -> p|>};
    If[canWin[s, p, tile, mode], AppendTo[actions, <|"Type" -> "Hu", "Player" -> p|>]];
    If[mode === "Discard" && !TrueQ[s["Liangdao"][p]],
      If[Count[h, tile] >= 2, AppendTo[actions, <|"Type" -> "Peng", "Player" -> p, "Tile" -> tile|>]];
      If[Count[h, tile] >= 3 && Length[s["Wall"]] > 0, AppendTo[actions, <|"Type" -> "Gang", "Player" -> p, "Tile" -> tile, "Kind" -> "Exposed"|>]]]; Return[actions]
  ];
  If[s["Phase"] =!= "Discard" || s["CurrentPlayer"] =!= p, Return[{}]];
  drawn = If[AssociationQ[s["LastDraw"]], s["LastDraw"]["Tile"], None];
  actions = (<|"Type" -> "Discard", "Player" -> p, "Tile" -> #|> &) /@ If[TrueQ[s["Liangdao"][p]], {drawn}, DeleteDuplicates[h]];
  If[drawn =!= None && canWin[s, p, drawn, "SelfDraw"], AppendTo[actions, <|"Type" -> "Hu", "Player" -> p|>]];
  If[!TrueQ[s["Liangdao"][p]],
    If[Length[s["Wall"]] > 0, Do[
      If[Count[h, tile] == 4, AppendTo[actions, <|"Type" -> "Gang", "Player" -> p, "Tile" -> tile, "Kind" -> "Concealed"|>]];
      If[Count[h, tile] >= 1 && AnyTrue[s["Melds"][p], #["Type"] === "Peng" && #["Tile"] === tile &], AppendTo[actions, <|"Type" -> "Gang", "Player" -> p, "Tile" -> tile, "Kind" -> "Added"|>]], {tile, DeleteDuplicates[h]}]];
    Do[If[Mahjong`Solver`Shanten[removeTiles[h, tile, 1], s["Melds"][p], CurrentKawuxingVersion] == 0, AppendTo[actions, <|"Type" -> "Liangdao", "Player" -> p, "Tile" -> tile|>]], {tile, DeleteDuplicates[h]}]
  ]; actions
];
strictKong[s_, event_] := Module[{p = event["Player"], tile = event["Tile"], kind = event["Kind"], base, multiplier, payers, amount, balance, payments, source},
  source = s["LastDiscard"]; base = s;
  Switch[kind,
    "Concealed", base = appendMeld[replaceHand[s, p, removeTiles[StateHand[s, p], tile, 4]], p, <|"Type" -> "ConcealedGang", "Tile" -> tile|>]; payers = DeleteCases[Range[3], p]; amount = 2,
    "Exposed", base = appendMeld[replaceDiscards[replaceHand[s, p, removeTiles[StateHand[s, p], tile, 3]], source["Player"], Most[s["Discards"][source["Player"]]]], p, <|"Type" -> "ExposedGang", "Tile" -> tile, "From" -> source["Player"]|>]; payers = {source["Player"]}; amount = 2,
    "Added", base = replaceMelds[replaceHand[s, p, removeTiles[StateHand[s, p], tile, 1]], p, (If[#["Type"] === "Peng" && #["Tile"] === tile, Join[#, <|"Type" -> "AddedGang"|>], #] &) /@ s["Melds"][p]]; payers = DeleteCases[Range[3], p]; amount = 1
  ];
  multiplier = If[TrueQ[s["KongChain"]["Open"]], 2 s["KongChain"]["Multiplier"], 1]; balance = s["Balances"];
  Do[balance = Join[balance, <|q -> (balance[q] - amount multiplier), p -> (balance[p] + amount multiplier)|>], {q, payers}];
  payments = Append[s["KongChain"]["Payments"], <|"Player" -> p, "Tile" -> tile, "Kind" -> kind, "Multiplier" -> multiplier, "Payers" -> payers, "AmountPerPayer" -> amount multiplier|>];
  Join[base, <|"Balances" -> balance, "KongChain" -> <|"Open" -> True, "Multiplier" -> multiplier, "Payments" -> payments|>, "Phase" -> "SupplementDraw", "CurrentPlayer" -> p,
    "LastDiscard" -> Missing["Claimed"], "Responders" -> {}, "Responses" -> {}, "PendingGang" -> Missing["None"]|>]
];
strictFinish[s_, winners_, source_, mode_, tile_] := Module[{balance = s["Balances"], wins = {}, hand, score, payers, nextDealer, base = s},
  Do[hand = If[mode === "SelfDraw", StateHand[s, p], Append[StateHand[s, p], tile]];
    score = WinScore[hand, s["Melds"][p], scoreContext[s, p, tile, mode]];
    payers = If[mode === "SelfDraw", DeleteCases[Range[3], p], {source}];
    Do[balance = Join[balance, <|q -> (balance[q] - score["Multiplier"]), p -> (balance[p] + score["Multiplier"])|>], {q, payers}];
    AppendTo[wins, <|"Player" -> p, "Score" -> score|>], {p, winners}];
  nextDealer = Which[winners === {}, s["Dealer"], Length[winners] == 2, source, True, First[winners]];
  If[mode === "RobKong", base = replaceHand[s, source, removeTiles[StateHand[s, source], tile, 1]]];
  Join[base, <|"Terminal" -> True, "Phase" -> "Finished", "Balances" -> balance, "Result" -> <|"Mode" -> mode, "Wins" -> wins, "Balances" -> balance, "NextDealer" -> nextDealer, "KongPayments" -> s["KongChain"]["Payments"]|>|>]
];
strictResolve[s_] := Module[{hu, claims, event, source = s["LastDiscard"], base},
  hu = Lookup[Select[s["Responses"], #["Type"] === "Hu" &], "Player", {}];
  If[hu =!= {}, Return[strictFinish[s, hu, source["Player"], If[AssociationQ[s["PendingGang"]], "RobKong", "Discard"], source["Tile"]]]];
  If[AssociationQ[s["PendingGang"]], Return[strictKong[s, s["PendingGang"]]]];
  claims = Select[s["Responses"], MemberQ[{"Peng", "Gang"}, #["Type"]] &];
  If[claims =!= {}, event = First[SortBy[claims, Mod[#["Player"] - source["Player"], 3] &]];
    If[event["Type"] === "Gang", Return[strictKong[s, event]]];
    base = appendMeld[replaceDiscards[replaceHand[s, event["Player"], removeTiles[StateHand[s, event["Player"]], source["Tile"], 2]], source["Player"], Most[s["Discards"][source["Player"]]]], event["Player"], <|"Type" -> "Peng", "Tile" -> source["Tile"], "From" -> source["Player"]|>];
    Return[Join[base, <|"Phase" -> "Discard", "CurrentPlayer" -> event["Player"], "LastDraw" -> Missing["None"], "LastDiscard" -> Missing["Claimed"], "Responders" -> {}, "Responses" -> {}, "KongChain" -> Join[s["KongChain"], <|"Open" -> False|>]|>]]];
  If[s["Wall"] === {}, Return[strictFinish[s, {}, 0, "Draw", None]]];
  Join[s, <|"Phase" -> "Draw", "CurrentPlayer" -> nextPlayer[s, source["Player"]], "LastDiscard" -> Missing["Passed"], "Responses" -> {}, "Responders" -> {}, "KongChain" -> Join[s["KongChain"], <|"Open" -> False|>]|>]
];
strictApply[s_, e_] := Module[{type = Lookup[e, "Type", None], p, tile, base, required, responses},
  If[type === "GameStart", If[s["EventOffset"] > 0, Return[failure["DuplicateGameStart"]]]; Return[strictInitial[e]]];
  If[TrueQ[s["Terminal"]], Return[failure["GameAlreadyFinished"]]];
  p = Lookup[e, "Player", None]; If[!validPlayerQ[s, p], Return[failure["InvalidPlayer"]]];
  Switch[type,
    "Deal", required = If[p === s["Dealer"], 14, 13];
      If[s["Phase"] =!= "Setup" || MemberQ[s["Dealt"], p] || Lookup[e, "Tiles", {}] =!= Take[s["Wall"], required], Return[failure["InvalidDeal"]]];
      base = replaceHand[s, p, e["Tiles"]]; base = Join[base, <|"Wall" -> Drop[s["Wall"], required], "Dealt" -> Append[s["Dealt"], p]|>];
      If[p === s["Dealer"], base = Join[base, <|"DealerLastTile" -> Last[e["Tiles"]]|>]];
      If[Length[base["Dealt"]] == 3, base = Join[base, <|"Phase" -> "Discard", "LastDraw" -> <|"Tile" -> base["DealerLastTile"], "Supplement" -> False|>|>]]; Return[base],
    "Draw", If[!MemberQ[{"Draw", "SupplementDraw"}, s["Phase"]] || p =!= s["CurrentPlayer"] || s["Wall"] === {}, Return[failure["InvalidDraw"]]];
      tile = If[s["Phase"] === "SupplementDraw", Last[s["Wall"]], First[s["Wall"]]];
      If[Lookup[e, "Tile", None] =!= tile, Return[failure["DrawTileMismatch"]]];
      Return[Join[appendHand[s, p, tile], <|"Wall" -> If[s["Phase"] === "SupplementDraw", Most[s["Wall"]], Rest[s["Wall"]]], "Phase" -> "Discard", "LastDraw" -> <|"Tile" -> tile, "Supplement" -> (s["Phase"] === "SupplementDraw")|>|>]]
  ];
  If[!MemberQ[KeySort /@ strictActions[s, p], KeySort[e]], Return[failure["IllegalAction"]]];
  If[s["Phase"] === "Response", responses = Append[s["Responses"], e]; base = Join[s, <|"Responses" -> responses|>]; Return[If[Length[responses] == Length[s["Responders"]], strictResolve[base], base]]];
  tile = Lookup[e, "Tile", None];
  Switch[type,
    "Hu", strictFinish[s, {p}, p, "SelfDraw", s["LastDraw"]["Tile"]],
    "Gang", If[e["Kind"] === "Added", Join[s, <|"PendingGang" -> e, "LastDiscard" -> <|"Player" -> p, "Tile" -> tile|>, "Phase" -> "Response", "Responders" -> DeleteCases[Range[3], p], "Responses" -> {}|>], strictKong[s, e]],
    "Discard" | "Liangdao",
      base = replaceDiscards[replaceHand[s, p, removeTiles[StateHand[s, p], tile, 1]], p, Append[s["Discards"][p], tile]];
      If[type === "Liangdao", base = Join[base, <|"Liangdao" -> Join[s["Liangdao"], <|p -> True|>], "LockedHands" -> Join[s["LockedHands"], <|p -> StateHand[base, p]|>]|>]];
      Join[base, <|"LastDiscard" -> <|"Player" -> p, "Tile" -> tile|>, "Phase" -> "Response", "Responders" -> DeleteCases[Range[3], p], "Responses" -> {}|>],
    _, failure["UnsupportedEvent"]
  ]
];
strictObserve[s_, p_] := Module[{revealed, publicMelds, visible},
  revealed = Association@Select[Normal[s["Hands"]], First[#] =!= p && TrueQ[s["Liangdao"][First[#]]] &];
  publicMelds = Association@KeyValueMap[Function[{q, ms}, q -> (If[#["Type"] === "ConcealedGang" && q =!= p, KeyDrop[#, "Tile"], #] & /@ ms)], s["Melds"]];
  visible = Join[StateHand[s, p], Flatten[Values[s["Discards"]]], Flatten[Values[revealed]], Flatten[KeyValueMap[Function[{q, ms}, Mahjong`Solver`MeldTiles[Select[ms, q === p || #["Type"] =!= "ConcealedGang" &]]], s["Melds"]]]];
  <|"Player" -> p, "Hand" -> StateHand[s, p], "Melds" -> publicMelds, "Discards" -> s["Discards"], "RevealedHands" -> revealed,
    "CurrentPlayer" -> s["CurrentPlayer"], "Phase" -> s["Phase"], "Terminal" -> s["Terminal"], "WallCount" -> Length[s["Wall"]], "VisibleTiles" -> visible|>
];

End[]
EndPackage[]
