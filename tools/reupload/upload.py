"""Upload exported animations/audio through Open Cloud. Resumable: results kept in results.json."""
import json, os, sys, time, uuid, urllib.request, urllib.error

KEY = os.environ["ROBLOX_API_KEY"]
USER_ID = os.environ.get("ROBLOX_USER_ID", "102707091")  # the account the API key belongs to
BASE = "https://apis.roblox.com/assets/v1/"

def _req(url, data=None, headers=None, method="GET"):
    h = {"x-api-key": KEY}
    h.update(headers or {})
    req = urllib.request.Request(url, data=data, headers=h, method=method)
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            return r.status, json.loads(r.read() or b"{}")
    except urllib.error.HTTPError as e:
        body = e.read().decode(errors="replace")
        return e.code, {"error": body[:500]}

def create(path, asset_type, display, ctype, desc):
    b = uuid.uuid4().hex
    meta = {"assetType": asset_type, "displayName": display[:50], "description": desc,
            "creationContext": {"creator": {"userId": USER_ID}}}
    body = (f"--{b}\r\nContent-Disposition: form-data; name=\"request\"\r\n\r\n{json.dumps(meta)}\r\n"
            f"--{b}\r\nContent-Disposition: form-data; name=\"fileContent\"; filename=\"{os.path.basename(path)}\"\r\n"
            f"Content-Type: {ctype}\r\n\r\n").encode() + open(path, "rb").read() + f"\r\n--{b}--\r\n".encode()
    for attempt in range(5):
        st, js = _req(BASE + "assets", body, {"Content-Type": f"multipart/form-data; boundary={b}"}, "POST")
        if st == 429 or st >= 500:
            time.sleep(2 ** (attempt + 2)); continue
        break
    if st != 200:
        return {"status": st, **js}
    op = js.get("path") or js.get("operationId")
    for _ in range(60):
        if js.get("done"):
            break
        time.sleep(2)
        st, js = _req(BASE + (op if op.startswith("operations/") else "operations/" + op))
    return js

def main(manifest_path, results_path, only=None):
    items = json.load(open(manifest_path))
    results = json.load(open(results_path)) if os.path.exists(results_path) else {}
    for it in items:
        key = it["file"]
        if only and only not in key:
            continue
        if results.get(key, {}).get("assetId"):
            continue
        js = create(it["file"], it.get("type", "Animation"), it["display"], it.get("ctype", "model/x-rbxm"),
                    it.get("desc", "Oathbound prototype"))
        aid = (js.get("response") or {}).get("assetId")
        results[key] = {"assetId": aid, "raw": None if aid else js}
        print(it["display"], "->", aid or js, flush=True)
        json.dump(results, open(results_path, "w"), indent=1)
        time.sleep(1)

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else None)
