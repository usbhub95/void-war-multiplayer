using System;
using System.IO;
using System.Linq;
using UndertaleModLib;
using UndertaleModLib.Compiler;
using UndertaleModLib.Models;

const string objectName = "oVoidWarConnectionProbe";
const string roomEntry = "gml_Room_rmMainMenu_Create";
var room = Data.Rooms.ByName("rmMainMenu")
    ?? throw new InvalidOperationException("The supported game's main menu room is missing.");
if (room.CreationCodeId != null || Data.Code.ByName(roomEntry) != null)
    throw new InvalidOperationException("The title room already has creation code.");
if (Data.GameObjects.ByName(objectName) != null)
    throw new InvalidOperationException("The connection probe already exists in this game data.");

// The game ships these Steam functions without code references. Register them so
// the compiler emits direct calls rather than reads of uninitialized variables.
var steamFunctions = new[] { "steam_net_packet_get_size", "steam_net_close_p2p_session" };
foreach (var name in steamFunctions)
{
    var extensionFunction = Data.Extensions.SelectMany(extension => extension.Files)
        .SelectMany(file => file.Functions).SingleOrDefault(function => function.Name.Content == name)
        ?? throw new InvalidOperationException($"The bundled Steam extension is missing {name}.");
    if (Data.Functions.ByName(name) == null)
    {
        Data.Functions.Add(new UndertaleFunction
        {
            Name = extensionFunction.Name,
            NameStringID = Data.Strings.IndexOf(extensionFunction.Name)
        });
    }
}

var source = Path.GetDirectoryName(ScriptPath);
var code = new CodeImportGroup(Data);
foreach (var (eventName, filename) in new[] {
    ("Create_0", "Create.gml"),
    ("Step_0", "Step.gml"),
    ("Draw_64", "DrawGui.gml"),
    ("CleanUp_0", "Cleanup.gml")
}) {
    code.QueueReplace($"gml_Object_{objectName}_{eventName}", File.ReadAllText(Path.Combine(source, filename)));
}
code.QueueReplace(roomEntry, $"instance_create_depth(0, 0, 100, {objectName});");
code.Import();
var create = Data.Code.ByName($"gml_Object_{objectName}_Create_0");
foreach (var name in steamFunctions)
{
    if (!create.Instructions.Any(instruction => instruction.Kind == UndertaleInstruction.Opcode.Call
        && instruction.ValueFunction?.Name.Content == name))
        throw new InvalidOperationException($"The probe did not compile a direct call to {name}.");
}

var probe = Data.GameObjects.ByName(objectName);
probe.Visible = true;
probe.Persistent = false;
room.CreationCodeId = Data.Code.ByName(roomEntry);
Console.WriteLine("Compiled the probe and linked it to rmMainMenu creation code.");
