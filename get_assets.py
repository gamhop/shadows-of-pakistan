#!/usr/bin/env python3
# Poly Haven (CC0) texture downloader for shadows-of-pakistan. Safe to re-run.
import json, os, sys, urllib.request

API = "https://api.polyhaven.com"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "assets", "tex")
RES = "1k"
# name -> keywords searched in Poly Haven category/tag/name, how many to take
WANT = {
    "brick":    (["brick"], 3),
    "concrete": (["concrete", "plaster", "stucco"], 3),
    "road":     (["asphalt", "road"], 2),
    "tile":     (["tiles", "paving", "pavement", "cobblestone"], 2),
    "ground":   (["ground", "dirt", "sand", "gravel"], 2),
    "roof":     (["roof"], 1),
}
HDR = {"User-Agent": "sop-asset-fetch/1.0"}

def get(url):
    req = urllib.request.Request(url, headers=HDR)
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read()

def getj(url):
    return json.loads(get(url))

def pick_url(files, keys):
    for k in keys:
        try:
            return files[k][RES]["jpg"]["url"]
        except (KeyError, TypeError):
            pass
    return None

def main():
    os.makedirs(OUT, exist_ok=True)
    allt = getj(API + "/assets?t=textures")
    print("textures available:", len(allt))
    used = set()
    ok = 0
    for name, (kws, n) in WANT.items():
        cands = []
        for aid, info in allt.items():
            hay = " ".join([aid] + info.get("categories", []) + info.get("tags", [])).lower()
            if aid not in used and any(k in hay for k in kws):
                cands.append((-info.get("download_count", 0), aid))
        cands.sort()
        got = 0
        for _, aid in cands:
            if got >= n:
                break
            try:
                files = getj(API + "/files/" + aid)
                diff = pick_url(files, ["Diffuse"])
                nor = pick_url(files, ["nor_gl", "nor_dx"])
                rough = pick_url(files, ["Rough"])
                if not diff:
                    continue
                idx = got + 1
                for suffix, url in (("diff", diff), ("nor", nor), ("rough", rough)):
                    if not url:
                        continue
                    path = os.path.join(OUT, "%s_%d_%s.jpg" % (name, idx, suffix))
                    if not os.path.exists(path):
                        with open(path, "wb") as f:
                            f.write(get(url))
                used.add(aid)
                got += 1
                ok += 1
                print("OK  %s_%d <- %s" % (name, idx, aid))
            except Exception as e:
                print("skip", aid, e)
        if got == 0:
            print("--  no texture for", name)
    print("done:", ok, "texture sets in", OUT)

if __name__ == "__main__":
    sys.exit(main())
