(* JSON-only process bridge. No client input is ever evaluated as WL code. *)
$CharacterEncoding = "UTF-8";
sourceDir = DirectoryName[$InputFileName];
Scan[Get[#, CharacterEncoding -> "UTF-8"] &, FileNameJoin[{sourceDir, #}] & /@ {"Core.wl", "Rules.wl", "Solver.wl", "Replay.wl", "Analysis.wl", "Coach.wl"}];
request = Quiet[Import[Environment["MAHJONG_REQUEST_PATH"], "RawJSON", CharacterEncoding -> "UTF-8"]];
apiView[game_, state_] := Module[{player, observation},
  player = If[state["Phase"] === "Response", First[Complement[state["Responders"], Lookup[state["Responses"], "Player", {}]]], state["CurrentPlayer"]];
  observation = Mahjong`Rules`Observe[state, player];
  <|"Game" -> game, "Observation" -> observation, "Player" -> player, "LegalActions" -> Mahjong`Rules`LegalActions[state, player],
    "Result" -> If[TrueQ[state["Terminal"]], state["Result"], Null]|>
];
api[req_Association] := Catch[Module[{op, game, state, action, events, analysis, evidence, next, player},
  op = Lookup[req, "Operation", None];
  If[op === "NewGame", If[!IntegerQ[Lookup[req, "Seed", 42]], Throw[Failure["InvalidSeed", <||>]]]; game = Mahjong`Rules`CreateGame["local-" <> ToString[Lookup[req, "Seed", 42]], Lookup[req, "Seed", 42]]; state = Mahjong`Replay`Replay[game["Events"]]; Return[apiView[game, state]]];
  game = Lookup[req, "Game", <||>];
  If[!AssociationQ[game] || !ListQ[Lookup[game, "Events", None]] || !StringQ[Lookup[game, "GameId", None]], Throw[Failure["InvalidGame", <||>]]];
  events = game["Events"];
  If[events === {} || !AssociationQ[First[events]] || Lookup[game, "RuleSetVersion", None] =!= Lookup[First[events], "RuleSetVersion", None] || game["RuleSetVersion"] =!= Mahjong`Rules`CurrentKawuxingVersion, Throw[Failure["InvalidGameRuleSet", <||>]]];
  If[Length[events] > 1500, Throw[Failure["EventLimit", <||>]]];
  state = Mahjong`Replay`Replay[events, If[op === "Replay", Lookup[req, "EventOffset", All], All]];
  If[FailureQ[state], Throw[state]];
  If[op === "Replay", Return[apiView[game, state]]];
  If[op === "Review", player = Lookup[req, "Player", 1]; If[!MemberQ[{1, 2, 3}, player], Throw[Failure["InvalidPlayer", <||>]]];
    analysis = Mahjong`Analysis`AnalyzeGame[game, player]; If[FailureQ[analysis], Throw[analysis]];
    Return[Join[analysis, <|"Explanations" -> Map[Function[a, evidence = Mahjong`Coach`BuildCoachEvidence[a]; <|"Evidence" -> evidence, "Explanation" -> Mahjong`Coach`TemplateCoach[evidence]|>], analysis["Reviews"]]|>]]];
  action = Lookup[req, "Action", <||>];
  If[!AssociationQ[action], Throw[Failure["InvalidAction", <||>]]];
  If[op === "Analyze",
    If[Lookup[action, "Type", None] =!= "Discard", Throw[Failure["UnsupportedDecisionType", <||>]]];
    player = Lookup[action, "Player", state["CurrentPlayer"]];
    If[!MemberQ[{1, 2, 3}, player], Throw[Failure["InvalidPlayer", <||>]]];
    analysis = Mahjong`Analysis`AnalyzeDecision[game["GameId"] <> "-D" <> ToString[Length[events] + 1], Mahjong`Replay`DecisionContext[state, player, action]];
    If[FailureQ[analysis], Throw[analysis]];
    evidence = Mahjong`Coach`BuildCoachEvidence[analysis];
    Return[<|"Analysis" -> analysis, "Evidence" -> evidence, "Explanation" -> Mahjong`Coach`TemplateCoach[evidence]|>]
  ];
  If[op =!= "Step", Throw[Failure["UnknownOperation", <||>]]];
  next = Mahjong`Rules`ApplyEvent[state, action]; If[FailureQ[next], Throw[next]]; AppendTo[events, action];
  If[MemberQ[{"Draw", "SupplementDraw"}, next["Phase"]],
    action = <|"Type" -> "Draw", "Player" -> next["CurrentPlayer"], "Tile" -> If[next["Phase"] === "SupplementDraw", Last[next["Wall"]], First[next["Wall"]]]|>;
    next = Mahjong`Rules`ApplyEvent[next, action]; If[FailureQ[next], Throw[next]]; AppendTo[events, action]
  ];
  apiView[Join[game, <|"Events" -> events|>], next]
]];
result = If[AssociationQ[request], api[request], Failure["InvalidJSON", <||>]];
If[FailureQ[result], result = <|"Error" -> First[result]|>];
jsonSafe[a_Association] := Association@KeyValueMap[(ToString[#1] -> jsonSafe[#2]) &, a];
jsonSafe[l_List] := jsonSafe /@ l;
jsonSafe[_Missing] := Null;
jsonSafe[x_] := x;
json = Quiet[ExportString[jsonSafe[result], "RawJSON"]];
If[json === $Failed, Print["{\"Error\":\"SerializationFailed\"}"]; Exit[1]];
(* RawJSON ExportString is an encoded byte string, whereas Print encodes text again. *)
Print[FromCharacterCode[ToCharacterCode[json], "UTF-8"]];
