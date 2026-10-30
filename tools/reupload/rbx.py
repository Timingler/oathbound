"""Minimal Roblox binary (.rbxm/.rbxl) reader: instances, parents, and the property types animations need."""
import struct, sys, lz4.block, zstandard

def _untransform(n):
    return (n >> 1) ^ -(n & 1)

def _interleave(data, off, count, width):
    out = []
    for i in range(count):
        b = bytes(data[off + j * count + i] for j in range(width))
        out.append(b)
    return out, off + count * width

def _i32s(data, off, count):
    raw, off = _interleave(data, off, count, 4)
    return [_untransform(struct.unpack(">I", b)[0]) for b in raw], off

def _u32s(data, off, count):
    raw, off = _interleave(data, off, count, 4)
    return [struct.unpack(">I", b)[0] for b in raw], off

def _floats(data, off, count):
    raw, off = _interleave(data, off, count, 4)
    vals = []
    for b in raw:
        n = struct.unpack(">I", b)[0]
        n = ((n >> 1) | ((n & 1) << 31)) & 0xFFFFFFFF
        vals.append(struct.unpack(">f", struct.pack(">I", n))[0])
    return vals, off

def _refs(data, off, count):
    vals, off = _i32s(data, off, count)
    acc, out = 0, []
    for v in vals:
        acc += v
        out.append(acc)
    return out, off

def _string(data, off):
    n = struct.unpack_from("<I", data, off)[0]
    return bytes(data[off + 4:off + 4 + n]), off + 4 + n

ROT_IDS = {
    0x02: (1,0,0,0,1,0,0,0,1), 0x03: (1,0,0,0,0,-1,0,1,0), 0x05: (1,0,0,0,-1,0,0,0,-1),
    0x06: (1,0,0,0,0,1,0,-1,0), 0x07: (0,1,0,1,0,0,0,0,-1), 0x09: (0,0,1,1,0,0,0,1,0),
    0x0a: (0,-1,0,1,0,0,0,0,1), 0x0c: (0,0,-1,1,0,0,0,-1,0), 0x0d: (0,1,0,0,0,1,1,0,0),
    0x0e: (0,0,-1,0,1,0,1,0,0), 0x10: (0,-1,0,0,0,-1,1,0,0), 0x11: (0,0,1,0,-1,0,1,0,0),
    0x14: (-1,0,0,0,1,0,0,0,-1), 0x15: (-1,0,0,0,0,1,0,1,0), 0x17: (-1,0,0,0,-1,0,0,0,1),
    0x18: (-1,0,0,0,0,-1,0,-1,0), 0x19: (0,1,0,-1,0,0,0,0,1), 0x1b: (0,0,-1,-1,0,0,0,1,0),
    0x1c: (0,-1,0,-1,0,0,0,0,-1), 0x1e: (0,0,1,-1,0,0,0,-1,0), 0x1f: (0,1,0,0,0,-1,-1,0,0),
    0x20: (0,0,1,0,1,0,-1,0,0), 0x22: (0,-1,0,0,0,1,-1,0,0), 0x23: (0,0,-1,0,-1,0,-1,0,0),
}

class Inst:
    def __init__(self, ref, cls):
        self.ref, self.cls, self.props, self.parent, self.children = ref, cls, {}, None, []
    def name(self):
        n = self.props.get("Name")
        return n.decode("utf-8", "replace") if isinstance(n, bytes) else str(n)
    def path(self):
        parts, cur = [], self
        while cur is not None:
            parts.append(cur.name())
            cur = cur.parent
        return ".".join(reversed(parts))
    def descendants(self):
        for c in self.children:
            yield c
            yield from c.descendants()

