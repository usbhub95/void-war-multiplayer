#load "NativeSelectionSource.csx"

using System;
using System.Collections.Generic;
using System.IO;
using UndertaleModLib;
using UndertaleModLib.Compiler;
using UndertaleModLib.Models;

const string cursor = "oVoidWarGuestSelectionCursor";
const string crew = "oVoidWarGuestSelectionCrew";
const string mask = "oVoidWarGuestSelectionMask";
const string portrait = "oVoidWarGuestSelectionPortrait";
const string roomCode = "gml_Room_rmVoidWarGuestView_Create";
var guestRoom = Data.Rooms.ByName("rmVoidWarGuestView")
    ?? throw new InvalidOperationException("Build the standard co-op patch before adding guest selection.");
if (guestRoom.CreationCodeId != null)
    throw new InvalidOperationException("The guest room already has creation code.");

var native = CompileSelectionSource(Data, new Dictionary<string, string>
{
    ["oCrew"] = crew,
    ["oUICursor"] = cursor,
    ["oCrewPortrait"] = portrait,
    ["scrCursorCrewSelection"] = "vw_native_guest_select",
    ["deselect_all_crew"] = "vw_native_guest_clear",
    ["mouse_x"] = cursor + ".x",
    ["mouse_y"] = cursor + ".y",
    ["global.tutorial_disableCrewSelection"] = "false"
});

var hitbox = Data.GameObjects.ByName("oCrewCollision")?.Sprite
    ?? throw new InvalidOperationException("The native crew selection mask is missing.");
foreach (var name in new[] { cursor, crew, mask, portrait })
{
    Data.GameObjects.Add(new UndertaleGameObject
    {
        Name = Data.Strings.MakeString(name),
        Sprite = name == mask ? hitbox : null,
        Visible = name == cursor
    });
}

var source = Path.Combine(Path.GetDirectoryName(ScriptPath), "NativeGuestSelection.gml");
var code = new CodeImportGroup(Data);
code.QueueReplace("gml_GlobalScript_vw_native_guest_selection", native + "\n" + File.ReadAllText(source));
code.QueueReplace($"gml_Object_{cursor}_Create_0", "vw_guest_selection_create();");
code.QueueReplace($"gml_Object_{cursor}_Step_{(int)EventSubtypeStep.EndStep}", "vw_guest_selection_update();");
code.QueueReplace($"gml_Object_{cursor}_Draw_{(int)EventSubtypeDraw.DrawGUIEnd}", "vw_guest_selection_draw();");
code.QueueReplace($"gml_Object_{cursor}_CleanUp_0", "vw_guest_selection_cleanup();");
code.QueueReplace(roomCode, $@"
with (oVoidWarConnectionProbe) {{
    instance_create_depth(0, 0, 0, {cursor}, {{ selection_probe: id }});
}}
");
code.Import();
guestRoom.CreationCodeId = Data.Code.ByName(roomCode);
Console.WriteLine("Installed the opt-in native guest selection experiment.");
