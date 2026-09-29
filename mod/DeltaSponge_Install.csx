// =====================================================================
//  DeltaSponge Tool v1.0 - UndertaleModTool installer
//  Run with "Scripts > Run other script..." on a chapter's data.win
//  (DELTARUNE\chapterX_windows\data.win). Keep the "gml" folder next to it.
// =====================================================================
using System;
using System.IO;
using UndertaleModLib;
using UndertaleModLib.Models;
using UndertaleModLib.Compiler;

EnsureDataLoaded();

const string Title = "DeltaSponge Tool";
const string ObjName = "obj_deltasponge";

// --- GML files ------------------------------------------------------
string gmlDir = Path.Combine(Path.GetDirectoryName(ScriptPath), "gml");
string[] parts = { "Create.gml", "BeginStep.gml", "Step.gml", "DrawGUI.gml" };
foreach (string p in parts)
{
    if (!File.Exists(Path.Combine(gmlDir, p)))
    {
        ScriptError("Missing file: gml\\" + p, Title);
        return;
    }
}
string ReadGml(string name) => File.ReadAllText(Path.Combine(gmlDir, name));

// --- Checks -----------------------------------------------------------
if (Data.GameObjects.ByName("obj_mainchara") == null || Data.GameObjects.ByName("obj_encounterbasic") == null)
{
    if (!ScriptQuestion("This is not a DELTARUNE chapter.\nUse DELTARUNE\\chapterX_windows\\data.win\n\nContinue anyway?"))
        return;
}

string[] hostCandidates = { "obj_time", "obj_initializer2", "obj_initializer" };
UndertaleGameObject host = null;
foreach (string h in hostCandidates)
{
    host = Data.GameObjects.ByName(h);
    if (host != null)
        break;
}
if (host == null)
{
    ScriptError("obj_time not found. This is not a DELTARUNE chapter.", Title);
    return;
}

// --- Backup of the original --------------------------------------------
string backupPath = FilePath + ".backup";
try
{
    if (!File.Exists(backupPath))
        File.Copy(FilePath, backupPath);
}
catch (Exception e)
{
    if (!ScriptQuestion("Could not create a backup:\n" + e.Message + "\n\nContinue?"))
        return;
}

// --- Mod object -----------------------------------------------------------
UndertaleGameObject obj = Data.GameObjects.ByName(ObjName);
bool alreadyInstalled = obj != null;
if (obj == null)
{
    obj = new UndertaleGameObject();
    obj.Name = Data.Strings.MakeString(ObjName);
    Data.GameObjects.Add(obj);
}
obj.Persistent = true;
obj.Visible = true;

CodeImportGroup group = new CodeImportGroup(Data);
group.QueueReplace("gml_Object_" + ObjName + "_Create_0", ReadGml("Create.gml"));
group.QueueReplace("gml_Object_" + ObjName + "_Step_1", ReadGml("BeginStep.gml"));
group.QueueReplace("gml_Object_" + ObjName + "_Step_0", ReadGml("Step.gml"));
group.QueueReplace("gml_Object_" + ObjName + "_Draw_64", ReadGml("DrawGUI.gml"));

// --- Auto-spawn: the persistent obj_time creates the menu object ----------
string spawnName = "gml_Object_" + host.Name.Content + "_Step_2";
string spawnCode = "\n// DeltaSponge Tool\nif (!instance_exists(" + ObjName + ")) instance_create_depth(0, 0, -15000, " + ObjName + ");\n";
UndertaleCode spawnEntry = Data.Code.ByName(spawnName);
if (spawnEntry == null)
{
    group.QueueReplace(spawnName, spawnCode);
}
else
{
    bool hasSpawn = alreadyInstalled;
    try { hasSpawn = GetDecompiledText(spawnEntry).Contains(ObjName); } catch { }
    if (!hasSpawn)
        group.QueueAppend(spawnEntry, spawnCode);
}

try
{
    group.Import();
}
catch (Exception e)
{
    ScriptError("GML compile error:\n\n" + e.Message, Title);
    return;
}

ScriptMessage(
    "DeltaSponge Tool " + (alreadyInstalled ? "updated" : "installed") + ".\n\n" +
    "Now save: File > Save (Ctrl+S).\n" +
    "In game: press ` (or F9).");