def load(path):
    data = open(path, "rb").read()
    assert data[:8] == b"<roblox!"
    off = 32
    classes, insts, sstrs = {}, {}, []
    while off < len(data):
        name = data[off:off + 4]
        clen, ulen = struct.unpack_from("<II", data, off + 4)
        off += 16
        if clen == 0:
            body = data[off:off + ulen]; off += ulen
        else:
            raw = data[off:off + clen]; off += clen
            if raw[:4] == b"\x28\xb5\x2f\xfd":
                body = zstandard.ZstdDecompressor().decompress(raw, max_output_size=ulen)
            else:
                body = lz4.block.decompress(raw, uncompressed_size=ulen)
        if name == b"END\x00":
            break
        if name == b"SSTR":
            n = struct.unpack_from("<I", body, 4)[0]; p = 8
            for _ in range(n):
                p += 16
                s, p = _string(body, p); sstrs.append(s)
        elif name == b"INST":
            cid = struct.unpack_from("<i", body, 0)[0]
            cname, p = _string(body, 4)
            p += 1
            cnt = struct.unpack_from("<I", body, p)[0]; p += 4
            refs, p = _refs(body, p, cnt)
            classes[cid] = (cname.decode(), refs)
            for r in refs:
                insts[r] = Inst(r, cname.decode())
        elif name == b"PROP":
            cid = struct.unpack_from("<i", body, 0)[0]
            pname, p = _string(body, 4)
            t = body[p]; p += 1
            refs = classes[cid][1]; n = len(refs)
            vals = None
            try:
                if t == 0x01:
                    vals = []
                    for _ in range(n):
                        s, p = _string(body, p); vals.append(s)
                elif t == 0x02:
                    vals = [bool(b) for b in body[p:p + n]]
                elif t == 0x03:
                    vals, p = _i32s(body, p, n)
                elif t == 0x04:
                    vals, p = _floats(body, p, n)
                elif t == 0x12:
                    vals, p = _u32s(body, p, n)
                elif t == 0x10:
                    rots = []
                    for _ in range(n):
                        rid = body[p]; p += 1
                        if rid == 0:
                            rots.append(struct.unpack_from("<9f", body, p)); p += 36
                        else:
                            rots.append(ROT_IDS[rid])
                    xs, p = _floats(body, p, n); ys, p = _floats(body, p, n); zs, p = _floats(body, p, n)
                    vals = [(xs[i], ys[i], zs[i]) + tuple(rots[i]) for i in range(n)]
                elif t == 0x0D:
                    xs, p = _floats(body, p, n); ys, p = _floats(body, p, n)
                    vals = list(zip(xs, ys))
                elif t == 0x0E:
                    xs, p = _floats(body, p, n); ys, p = _floats(body, p, n); zs, p = _floats(body, p, n)
                    vals = list(zip(xs, ys, zs))
                elif t in (0x15, 0x16):
                    width = 3 if t == 0x15 else 5
                    vals = []
                    for _ in range(n):
                        k = struct.unpack_from("<I", body, p)[0]; p += 4
                        vals.append([struct.unpack_from("<%df" % width, body, p + j * 4 * width) for j in range(k)])
                        p += k * 4 * width
                elif t == 0x17:
                    vals = []
                    for _ in range(n):
                        vals.append(struct.unpack_from("<2f", body, p)); p += 8
                elif t == 0x1C:
                    idx, p = _u32s(body, p, n)
                    vals = [sstrs[i] for i in idx]
                elif t == 0x22:
                    # Content: source types, then uris / objects / externals
                    kinds, p = _i32s(body, p, n)
                    nuri = struct.unpack_from("<I", body, p)[0]; p += 4
                    uris = []
                    for _ in range(nuri):
                        s, p = _string(body, p); uris.append(s)
                    it = iter(uris)
                    vals = [next(it) if k == 1 else b"" for k in kinds]
            except Exception:
                vals = None
            if vals is not None:
                for r, v in zip(refs, vals):
                    insts[r].props[pname.decode()] = v
        elif name == b"PRNT":
            cnt = struct.unpack_from("<I", body, 1)[0]
            ch, p = _refs(body, 5, cnt)
            pa, p = _refs(body, p, cnt)
            for c, q in zip(ch, pa):
                if q >= 0 and q in insts:
                    insts[c].parent = insts[q]
                    insts[q].children.append(insts[c])
    return insts

if __name__ == "__main__":
    insts = load(sys.argv[1])
    from collections import Counter
    print(Counter(i.cls for i in insts.values()).most_common(25))
