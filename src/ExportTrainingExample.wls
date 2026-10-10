(* Load with wolframscript -code 'Get["src/ExportTrainingExample.wls"]'. All numbers and text are
   computed by the WL evaluator; the browser only presents this projection. *)
sourceDir = DirectoryName[$InputFileName];
Scan[Get, FileNameJoin[{sourceDir, #}] & /@ {"Core.wl", "Rules.wl", "Solver.wl", "Replay.wl", "Analysis.wl", "Coach.wl"}];
hand = {"1筒", "2筒", "3筒", "4筒", "5筒", "6筒", "1条", "2条", "3条", "4条", "5条", "7条", "7条"};
log = {<|"Type" -> "GameStart", "RuleSetVersion" -> Mahjong`Rules`RuleSetVersion|>,
  <|"Type" -> "Deal", "Player" -> 1, "Tiles" -> hand|>,
  <|"Type" -> "Draw", "Player" -> 1, "Tile" -> "9筒"|>};
state = Mahjong`Replay`Replay[log];
If[FailureQ[state], Print[state]; Exit[1]];
choices = Map[Function[action, Module[{analysis, evidence},
  analysis = Mahjong`Analysis`AnalyzeDecision["example-D1", Mahjong`Replay`DecisionContext[state, 1, action]];
  If[FailureQ[analysis], Print[analysis]; Exit[1]];
  evidence = Mahjong`Coach`BuildCoachEvidence[analysis];
  <|"Tile" -> action["Tile"], "Analysis" -> analysis, "Evidence" -> evidence, "Explanation" -> Mahjong`Coach`TemplateCoach[evidence]|>
]], Mahjong`Rules`LegalActions[state]];
output = FileNameJoin[{DirectoryName[sourceDir], "web", "data", "training-example.json"}];
If[!DirectoryQ[DirectoryName[output]], CreateDirectory[DirectoryName[output], CreateIntermediateDirectories -> True]];
exported = Export[output, <|"RuleSetVersion" -> state["RuleSetVersion"], "AnalysisRevision" -> Mahjong`Analysis`AnalysisRevision,
  "EventOffset" -> state["EventOffset"], "Hand" -> Mahjong`Core`StateHand[state, 1], "Choices" -> choices|>, "RawJSON"];
If[exported === $Failed, Exit[1]];
Print["Exported ", Length[choices], " WL analyses to ", output];
