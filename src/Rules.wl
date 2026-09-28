BeginPackage["Mahjong`Rules`", {"Mahjong`Core`"}]

TileUniverse::usage = "TileUniverse[] returns the 27 numbered tiles used by the training-core ruleset.";
TileQ::usage = "TileQ[tile] is true for a supported tile string.";
RuleSetVersion::usage = "RuleSetVersion is the immutable identifier for this ruleset implementation.";
RuleSetManifest::usage = "RuleSetManifest records the immutable scope of RuleSetVersion.";
LegalActions::usage = "LegalActions[state] returns legal actions visible in the current state.";
ApplyEvent::usage = "ApplyEvent[state, event] applies a committed fact event without RNG.";
ApplyAction::usage = "ApplyAction[state, action] validates and applies a player action.";
Observe::usage = "Observe[state, player] projects the rule-defined visible world for that player.";

Begin["`Private`"]

RuleSetVersion = "xiaogan-training-core-0.1";
RuleSetManifest = <|"RuleSetVersion" -> RuleSetVersion, "TileSet" -> "three-numbered-suits", "CopiesPerTile" -> 4, "HuStructure" -> "four-melds-one-pair", "Unsupported" -> {"flowers", "wildcards", "honors", "seven-pairs", "meld-calls", "scoring"}|>;
TileUniverse[] := TileUniverse[] = Flatten[Table[ToString[n] <> suit, {suit, {"万", "筒", "条"}}, {n, 9}]];
TileQ[tile_String] := MemberQ[TileUniverse[], tile];
TileQ[_] := False;

failure[tag_, data_: <||>] := Failure[tag, Join[<|"MessageTemplate" -> tag|>, data]];
replaceHand[state_, player_, hand_] := Join[state, <|"Hands" -> Join[state["Hands"], <|player -> Sort[hand]|>]|>];
replaceDiscards[state_, player_, discards_] := Join[state, <|"Discards" -> Join[state["Discards"], <|player -> discards|>]|>];
nextPlayer[state_, player_] := Mod[player, state["PlayerCount"]] + 1;
validPlayerQ[state_, player_] := IntegerQ[player] && 1 <= player <= state["PlayerCount"];
appendHand[state_, player_, tile_] := replaceHand[state, player, Append[StateHand[state, player], tile]];

LegalActions[state_Association] := Module[{player, hand},
  If[TrueQ[state["Terminal"]] || state["Phase"] =!= "Discard", Return[{}]];
  player = state["CurrentPlayer"]; hand = StateHand[state, player];
  (<|"Type" -> "Discard", "Player" -> player, "Tile" -> #|> &) /@ DeleteDuplicates[hand]
];

ApplyEvent[state_Association, event_Association] := Module[{type = Lookup[event, "Type", Missing[]], player, tile, tiles, next},
  Switch[type,
    "GameStart",
      InitialState[Lookup[event, "RuleSetVersion", RuleSetVersion], Lookup[event, "PlayerCount", 4]],
    "Deal",
      player = Lookup[event, "Player", Missing[]]; tiles = Lookup[event, "Tiles", Missing[]];
      If[!validPlayerQ[state, player] || !ListQ[tiles] || !And @@ (TileQ /@ tiles), Return[failure["InvalidDeal"]]];
      Join[replaceHand[state, player, Join[StateHand[state, player], tiles]], <|"Phase" -> "Draw"|>],
    "Draw",
      player = Lookup[event, "Player", Missing[]]; tile = Lookup[event, "Tile", Missing[]];
      If[!validPlayerQ[state, player] || !TileQ[tile], Return[failure["InvalidDraw"]]];
      Join[appendHand[state, player, tile], <|"CurrentPlayer" -> player, "Phase" -> "Discard"|>],
    "Discard",
      player = Lookup[event, "Player", Missing[]]; tile = Lookup[event, "Tile", Missing[]];
      If[!validPlayerQ[state, player] || !TileQ[tile] || state["Phase"] =!= "Discard" || state["CurrentPlayer"] =!= player || !MemberQ[StateHand[state, player], tile], Return[failure["InvalidDiscard"]]];
      next = nextPlayer[state, player];
      Join[replaceDiscards[replaceHand[state, player, DeleteCases[StateHand[state, player], tile, {1}, 1]], player, Append[state["Discards"][player], tile]], <|"CurrentPlayer" -> next, "Phase" -> "Draw"|>],
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
