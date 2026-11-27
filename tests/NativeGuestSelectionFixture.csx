using System;
using System.Text.RegularExpressions;
using Underanalyzer.Decompiler;
using UndertaleModLib;
using UndertaleModLib.Compiler;
using UndertaleModLib.Decompiler;
using UndertaleModLib.Models;

// Extract only the selection and clearing routines from the local game data.
var nativeEntry = Data.Code.ByName("gml_GlobalScript_scrCursorCrewSelection")
    ?? throw new InvalidOperationException("Expected the native crew selection script.");
if (Data.Code.ByName("gml_Object_oVoidWarConnectionProbe_Create_0") == null)
    throw new InvalidOperationException("Build the standard co-op data before applying this fixture.");
var native = new DecompileContext(new GlobalDecompileContext(Data), nativeEntry).DecompileToString();
var selectEnd = native.IndexOf("function crewPortraitIsDragged()", StringComparison.Ordinal);
var clearStart = native.IndexOf("function deselect_all_crew()", StringComparison.Ordinal);
var clearEnd = native.IndexOf("function select_crew(", StringComparison.Ordinal);
if (!native.StartsWith("function scrCursorCrewSelection()", StringComparison.Ordinal)
    || selectEnd < 0 || clearStart <= selectEnd || clearEnd <= clearStart)
    throw new InvalidOperationException("Unexpected structure in the native crew selection script.");

var select = native[..selectEnd];
var clear = native[clearStart..clearEnd];
var isolated = Regex.Replace(select + clear, @"\boCrew\b", "oVWFixtureCrew");
isolated = Regex.Replace(isolated, @"\boUICursor\b", "oVWFixtureCursor");
isolated = Regex.Replace(isolated, @"\boCrewPortrait\b", "oVWFixturePortrait");
isolated = Regex.Replace(isolated, @"\bscrCursorCrewSelection\b", "vw_fixture_native_select");
isolated = Regex.Replace(isolated, @"\bdeselect_all_crew\b", "vw_fixture_native_clear");
var code = new CodeImportGroup(Data);
var mask = new UndertaleGameObject { Name = Data.Strings.MakeString("oVWFixtureMask"),
    Sprite = Data.GameObjects.ByName("oCrewCollision").Sprite, Visible = false };
Data.GameObjects.Add(mask);
Data.GameObjects.Add(new UndertaleGameObject { Name = Data.Strings.MakeString("oVWFixturePortrait"), Visible = false });
code.QueueReplace("gml_GlobalScript_vw_fixture_native_select", isolated);
code.QueueReplace("gml_Object_oVWFixtureCursor_Create_0", @"
visible = false;
currSelected = ds_list_create();
cursorDebugMode = """";
startX = -1;
startY = -1;
endX = -1;
endY = -1;
dragSelectedCrewInThisStep = false;
");
code.QueueReplace("gml_Object_oVWFixtureCursor_CleanUp_0", "ds_list_destroy(currSelected);");
code.QueueReplace("gml_Object_oVWFixtureCrew_Create_0", @"
visible = false;
allied = true;
enableFriendlyCrewAI = false;
unitSelected = false;
selectionCol = 0;
");
code.QueueReplace("gml_Room_rmVoidWarGuestView_Create", @"
show_debug_message(""[Native guest selection fixture] room entered"");
global.tutorial_disableCrewSelection = false;
var _cursor = instance_create_depth(0, 0, 0, oVWFixtureCursor);
var _crew = instance_create_depth(500, 350, 0, oVWFixtureCrew);
var _mask = instance_create_depth(mouse_x - 15, mouse_y - 15, 0, oVWFixtureMask);
_crew.selectionCol = _mask;
_mask.image_xscale = 30;
_mask.image_yscale = 30;
with (_cursor) {
    startX = 0;
    startY = 0;
    endX = 0;
    endY = 0;
    vw_fixture_native_select();
    if (ds_list_size(currSelected) != 1 || ds_list_find_value(currSelected, 0) != _crew || !_crew.unitSelected) {
        show_debug_message(""[Native guest selection fixture] FAIL click"");
        game_end();
    }
    show_debug_message(""[Native guest selection fixture] click resolved"");
    _mask.x = mouse_x + 150;
    _mask.y = mouse_y + 150;
    startX = 0;
    startY = 0;
    endX = 0;
    endY = 0;
    vw_fixture_native_select();
    if (ds_list_size(currSelected) || _crew.unitSelected) {
        show_debug_message(""[Native guest selection fixture] FAIL clear"");
        game_end();
    }
}
with (oVoidWarConnectionProbe) {
    show_debug_message(""[Native guest selection fixture] clear resolved"");
    crew_token = 1;
    crew_rooms = [[0, 0, 40, 40, [[10, 20], [30, 20]]]];
    guest_selected = _crew.unitSelected;
    layout_guest_view();
    var _gx = guest_layout[0] + 30 * guest_layout[2];
    var _gy = guest_layout[1] + 20 * guest_layout[2];
    read_guest_click(_gx, _gy, false, true);
    if (crew_pending != 0) {
        show_debug_message(""[Native guest selection fixture] FAIL order while deselected"");
        game_end();
    }
    with (_cursor) {
        startX = 480;
        startY = 330;
        endX = 520;
        endY = 370;
        vw_fixture_native_select();
    }
    if (ds_list_size(_cursor.currSelected) != 1 || ds_list_find_value(_cursor.currSelected, 0) != _crew || !_crew.unitSelected) {
        show_debug_message(""[Native guest selection fixture] FAIL drag"");
        game_end();
    }
    guest_selected = _crew.unitSelected;
    read_guest_click(_gx, _gy, false, true);
    if (crew_pending == 0 || crew_order_room != 1 || crew_order_tile != 2) {
        show_debug_message(""[Native guest selection fixture] FAIL tile order"");
        game_end();
    }
    clear_crew_test();
}
show_debug_message(""[Native guest selection fixture] PASS click, clear, drag, gated tile order"");
game_end();
");
code.QueueReplace("gml_Room_rmMainMenu_Create", "instance_create_depth(0, 0, 100, oVoidWarConnectionProbe); room_goto(rmVoidWarGuestView);");
code.Import();
Data.Rooms.ByName("rmVoidWarGuestView").CreationCodeId = Data.Code.ByName("gml_Room_rmVoidWarGuestView_Create");
