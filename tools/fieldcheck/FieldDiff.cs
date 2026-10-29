using System.Reflection.Metadata;
using System.Reflection.PortableExecutable;

// Lists the instance fields Unity could serialize on every type in an assembly,
// in declaration order, and diffs two builds. A changed set/order on a type that
// lives in a built scene shifts the serialized layout of that component.
static (Dictionary<string, List<string>> fields, Dictionary<string, string> bases) Scan(string path)
{
    using var fs = File.OpenRead(path);
    using var pe = new PEReader(fs);
    var md = pe.GetMetadataReader();
    var fields = new Dictionary<string, List<string>>();
    var bases = new Dictionary<string, string>();
    foreach (var th in md.TypeDefinitions)
    {
        var t = md.GetTypeDefinition(th);
        var ns = md.GetString(t.Namespace);
        var name = md.GetString(t.Name);
        if (name.StartsWith("<")) continue;
        var full = string.IsNullOrEmpty(ns) ? name : ns + "." + name;
        string BaseName(EntityHandle h) => h.Kind switch
        {
            HandleKind.TypeDefinition => md.GetString(md.GetTypeDefinition((TypeDefinitionHandle)h).Name),
            HandleKind.TypeReference => md.GetString(md.GetTypeReference((TypeReferenceHandle)h).Name),
            _ => ""
        };
        bases[full] = BaseName(t.BaseType);
        var list = new List<string>();
        foreach (var fh in t.GetFields())
        {
            var f = md.GetFieldDefinition(fh);
            var fn = md.GetString(f.Name);
            if (fn.StartsWith("<")) continue;
            if (f.Attributes.HasFlag(System.Reflection.FieldAttributes.Static)) continue;
            if (f.Attributes.HasFlag(System.Reflection.FieldAttributes.Literal)) continue;
            bool isPublic = f.Attributes.HasFlag(System.Reflection.FieldAttributes.Public);
            bool serialize = false, skip = false;
            foreach (var ah in f.GetCustomAttributes())
            {
                string an = AttrName(md, md.GetCustomAttribute(ah));
                if (an is "SerializeField" or "SerializeReference") serialize = true;
                if (an == "NonSerialized") skip = true;
            }
            if (skip) continue;
            if (isPublic || serialize)
                list.Add(fn +
                    (f.Attributes.HasFlag(System.Reflection.FieldAttributes.NotSerialized) ? " [NotSerialized]" : "") +
                    (f.Attributes.HasFlag(System.Reflection.FieldAttributes.InitOnly) ? " [readonly]" : ""));
        }
        fields[full] = list;
    }
    return (fields, bases);
}

static string AttrName(MetadataReader md, CustomAttribute attr)
{
    switch (attr.Constructor.Kind)
    {
        case HandleKind.MemberReference:
            var mr = md.GetMemberReference((MemberReferenceHandle)attr.Constructor);
            if (mr.Parent.Kind == HandleKind.TypeReference)
                return md.GetString(md.GetTypeReference((TypeReferenceHandle)mr.Parent).Name);
            return "";
        case HandleKind.MethodDefinition:
            var mdef = md.GetMethodDefinition((MethodDefinitionHandle)attr.Constructor);
            return md.GetString(md.GetTypeDefinition(mdef.GetDeclaringType()).Name);
        default: return "";
    }
}

var (a, ab) = Scan(args[0]);
var (b, bb) = Scan(args[1]);
int changed = 0, broken = 0;
foreach (var kv in a)
{
    if (!b.TryGetValue(kv.Key, out var nb)) { Console.WriteLine("TYPE-GONE  " + kv.Key); continue; }
    var oldF = kv.Value; var newF = nb;
    var added = newF.Except(oldF).ToList();
    var removed = oldF.Except(newF).ToList();
    var commonOld = oldF.Where(newF.Contains).ToList();
    var commonNew = newF.Where(oldF.Contains).ToList();
    if (added.Count == 0 && removed.Count == 0 && commonOld.SequenceEqual(commonNew)) continue;
    changed++;
    string baseName = ab.GetValueOrDefault(kv.Key) ?? "";
    bool live = baseName == "MonoBehaviour";
    if (live) broken++;
    Console.WriteLine("CHANGED    " + kv.Key + "  (base " + baseName + ")" + (live ? "   <-- BREAKS SCENES" : ""));
    foreach (var f in added) Console.WriteLine("   + " + f);
    foreach (var f in removed) Console.WriteLine("   - " + f);
    if (added.Count == 0 && removed.Count == 0) Console.WriteLine("   ! order changed: " + string.Join(",", commonNew));
}
foreach (var kv in b) if (!a.ContainsKey(kv.Key)) Console.WriteLine("TYPE-NEW   " + kv.Key + "  (base " + bb.GetValueOrDefault(kv.Key) + ")");
Console.WriteLine($"changed types: {changed}, MonoBehaviour layout breaks: {broken}");
if (broken > 0)
{
    Console.WriteLine("A serialized field was added to/removed from a MonoBehaviour that already exists in the");
    Console.WriteLine("shipped scenes. Make the field private/[NonSerialized] or move it to a new class.");
    Environment.Exit(1);
}
