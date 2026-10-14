"""Fill tools/glossary/mymemory-cache.json with MyMemory's current te->en answer
for every drafted word (what the app shows today), for side-by-side review.
Stops cleanly if the free daily quota runs out."""
import json, glob, time, urllib.request, urllib.parse
CACHE = "tools/glossary/mymemory-cache.json"
cache = json.load(open(CACHE))
words = []
for f in sorted(glob.glob("tools/glossary/drafts/story*.json")):
    words += [e["word"] for e in json.load(open(f))["entries"]]
todo = [w for w in dict.fromkeys(words) if w not in cache]
print("to fetch:", len(todo), flush=True)
for i, w in enumerate(todo):
    url = "https://api.mymemory.translated.net/get?" + urllib.parse.urlencode({"q": w, "langpair": "te|en"})
    try:
        r = json.load(urllib.request.urlopen(url, timeout=15))
    except Exception as ex:
        print("error", w, ex, flush=True); time.sleep(2); continue
    text = (r.get("responseData") or {}).get("translatedText", "").strip()
    if r.get("responseStatus") == 429 or "MYMEMORY WARNING" in text.upper():
        print("quota reached after", i, "lookups", flush=True); break
    cache[w] = text.lower()
    if i % 50 == 0:
        json.dump(cache, open(CACHE, "w"), ensure_ascii=False, indent=1); print(i, flush=True)
    time.sleep(0.35)
json.dump(cache, open(CACHE, "w"), ensure_ascii=False, indent=1)
print("done; cached", len(cache), flush=True)
