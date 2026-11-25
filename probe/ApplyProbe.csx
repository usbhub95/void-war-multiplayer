using System;
using System.IO;
using UndertaleModLib;
using UndertaleModLib.Compiler;

const string objectName = "oVoidWarConnectionProbe";
const string roomEntry = "gml_Room_rmMainMenu_Create";
var room = Data.Rooms.ByName("rmMainMenu")
    ?? throw new InvalidOperationException("The supported game's main menu room is missing.");
if (room.CreationCodeId != null || Data.Code.ByName(roomEntry) != null)
    throw new InvalidOperationException("The title room already has creation code.");
if (Data.GameObjects.ByName(objectName) != null)
    throw new InvalidOperationException("The connection probe already exists in this game data.");

var source = Path.GetDirectoryName(ScriptPath);
var code = new CodeImportGroup(Data);
foreach (var (eventName, filename) in new[] {
    ("Create_0", "Create.gml"),
    ("Step_0", "Step.gml"),
    ("Other_63", "Dialog.gml"),
    ("Draw_64", "DrawGui.gml"),
    ("CleanUp_0", "Cleanup.gml")
}) {
    code.QueueReplace($"gml_Object_{objectName}_{eventName}", File.ReadAllText(Path.Combine(source, filename)));
}
code.QueueReplace(roomEntry, $"instance_create_depth(0, 0, 100, {objectName});");
code.Import();

var probe = Data.GameObjects.ByName(objectName);
probe.Visible = true;
probe.Persistent = false;
room.CreationCodeId = Data.Code.ByName(roomEntry);
Console.WriteLine("Compiled the probe and linked it to rmMainMenu creation code.");
