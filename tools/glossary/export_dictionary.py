"""Build the app's bundled dictionary, Kathalu/Resources/dictionary.json, from the
per-story drafts plus the review decisions in reviews.json (a snapshot of the
review page's `reviews` collection). A "fixed" review replaces the meaning;
"ok" and "flag" keep the drafted one.

Output is compact: {word: {m, b?, bm?, p?, n?}} — meaning, base word, base
meaning, part of speech, note."""
import json, glob, os
ROOT = "tools/glossary"
reviews = json.load(open(f"{ROOT}/reviews.json")) if os.path.exists(f"{ROOT}/reviews.json") else {}

out, fixed = {}, 0
for f in sorted(glob.glob(f"{ROOT}/drafts/story*.json")):
    for e in json.load(open(f))["entries"]:
        if e["word"] in out:
            continue
        r = reviews.get(e["word"], {})
        meaning = e["meaning"]
        if r.get("status") == "fixed" and r.get("meaning", "").strip():
            meaning = r["meaning"].strip()
            fixed += 1
        entry = {"m": meaning}
        for src, key in (("base", "b"), ("baseMeaning", "bm"), ("pos", "p"), ("note", "n")):
            if e.get(src):
                entry[key] = e[src]
        # A fix that picked the note's alternate sense swaps the two around.
        if meaning != e["meaning"] and "n" in entry:
            entry["n"] = entry["n"].replace(f"Also: {meaning}", f"Also: {e['meaning']}")
        out[e["word"]] = entry

path = "Kathalu/Resources/dictionary.json"
with open(path, "w") as o:
    json.dump(dict(sorted(out.items())), o, ensure_ascii=False, separators=(",", ":"))
    o.write("\n")
print(f"wrote {len(out)} entries ({fixed} reviewer fixes) | {os.path.getsize(path) // 1024} KB")
