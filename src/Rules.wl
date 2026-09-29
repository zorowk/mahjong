BeginPackage["Mahjong`Rules`", {"Mahjong`Core`"}]

TileUniverse::usage = "TileUniverse[ruleSetVersion] returns that version's supported tile types.";
TileQ::usage = "TileQ[tile] is true for a supported tile string.";
RuleSetVersion::usage = "RuleSetVersion is the immutable identifier for this ruleset implementation.";
KawuxingRuleSetVersion::usage = "KawuxingRuleSetVersion identifies the three-player Xiaogan Kaxingwu ruleset.";
RuleSetManifest::usage = "RuleSetManifest records the immutable scope of RuleSetVersion.";
RuleSetManifestFor::usage = "RuleSetManifestFor[version] returns an immutable ruleset manifest.";
LegalActions::usage = "LegalActions[state] returns legal actions visible in the current state.";
ApplyEvent::usage = "ApplyEvent[state, event] applies a committed fact event without RNG.";
ApplyAction::usage = "ApplyAction[state, action] validates and applies a player action.";
Observe::usage = "Observe[state, player] projects the rule-defined visible world for that player.";

Begin["`Private`"]

RuleSetVersion = "xiaogan-training-core-0.1";
RuleSetManifest = <|"RuleSetVersion" -> RuleSetVersion, "TileSet" -> "three-numbered-suits", "CopiesPerTile" -> 4, "HuStructure" -> "four-melds-one-pair", "Unsupported" -> {"flowers", "wildcards", "honors", "seven-pairs", "meld-calls", "scoring"}|>;
KawuxingRuleSetVersion = "xiaogan-kawuxing-1.0";
kawuxingManifest = <|"RuleSetVersion" -> KawuxingRuleSetVersion, "Players" -> 3, "TileSet" -> "two-numbered-suits-and-dragons", "CopiesPerTile" -> 4, "NoChi" -> True, "Claims" -> {"Peng", "ExposedGang", "AddedGang", "ConcealedGang", "Hu"}, "KongReplacement" -> "SupplementDraw", "MultipleHu" -> "OneDiscardMayHaveTwoWinners", "KongChain" -> "Each consecutive gang doubles its own multiplier; all payments accumulate", "Scoring" -> "Pending separate scorer"|>;
RuleSetManifestFor[RuleSetVersion] := RuleSetManifest;
RuleSetManifestFor[KawuxingRuleSetVersion] := kawuxingManifest;
RuleSetManifestFor[_] := Failure["UnknownRuleSetVersion", <||>];
TileUniverse[] := TileUniverse[RuleSetVersion];
TileUniverse[RuleSetVersion] := TileUniverse[RuleSetVersion] = Flatten[Table[ToString[n] <> suit, {suit, {"万", "筒", "条"}}, {n, 9}]];
TileUniverse[KawuxingRuleSetVersion] := TileUniverse[KawuxingRuleSetVersion] = Join[Flatten[Table[ToString[n] <> suit, {suit, {"筒", "条"}}, {n, 9}]], {"中", "发", "白"}];
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
  If[TrueQ[state["Terminal"]] || state["Phase"] =!= "Discard", Return[{}]];
  player = state["CurrentPlayer"]; hand = StateHand[state, player];
  (<|"Type" -> "Discard", "Player" -> player, "Tile" -> #|> &) /@ DeleteDuplicates[hand]
];

ApplyEvent[state_Association, event_Association] := Module[{type = Lookup[event, "Type", Missing[]], player, tile, tiles, next, kind, source, base, melds, wasSupplement},
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

Observe[state_Association, player_Integer] /; validPlayerQ[state, player] := <|
  "Player" -> player,
  "Hand" -> StateHand[state, player],
  "Discards" -> state["Discards"],
  "CurrentPlayer" -> state["CurrentPlayer"],
  "Phase" -> state["Phase"],
  "Terminal" -> state["Terminal"],
  "VisibleTiles" -> Join[StateHand[state, player], Flatten[Values[state["Discards"]]]]
|>;
Observe[_, player_] := failure["InvalidObservationPlayer", <|"Player" -> player|>];

End[]
EndPackage[]
