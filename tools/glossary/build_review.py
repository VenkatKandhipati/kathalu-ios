"""Merge the per-story drafts into tools/glossary/review/glossary.json, the data
file the glossary review page loads. Adds romanizations (via the app's own
Transliterator), the story sentence each word appears in, and MyMemory's
current answer for comparison."""
import json, glob, re, subprocess, tempfile, os
ROOT = "tools/glossary"
stories = json.load(open("Kathalu/Resources/stories.json"))
mm = json.load(open(f"{ROOT}/mymemory-cache.json")) if os.path.exists(f"{ROOT}/mymemory-cache.json") else {}
# Words where MyMemory gives a real, different meaning (not noise or a synonym) — hand-picked.
disputed = set(json.load(open(f"{ROOT}/disputed.json"))) if os.path.exists(f"{ROOT}/disputed.json") else set()
tel = re.compile(r'[ఀ-౿]+')

def sentences(text):
    """Split on . ! ? outside quotes; '..' is a pause, not an end (mirrors the widget)."""
    out, cur, depth, chars, i = [], "", 0, list(text), 0
    while i < len(chars):
        ch = chars[i]; cur += ch
        if ch in "‘“": depth += 1
        elif ch in "’”": depth = max(0, depth - 1)
        elif ch in "'\"": depth = depth - 1 if depth > 0 else 1
        if ch in ".!?":
            run = 1
            while i + 1 < len(chars) and chars[i + 1] in ".!?":
                i += 1; run += 1; cur += chars[i]
            ellipsis = run >= 2 and chars[i] == "."
            at_break = i + 1 >= len(chars) or chars[i + 1].isspace()
            if depth == 0 and not ellipsis and at_break:
                out.append(cur.strip()); cur = ""
        i += 1
    if cur.strip(): out.append(cur.strip())
    return out

story_sents = [[s for p in st["text"].split("\n\n") for s in sentences(p)] for st in stories]

entries = []
for f in sorted(glob.glob(f"{ROOT}/drafts/story*.json")):
    d = json.load(open(f))
    for e in d["entries"]:
        e["firstStory"] = d["story"]
        entries.append(e)

# Context sentence per entry (first story it appears in).
for e in entries:
    w = e["word"]
    e["_appears"] = [i for i, st in enumerate(stories) if w in tel.findall(st["text"])]
    s0 = e["_appears"][0] if e["_appears"] else e["firstStory"]
    e["_ctx"] = next((s for s in story_sents[s0] if w in tel.findall(s)), "")

# Romanize every word, base word and context sentence with the app's Transliterator.
strings = sorted({e["word"] for e in entries} | {e["base"] for e in entries if "base" in e}
                 | {e["_ctx"] for e in entries if e["_ctx"]})
with tempfile.TemporaryDirectory() as tmp:
    exe = os.path.join(tmp, "translit")
    main = os.path.join(tmp, "main.swift")   # top-level code must live in main.swift
    open(main, "w").write(open(f"{ROOT}/translit_cli.swift").read())
    subprocess.run(["swiftc", "-O", "Kathalu/Services/Transliterator.swift", main, "-o", exe],
                   check=True, capture_output=True)
    lst = os.path.join(tmp, "in.json"); json.dump(strings, open(lst, "w"), ensure_ascii=False)
    trans = json.loads(subprocess.run([exe, lst], check=True, capture_output=True).stdout)

out = []
for e in entries:
    w, appears, ctx = e["word"], e["_appears"], e["_ctx"]
    out.append({
        "id": "w-" + w.encode("utf-8").hex(),       # stable db doc id (letters/digits only)
        "word": w, "trans": trans[w],
        "meaning": e["meaning"],
        **({"base": e["base"], "baseTrans": trans[e["base"]], "baseMeaning": e.get("baseMeaning", "")} if "base" in e else {}),
        "pos": e.get("pos", ""), "note": e.get("note", ""), "confidence": e["confidence"],
        "stories": appears, "context": ctx, "contextTrans": trans.get(ctx, ""), "mymemory": mm.get(w), "disputed": w in disputed,
    })

data = {"stories": [{"index": i, "title": s["title"], "titleEn": s["titleEn"]} for i, s in enumerate(stories)],
        "entries": out}
json.dump(data, open(f"{ROOT}/review/glossary.json", "w"), ensure_ascii=False, separators=(",", ":"))
conf = {c: sum(1 for e in out if e["confidence"] == c) for c in ("high", "medium", "low")}
print(f"wrote {len(out)} entries | confidence {conf} | mymemory {sum(1 for e in out if e['mymemory'])} | "
      f"{os.path.getsize(ROOT + '/review/glossary.json') // 1024} KB")
