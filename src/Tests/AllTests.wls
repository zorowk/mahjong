testDir = DirectoryName[$InputFileName];
reports = Get[FileNameJoin[{testDir, #}]] & /@ {"RunTests.wl", "KawuxingTests.wl", "ApplicationTests.wl"};
success = Total[#["TestsSucceededCount"] & /@ reports];
failed = Total[#["TestsFailedCount"] & /@ reports];
Print[<|"Passed" -> success, "Failed" -> failed|>];
If[failed > 0, Scan[Print[#["TestsFailed"]] &, reports]; Exit[1]];
