BeginPackage["Mahjong`Replay`", {"Mahjong`Core`", "Mahjong`Rules`"}]

Replay::usage = "Replay[eventLog, offset] rebuilds state from committed fact events through offset.";
DecisionContext::usage = "DecisionContext[state, player, selectedAction] constructs a transient analysis projection.";

Begin["`Private`"]

Replay[eventLog_List, offset_: All] := Module[{events, state},
  events = If[offset === All, eventLog, Take[eventLog, UpTo[offset]]];
  state = InitialState[RuleSetVersion];
  Do[
    state = ApplyEvent[state, event];
    If[FailureQ[state], Return[state]],
    {event, events}
  ];
  Join[state, <|"EventOffset" -> Length[events]|>]
];

DecisionContext[state_Association, player_Integer, selectedAction_Association] := Module[{observation, actions},
  observation = Observe[state, player]; If[FailureQ[observation], Return[observation]];
  actions = LegalActions[state];
  <|"State" -> state, "Observation" -> observation, "LegalActions" -> actions, "SelectedAction" -> selectedAction|>
];

End[]
EndPackage[]
