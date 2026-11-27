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

const string guestRoom = "rmVoidWarGuestView";
if (Data.Rooms.ByName(guestRoom) != null)
    throw new InvalidOperationException("The guest view room already exists in this game data.");
var viewRoom = new UndertaleRoom
{
    Name = Data.Strings.MakeString(guestRoom),
    Width = 1280,
    Height = 720,
    Speed = 0,
    DrawBackgroundColor = false,
    Flags = room.Flags & ~(UndertaleRoom.RoomEntryFlags.EnableViews
        | UndertaleRoom.RoomEntryFlags.ShowColor | UndertaleRoom.RoomEntryFlags.DoNotClearDisplayBuffer)
};
viewRoom.Backgrounds.Clear();
viewRoom.Layers.Add(new UndertaleRoom.Layer
{
    LayerName = Data.Strings.MakeString("Instances"),
    LayerId = Data.Rooms.SelectMany(candidate => candidate.Layers).Max(layer => layer.LayerId) + 1,
    LayerType = UndertaleRoom.LayerType.Instances,
    LayerDepth = 0,
    Data = new UndertaleRoom.Layer.LayerInstancesData()
});
Data.Rooms.Add(viewRoom);

// Read the starter layout from the installed game data. Use the sprites assigned
// by the cell Create events and leave the original room and objects untouched.
var starter = Data.Rooms.ByName("rmStart_EMCruiserA_gunBoarding")
    ?? throw new InvalidOperationException("The Empire cruiser starter room is missing.");
var cellSprites = new System.Collections.Generic.Dictionary<string, string>
{
    ["oCellSingle"] = "spr_box_ltGray",
    ["oCellWide"] = "spr_boxWide_ltGray",
    ["oCellTall"] = "spr_boxTall_ltGray",
    ["oCellLarge"] = "spr_boxLarge_ltGray"
};
var starterCells = starter.GameObjects.Where(placed => cellSprites.ContainsKey(placed.ObjectDefinition.Name.Content)).ToArray();
var minX = starterCells.Min(placed => placed.X);
var minY = starterCells.Min(placed => placed.Y);
var hull = starter.GameObjects.Single(placed => placed.ObjectDefinition.Name.Content == "oHullPlayerEMCruiserA");
var border = starter.GameObjects.Single(placed => placed.ObjectDefinition.Name.Content == "oShipBorderPlayerEMCruiserA");
var cells = starterCells.Select(placed =>
    $"[{placed.X - minX}, {placed.Y - minY}, {cellSprites[placed.ObjectDefinition.Name.Content]}]");
var nativeLayout = $"guest_native_hull_name = \"{hull.ObjectDefinition.Sprite.Name.Content}\";\n"
    + $"guest_native_border = [{border.ObjectDefinition.Sprite.Name.Content}, {border.X - hull.X}, {border.Y - hull.Y}];\n"
    + $"guest_native_cells = [{string.Join(", ", cells)}];\n";

var source = Path.GetDirectoryName(ScriptPath);
var code = new CodeImportGroup(Data);
foreach (var (eventName, filename) in new[] {
    ("Create_0", "Create.gml"),
    ("Step_0", "Step.gml"),
    ("Draw_64", "DrawGui.gml"),
    ("CleanUp_0", "Cleanup.gml")
}) {
    var gml = File.ReadAllText(Path.Combine(source, filename));
    if (eventName == "Create_0")
        gml += "\n" + File.ReadAllText(Path.Combine(source, "CrewTest.gml"))
            + "\n" + File.ReadAllText(Path.Combine(source, "GuestView.gml"))
            + "\n" + nativeLayout + File.ReadAllText(Path.Combine(source, "NativeGuestShip.gml"));
    code.QueueReplace($"gml_Object_{objectName}_{eventName}", gml);
}
code.QueueReplace(roomEntry, $"if (!instance_exists({objectName})) instance_create_depth(0, 0, 100, {objectName});");
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
probe.Persistent = true;
room.CreationCodeId = Data.Code.ByName(roomEntry);
Console.WriteLine("Compiled the probe and linked it to rmMainMenu creation code.");
