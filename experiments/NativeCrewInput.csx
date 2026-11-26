using System;
using System.IO;
using System.Security.Cryptography;
using UndertaleModLib;
using UndertaleModLib.Compiler;
using UndertaleModLib.Models;

using (var input = File.OpenRead(FilePath))
{
    var hash = Convert.ToHexString(SHA256.HashData(input));
    if (hash != "ABCE01818900906D6DCC6D45777B0EBFB08FC29DDED9E84B541FB4AD4348D92B"
        && hash != "5ECFD25C0194CADB5145D57B66FC73088970376149ED022764709EFFCAC9CB9E")
        throw new InvalidOperationException("Use vanilla build 26906873 or the pinned protocol 5 probe build.");
}

const string traceEntry = "gml_GlobalScript_vw_trace_native_crew";
var step = Data.Code.ByName("gml_Object_oCell_Step_0")
    ?? throw new InvalidOperationException("The native room Step event is missing.");
var hooks = new (int Index, string Native, int Arguments, string Trace)[]
{
    (471, "crew_move_set_target_slot", 4, "vw_trace_crew_tile"),
    (496, "crew_move_set_target_and_push_crew_nearby_slot", 2, "vw_trace_crew_occupied_tile"),
    (529, "crew_move_set_target", 2, "vw_trace_crew_room"),
    (587, "crew_move_set_target_slot", 4, "vw_trace_crew_console")
};

// Guard the exact right-click sites. Other callers, including the later
// simulation-driven call in this Step event, keep their original targets.
foreach (var hook in hooks)
{
    var call = step.Instructions[hook.Index];
    if (call.Kind != UndertaleInstruction.Opcode.Call || call.ArgumentsCount != hook.Arguments
        || call.ValueFunction?.Name.Content != "gml_Script_" + hook.Native)
        throw new InvalidOperationException($"Unexpected native crew call at instruction {hook.Index}.");
}

var code = new CodeImportGroup(Data);
code.QueueReplace(traceEntry, @"
show_debug_message(""[Native crew input] ready"");

function vw_trace_crew_intent(_branch, _crew, _cell, _slot) {
    if (ds_list_size(oUICursor.currSelected) != 1) return;
    show_debug_message(""[Native crew input] "" + _branch + "" crew="" + string(_crew)
        + "" cell="" + string(_cell) + "" x="" + string(_cell.x) + "" y="" + string(_cell.y)
        + "" slot="" + string(_slot));
}

function vw_trace_crew_tile(_crew, _cell, _slot, _mode) {
    vw_trace_crew_intent(""precision"", _crew, _cell, _slot);
    return crew_move_set_target_slot(_crew, _cell, _slot, _mode);
}

function vw_trace_crew_occupied_tile(_crew, _cell) {
    vw_trace_crew_intent(""occupied"", _crew, _cell, nearest_slot_number(_cell, mouse_x, mouse_y));
    return crew_move_set_target_and_push_crew_nearby_slot(_crew, _cell);
}

function vw_trace_crew_room(_crew, _cell) {
    vw_trace_crew_intent(""room"", _crew, _cell, 0);
    return crew_move_set_target(_crew, _cell);
}

function vw_trace_crew_console(_crew, _cell, _slot, _mode) {
    vw_trace_crew_intent(""console"", _crew, _cell, _slot);
    return crew_move_set_target_slot(_crew, _cell, _slot, _mode);
}
");
code.Import();

foreach (var hook in hooks)
{
    step.Instructions[hook.Index].ValueFunction = Data.Functions.ByName("gml_Script_" + hook.Trace)
        ?? throw new InvalidOperationException($"Missing compiled observer {hook.Trace}.");
}
Console.WriteLine("Installed four local native crew observers.");
