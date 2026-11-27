using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;
using Underanalyzer.Decompiler;
using UndertaleModLib;
using UndertaleModLib.Decompiler;
using UndertaleModLib.Models;

static string CompileSelectionSource(UndertaleData data, IReadOnlyDictionary<string, string> bindings)
{
    var entry = data.Code.ByName("gml_GlobalScript_scrCursorCrewSelection")
        ?? throw new InvalidOperationException("Expected the native crew selection script.");
    var source = new DecompileContext(new GlobalDecompileContext(data), entry).DecompileToString();
    var selectEnd = source.IndexOf("function crewPortraitIsDragged()", StringComparison.Ordinal);
    var clearStart = source.IndexOf("function deselect_all_crew()", StringComparison.Ordinal);
    var clearEnd = source.IndexOf("function select_crew(", StringComparison.Ordinal);
    if (!source.StartsWith("function scrCursorCrewSelection()", StringComparison.Ordinal)
        || selectEnd < 0 || clearStart <= selectEnd || clearEnd <= clearStart)
        throw new InvalidOperationException("Unexpected structure in the native crew selection script.");

    // The guest reuses the selection and clearing routines with its own instance targets.
    var identifiers = @"\b(?:" + string.Join("|", bindings.Keys.Select(Regex.Escape)) + @")\b";
    return Regex.Replace(source[..selectEnd] + source[clearStart..clearEnd], identifiers,
        match => bindings[match.Value]);
}
