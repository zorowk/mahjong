BeginPackage["Mahjong`Solver`", {"Mahjong`Rules`"}]

HuQ::usage = "HuQ[hand] checks the current standard four-meld-plus-pair structure.";
Shanten::usage = "Shanten[hand] returns the standard-structure shanten number for supported numbered tiles.";
Ukeire::usage = "Ukeire[hand, visibleTiles] returns effective tiles and remaining counts after a discard.";
ClearSolverCache::usage = "ClearSolverCache[] deletes derived shanten results without changing semantics.";

Begin["`Private`"]

tileIndex[tile_] := First@FirstPosition[TileUniverse[], tile];
counts[hand_List] /; And @@ (TileQ /@ hand) := Counts[hand];
counts[_] := $Failed;
countAt[c_, i_] := Lookup[c, TileUniverse[][[i]], 0];
removeN[c_, i_, n_] := Join[c, <|TileUniverse[][[i]] -> countAt[c, i] - n|>];
firstNonzero[c_] := SelectFirst[Range[Length[TileUniverse[]]], countAt[c, #] > 0 &, None];
sameSuitSequenceQ[i_] := Mod[i - 1, 9] <= 6;

meldableQ[c_] := Module[{i = firstNonzero[c]},
  If[i === None, True,
    (countAt[c, i] >= 3 && meldableQ[removeN[c, i, 3]]) ||
    (sameSuitSequenceQ[i] && countAt[c, i + 1] > 0 && countAt[c, i + 2] > 0 && meldableQ[removeN[removeN[removeN[c, i, 1], i + 1, 1], i + 2, 1]])
  ]
];

HuQ[hand_List] /; Length[hand] == 14 && And @@ (TileQ /@ hand) := Module[{c = counts[hand]},
  AnyTrue[Range[Length[TileUniverse[]]], countAt[c, #] >= 2 && meldableQ[removeN[c, #, 2]] &]
];
HuQ[_] := False;

shantenSearch[c_, melds_, taatsu_, pair_] := Module[{i, best, c1, usableTaatsu},
  i = firstNonzero[c];
  If[i === None,
    usableTaatsu = Min[taatsu, 4 - melds];
    Return[8 - 2 melds - usableTaatsu - pair]
  ];
  best = shantenSearch[removeN[c, i, 1], melds, taatsu, pair];
  If[countAt[c, i] >= 3, best = Min[best, shantenSearch[removeN[c, i, 3], melds + 1, taatsu, pair]]];
  If[sameSuitSequenceQ[i] && countAt[c, i + 1] > 0 && countAt[c, i + 2] > 0,
    c1 = removeN[removeN[removeN[c, i, 1], i + 1, 1], i + 2, 1]; best = Min[best, shantenSearch[c1, melds + 1, taatsu, pair]]
  ];
  If[pair == 0 && countAt[c, i] >= 2, best = Min[best, shantenSearch[removeN[c, i, 2], melds, taatsu, 1]]];
  If[countAt[c, i] >= 2, best = Min[best, shantenSearch[removeN[c, i, 2], melds, taatsu + 1, pair]]];
  If[sameSuitSequenceQ[i] && countAt[c, i + 1] > 0, best = Min[best, shantenSearch[removeN[removeN[c, i, 1], i + 1, 1], melds, taatsu + 1, pair]]];
  If[Mod[i - 1, 9] <= 5 && countAt[c, i + 2] > 0, best = Min[best, shantenSearch[removeN[removeN[c, i, 1], i + 2, 1], melds, taatsu + 1, pair]]];
  best
];

(* Numeric counts avoid repeated Association lookups at every recursive branch.
   The cache contains only derived values and can always be discarded. *)
fastShanten[vector_List] := Block[{search},
  search[c_List, m_, t_, p_] := search[c, m, t, p] = Module[{i, best, take},
    i = SelectFirst[Range[27], c[[#]] > 0 &, None];
    If[i === None, Return[8 - 2 m - Min[t, 4 - m] - p]];
    take[indices_] := Fold[ReplacePart[#1, #2 -> (#1[[#2]] - 1)] &, c, indices];
    best = search[take[{i}], m, t, p];
    If[m < 4 && c[[i]] >= 3, best = Min[best, search[take[{i, i, i}], m + 1, t, p]]];
    If[m < 4 && Mod[i - 1, 9] <= 6 && c[[i + 1]] > 0 && c[[i + 2]] > 0,
      best = Min[best, search[take[{i, i + 1, i + 2}], m + 1, t, p]]];
    If[c[[i]] >= 2,
      If[p == 0, best = Min[best, search[take[{i, i}], m, t, 1]]];
      If[t < 4 - m, best = Min[best, search[take[{i, i}], m, t + 1, p]]]];
    If[t < 4 - m && Mod[i - 1, 9] <= 7 && c[[i + 1]] > 0,
      best = Min[best, search[take[{i, i + 1}], m, t + 1, p]]];
    If[t < 4 - m && Mod[i - 1, 9] <= 6 && c[[i + 2]] > 0,
      best = Min[best, search[take[{i, i + 2}], m, t + 1, p]]];
    best
  ];
  search[vector, 0, 0, 0]
];
cachedShanten[vector_List] := cachedShanten[vector] = fastShanten[vector];
ClearSolverCache[] := (Clear[cachedShanten]; cachedShanten[vector_List] := cachedShanten[vector] = fastShanten[vector]; Null);

Shanten[hand_List] /; MemberQ[{13, 14}, Length[hand]] && And @@ (TileQ /@ hand) && Max[Join[Values[counts[hand]], {0}]] <= 4 := cachedShanten[Lookup[counts[hand], TileUniverse[], 0]];
Shanten[_] := Failure["InvalidHand", <|"MessageTemplate" -> "InvalidHand"|>];

Ukeire[hand_List] := Ukeire[hand, hand];

Ukeire[hand_List, visibleTiles_List] /; And @@ (TileQ /@ Join[hand, visibleTiles]) := Module[{base, effective},
  base = Shanten[hand];
  If[FailureQ[base] || Length[hand] != 13 || Max[Join[Values[Counts[visibleTiles]], {0}]] > 4 || !And @@ (Count[visibleTiles, #] >= Count[hand, #] & /@ DeleteDuplicates[hand]), Return[Failure["InvalidUkeireInput", <||>]]];
  effective = Select[TileUniverse[], Count[visibleTiles, #] < 4 && Shanten[Append[hand, #]] < base &];
  <|"Ukeire" -> Total[4 - Count[visibleTiles, #] & /@ effective], "EffectiveTiles" -> (<|"Tile" -> #, "Count" -> 4 - Count[visibleTiles, #]|> &) /@ effective|>
];
Ukeire[_, _] := Failure["InvalidUkeireInput", <|"MessageTemplate" -> "InvalidUkeireInput"|>];

End[]
EndPackage[]
