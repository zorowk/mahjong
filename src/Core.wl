BeginPackage["Mahjong`Core`"]

InitialState::usage = "InitialState[ruleSetVersion, playerCount] creates an empty replayable state.";
EventQ::usage = "EventQ[event] verifies the minimal fact-event shape.";
ActionQ::usage = "ActionQ[action] verifies the minimal player-action shape.";
StateHand::usage = "StateHand[state, player] returns a player's current concealed hand.";

Begin["`Private`"]

InitialState[ruleSetVersion_String, playerCount_Integer?Positive : 4] := <|
  "RuleSetVersion" -> ruleSetVersion,
  "PlayerCount" -> playerCount,
  "Hands" -> AssociationThread[Range[playerCount], ConstantArray[{}, playerCount]],
  "Discards" -> AssociationThread[Range[playerCount], ConstantArray[{}, playerCount]],
  "CurrentPlayer" -> 1,
  "Phase" -> "Setup",
  "Terminal" -> False,
  "Result" -> Missing["NotFinished"],
  "EventOffset" -> 0
|>;

EventQ[event_Association] := KeyExistsQ[event, "Type"] && StringQ[event["Type"]];
EventQ[_] := False;

ActionQ[action_Association] := KeyExistsQ[action, "Type"] && StringQ[action["Type"]];
ActionQ[_] := False;

StateHand[state_Association, player_Integer] := Lookup[state["Hands"], player, Missing["UnknownPlayer", player]];

End[]
EndPackage[]
