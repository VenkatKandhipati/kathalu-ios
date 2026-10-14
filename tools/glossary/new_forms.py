"""Print a story's text and the word forms not yet covered by any draft."""
import json, re, sys, glob
idx = int(sys.argv[1])
stories = json.load(open("Kathalu/Resources/stories.json"))
done = set()
for f in glob.glob("tools/glossary/drafts/story*.json"):
    done |= {e["word"] for e in json.load(open(f))["entries"]}
text = stories[idx]["text"]
forms = list(dict.fromkeys(re.findall(r'[ఀ-౿]+', text)))
new = [w for w in forms if w not in done]
print(f"[{idx}] {stories[idx]['titleEn']} — {len(forms)} forms, {len(new)} new\n")
print(text)
print("\nNEW:", " ".join(new))
