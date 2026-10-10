BeginPackage["Mahjong`Replay`", {"Mahjong`Core`", "Mahjong`Rules`"}]

Replay::usage = "Replay[eventLog, offset] rebuilds state from committed fact events through offset.";
DecisionContext::usage = "DecisionContext[state, player, selectedAction] constructs a transient analysis projection.";
DecisionIndex::usage = "DecisionIndex[game] projects actual action indexes using the last event before each action.";

Begin["`Private`"]

Replay[eventLog_List, offset_: All] := Catch[Module[{events, state},
  If[!AllTrue[eventLog, AssociationQ[#] && StringQ[Lookup[#, "Type", None]] &], Return[Failure["InvalidEventLog", <||>]]];
  If[offset =!= All && (!IntegerQ[offset] || offset < 0 || offset > Length[eventLog]), Return[Failure["InvalidEventOffset", <||>]]];
  events = If[offset === All, eventLog, Take[eventLog, UpTo[offset]]];
  state = InitialState[RuleSetVersion];
  Do[
    state = ApplyEvent[state, event];
    If[FailureQ[state], Throw[state, "ReplayFailure"]];
    state = Join[state, <|"EventOffset" -> (state["EventOffset"] + 1)|>],
    {event, events}
  ];
  Join[state, <|"EventOffset" -> Length[events]|>]
], "ReplayFailure"];

DecisionIndex[game_Association] := Module[{events = game["Events"], id = game["GameId"]},
  Map[Function[i, <|"Id" -> id <> "-D" <> ToString[i], "GameId" -> id, "EventOffset" -> i - 1,
    "PlayerId" -> events[[i]]["Player"], "SelectedAction" -> events[[i]]|>],
    Select[Range[Length[events]], MemberQ[{"Discard", "Peng", "Gang", "Pass", "Hu", "Liangdao"}, events[[#]]["Type"]] &]]
];

DecisionContext[state_Association, player_Integer, selectedAction_Association] := Module[{observation, actions},
  observation = Observe[state, player]; If[FailureQ[observation], Return[observation]];
  actions = LegalActions[state, player];
  <|"State" -> state, "Observation" -> observation, "LegalActions" -> actions, "SelectedAction" -> selectedAction|>
];

End[]
EndPackage[]
