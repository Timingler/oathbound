"""Export every KeyframeSequence in the given kit files as standalone .rbxmx files plus a manifest."""
import json, os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rbx
from xml.sax.saxutils import escape

def rig_of(kfs):
    names = {d.name() for d in kfs.descendants() if d.cls == "Pose"}
    return "R15" if "UpperTorso" in names else "R6"

def xml_inst(inst, out, depth, counter):
    if inst.cls not in ("KeyframeSequence", "Keyframe", "Pose", "KeyframeMarker"):
        return
    counter[0] += 1
    p = inst.props
    out.append(f'<Item class="{inst.cls}" referent="RBX{counter[0]}"><Properties>')
    out.append(f'<string name="Name">{escape(inst.name())}</string>')
    if inst.cls == "KeyframeSequence":
        out.append(f'<bool name="Loop">{"true" if p.get("Loop") else "false"}</bool>')
        out.append(f'<token name="Priority">{p.get("Priority", 2)}</token>')
        out.append(f'<float name="AuthoredHipHeight">{p.get("AuthoredHipHeight", 2.0)}</float>')
    elif inst.cls == "Keyframe":
        out.append(f'<float name="Time">{p.get("Time", 0.0)!r}</float>')
    elif inst.cls == "Pose":
        c = p.get("CFrame", (0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1))
        keys = ["X", "Y", "Z", "R00", "R01", "R02", "R10", "R11", "R12", "R20", "R21", "R22"]
        out.append('<CoordinateFrame name="CFrame">' + "".join(f"<{k}>{float(v)!r}</{k}>" for k, v in zip(keys, c)) + "</CoordinateFrame>")
        out.append(f'<token name="EasingDirection">{p.get("EasingDirection", 0)}</token>')
        out.append(f'<token name="EasingStyle">{p.get("EasingStyle", 0)}</token>')
        out.append(f'<float name="Weight">{p.get("Weight", 1.0)!r}</float>')
        if "MaskWeight" in p:
            out.append(f'<float name="MaskWeight">{p["MaskWeight"]!r}</float>')
    elif inst.cls == "KeyframeMarker":
        v = p.get("Value", b"")
        v = v.decode("utf-8", "replace") if isinstance(v, bytes) else str(v)
        out.append(f'<string name="Value">{escape(v)}</string>')
    out.append("</Properties>")
    for c in inst.children:
        xml_inst(c, out, depth + 1, counter)
    out.append("</Item>")

def main(outdir, files):
    os.makedirs(outdir, exist_ok=True)
    manifest = []
    for f in files:
        kit = re.sub(r"^[0-9a-f]{8}-", "", os.path.basename(f)).rsplit(".", 1)[0]
        for inst in rbx.load(f).values():
            if inst.cls != "KeyframeSequence":
                continue
            out = ['<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" version="4">']
            xml_inst(inst, out, 0, [0])
            out.append("</roblox>")
            slug = re.sub(r"[^A-Za-z0-9]+", "_", f"{kit}__{inst.name()}").strip("_")
            path = os.path.join(outdir, slug + ".rbxmx")
            open(path, "w").write("".join(out))
            kfs = [c for c in inst.children if c.cls == "Keyframe"]
            manifest.append({"kit": kit, "name": inst.name(), "rig": rig_of(inst), "file": path,
                             "loop": bool(inst.props.get("Loop")),
                             "length": max([k.props.get("Time", 0) for k in kfs] or [0])})
    json.dump(manifest, open(os.path.join(outdir, "manifest.json"), "w"), indent=1)
    print(len(manifest), "exported")

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2:])
