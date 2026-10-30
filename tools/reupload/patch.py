"""Rewrite string PROP chunks (AnimationId, SoundId, Source) in a binary Roblox file using an old->new ID map."""
import json, struct, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rbx, lz4.block, zstandard

def patch(src, dst, idmap):
    d = open(src, "rb").read()
    out = bytearray(d[:32])
    off, hits = 32, 0
    while off < len(d):
        name = d[off:off + 4]
        clen, ulen, res = struct.unpack_from("<III", d, off + 4)
        raw = d[off + 16:off + 16 + (clen or ulen)]
        nxt = off + 16 + (clen or ulen)
        if name == b"PROP":
            if clen == 0:
                body = raw
            elif raw[:4] == b"\x28\xb5\x2f\xfd":
                body = zstandard.ZstdDecompressor().decompress(raw, max_output_size=ulen)
            else:
                body = lz4.block.decompress(raw, uncompressed_size=ulen)
            pname, p = rbx._string(body, 4)
            if pname in (b"AnimationId", b"SoundId", b"Source") and body[p] == 0x01:
                head, q, vals = body[:p + 1], p + 1, []
                while q < len(body):
                    s, q = rbx._string(body, q)
                    vals.append(s)
                changed = False
                for i, s in enumerate(vals):
                    t = s
                    for old, new in idmap.items():
                        t = t.replace(old.encode(), new.encode())
                    if t != s:
                        vals[i], changed = t, True
                        hits += 1
                if changed:
                    nb = bytes(head) + b"".join(struct.pack("<I", len(v)) + v for v in vals)
                    out += name + struct.pack("<III", 0, len(nb), 0) + nb
                    off = nxt
                    continue
        out += d[off:nxt]
        off = nxt
        if name == b"END\x00":
            out += d[nxt:]
            break
    open(dst, "wb").write(out)
    return hits

if __name__ == "__main__":
    print(patch(sys.argv[1], sys.argv[2], json.load(open(sys.argv[3]))))
