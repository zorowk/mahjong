BeginPackage["Mahjong`Solver`", {"Mahjong`Rules`"}]

HuQ::usage = "HuQ[hand] checks the current standard four-meld-plus-pair structure.";
Shanten::usage = "Shanten[hand] returns the standard-structure shanten number for supported numbered tiles.";
Ukeire::usage = "Ukeire[hand, visibleTiles] returns effective tiles and remaining counts after a discard.";
ClearSolverCache::usage = "ClearSolverCache[] deletes derived shanten results without changing semantics.";
HuDecompositions::usage = "HuDecompositions[hand, melds, version] lists standard and seven-pairs winning decompositions.";
MeldTiles::usage = "MeldTiles[melds] returns physical tile copies from validated Peng/Gang melds.";

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
fastShanten[vector_List] := fastShanten[vector, 0, 27];
fastShanten[vector_List, open_Integer, numbered_Integer] := Block[{search},
  search[c_List, m_, t_, p_] := search[c, m, t, p] = Module[{i, best, take},
    i = SelectFirst[Range[Length[c]], c[[#]] > 0 &, None];
    If[i === None, Return[8 - 2 m - Min[t, 4 - m] - p]];
    take[indices_] := Fold[ReplacePart[#1, #2 -> (#1[[#2]] - 1)] &, c, indices];
    best = search[take[{i}], m, t, p];
    If[m < 4 && c[[i]] >= 3, best = Min[best, search[take[{i, i, i}], m + 1, t, p]]];
    If[m < 4 && i <= numbered && Mod[i - 1, 9] <= 6 && c[[i + 1]] > 0 && c[[i + 2]] > 0,
      best = Min[best, search[take[{i, i + 1, i + 2}], m + 1, t, p]]];
    If[c[[i]] >= 2,
      If[p == 0, best = Min[best, search[take[{i, i}], m, t, 1]]];
      If[t < 4 - m, best = Min[best, search[take[{i, i}], m, t + 1, p]]]];
    If[t < 4 - m && i <= numbered && Mod[i - 1, 9] <= 7 && c[[i + 1]] > 0,
      best = Min[best, search[take[{i, i + 1}], m, t + 1, p]]];
    If[t < 4 - m && i <= numbered && Mod[i - 1, 9] <= 6 && c[[i + 2]] > 0,
      best = Min[best, search[take[{i, i + 2}], m, t + 1, p]]];
    best
  ];
  search[vector, open, 0, 0]
];
cachedShanten[vector_List] := cachedShanten[vector] = fastShanten[vector];
ClearSolverCache[] := (Clear[cachedShanten, cachedOpenShanten]; cachedShanten[vector_List] := cachedShanten[vector] = fastShanten[vector]; cachedOpenShanten[vector_, open_, numbered_] := cachedOpenShanten[vector, open, numbered] = fastShanten[vector, open, numbered]; Null);

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

MeldTiles[melds_List] := Flatten[ConstantArray[#["Tile"], If[#["Type"] === "Peng", 3, 4]] & /@ melds];
validMeldsQ[melds_, version_] := ListQ[melds] && Length[melds] <= 4 && AllTrue[melds,
  AssociationQ[#] && MemberQ[{"Peng", "ConcealedGang", "ExposedGang", "AddedGang"}, Lookup[#, "Type", None]] && TileQ[Lookup[#, "Tile", None], version] &];
validHandQ[hand_, melds_, version_, lengths_] := ListQ[hand] && validMeldsQ[melds, version] && MemberQ[lengths - 3 Length[melds], Length[hand]] &&
  AllTrue[hand, TileQ[#, version] &] && Max[Join[Values[Counts[Join[hand, MeldTiles[melds]]]], {0}]] <= 4;
cachedOpenShanten[vector_, open_, numbered_] := cachedOpenShanten[vector, open, numbered] = fastShanten[vector, open, numbered];

Shanten[hand_List, melds_List, version_String] := Module[{tiles, vector, regular, pairs},
  If[!validHandQ[hand, melds, version, {13, 14}], Return[Failure["InvalidHand", <||>]]];
  tiles = TileUniverse[version]; vector = Lookup[Counts[hand], tiles, 0];
  regular = cachedOpenShanten[vector, Length[melds], If[version === RuleSetVersion, 27, 18]];
  If[version === RuleSetVersion || melds =!= {}, Return[regular]];
  (* Four identical tiles form two pairs in this local seven-pairs rule. *)
  pairs = Total[Floor[vector/2]];
  Min[regular, 6 - pairs]
];

Ukeire[hand_List, visible_List, melds_List, version_String] := Module[{base, effective},
  base = Shanten[hand, melds, version];
  If[FailureQ[base] || Length[hand] != 13 - 3 Length[melds] || !AllTrue[visible, TileQ[#, version] &] ||
    Max[Join[Values[Counts[visible]], {0}]] > 4 || !AllTrue[DeleteDuplicates[Join[hand, MeldTiles[melds]]], Count[visible, #] >= Count[Join[hand, MeldTiles[melds]], #] &], Return[Failure["InvalidUkeireInput", <||>]]];
  effective = Select[TileUniverse[version], Count[visible, #] < 4 && Shanten[Append[hand, #], melds, version] < base &];
  <|"Ukeire" -> Total[4 - Count[visible, #] & /@ effective], "EffectiveTiles" -> (<|"Tile" -> #, "Count" -> 4 - Count[visible, #]|> &) /@ effective|>
];

HuDecompositions[hand_List, melds_List, version_String] := Module[{tiles, vector, numbered, split, out = {}, pairs},
  If[!validHandQ[hand, melds, version, {14}], Return[{}]];
  tiles = TileUniverse[version]; vector = Lookup[Counts[hand], tiles, 0]; numbered = If[version === RuleSetVersion, 27, 18];
  split[c_] := Module[{i, result = {}, rest, groups},
    i = SelectFirst[Range[Length[c]], c[[#]] > 0 &, None]; If[i === None, Return[{{}}]];
    If[c[[i]] >= 3, rest = ReplacePart[c, i -> (c[[i]] - 3)]; groups = split[rest]; result = Join[result, Prepend[#, ConstantArray[tiles[[i]], 3]] & /@ groups]];
    If[i <= numbered && Mod[i - 1, 9] <= 6 && c[[i + 1]] > 0 && c[[i + 2]] > 0,
      rest = Fold[ReplacePart[#1, #2 -> (#1[[#2]] - 1)] &, c, {i, i + 1, i + 2}];
      result = Join[result, Prepend[#, tiles[[{i, i + 1, i + 2}]]] & /@ split[rest]]]; result
  ];
  Do[If[vector[[i]] >= 2, out = Join[out, (<|"Kind" -> "Standard", "Pair" -> tiles[[i]], "Groups" -> #|> &) /@ split[ReplacePart[vector, i -> (vector[[i]] - 2)]]]], {i, Length[tiles]}];
  If[version =!= RuleSetVersion && melds === {} && AllTrue[vector, EvenQ],
    AppendTo[out, <|"Kind" -> "SevenPairs", "Quads" -> Count[vector, 4]|>]];
  out
];
HuQ[hand_List, melds_List, version_String] := HuDecompositions[hand, melds, version] =!= {};

End[]
EndPackage[]
