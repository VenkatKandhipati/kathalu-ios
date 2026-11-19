import Foundation

// Pure-logic checks for the decoding engine (Models/Syllables.swift).
// Run: tools/tests/run.sh — compiles the model files with swiftc, no Xcode.
// The segmentations below were done by hand from the bundled stories; they
// are the ground truth the splitter must match exactly.

var failures = 0
var checks = 0

func expect<T: Equatable>(_ actual: T, _ expected: T, _ label: String) {
    checks += 1
    if actual != expected {
        failures += 1
        print("FAIL \(label)\n  expected: \(expected)\n  actual:   \(actual)")
    }
}

// MARK: Syllable splitting — hand-segmented story words

let segmented: [(String, [String])] = [
    ("నక్క", ["న", "క్క"]),
    ("స్వార్థం", ["స్వా", "ర్థం"]),
    ("ఎక్కువ", ["ఎ", "క్కు", "వ"]),
    ("ఎప్పుడూ", ["ఎ", "ప్పు", "డూ"]),
    ("తప్పుడు", ["త", "ప్పు", "డు"]),
    ("ఇస్తుండేది", ["ఇ", "స్తుం", "డే", "ది"]),
    ("విశ్రాంతి", ["వి", "శ్రాం", "తి"]),
    ("చెట్టు", ["చె", "ట్టు"]),
    ("కూర్చుంది", ["కూ", "ర్చుం", "ది"]),
    ("అప్పుడే", ["అ", "ప్పు", "డే"]),
    ("అక్కడికి", ["అ", "క్క", "డి", "కి"]),
    ("ఉన్న", ["ఉ", "న్న"]),
    ("వచ్చింది", ["వ", "చ్చిం", "ది"]),
    ("పండ్లు", ["పం", "డ్లు"]),
    ("ఉన్నాయి", ["ఉ", "న్నా", "యి"]),
    ("హమ్మయ్యా", ["హ", "మ్మ", "య్యా"]),
    ("వెతుక్కుంటూ", ["వె", "తు", "క్కుం", "టూ"]),
    ("తినేస్తా", ["తి", "నే", "స్తా"]),
    ("మెల్లగా", ["మె", "ల్ల", "గా"]),
    ("ఎక్కబోతోంది", ["ఎ", "క్క", "బో", "తోం", "ది"]),
    ("శ్రమపడతావు", ["శ్ర", "మ", "ప", "డ", "తా", "వు"]),
    ("కర్ర", ["క", "ర్ర"]),
    ("ఎంచక్కా", ["ఎం", "చ", "క్కా"]),
    ("తినేయొచ్చు", ["తి", "నే", "యొ", "చ్చు"]),
    ("మళ్లీ", ["మ", "ళ్లీ"]),
    ("విద్య", ["వి", "ద్య"]),
    ("నువ్వు", ["ను", "వ్వు"]),
    ("ఏకాగ్రత", ["ఏ", "కా", "గ్ర", "త"]),
    ("ప్రయత్నం", ["ప్ర", "య", "త్నం"]),
    ("జాగ్రత్తగా", ["జా", "గ్ర", "త్త", "గా"]),
    ("వస్త్రాలు", ["వ", "స్త్రా", "లు"]),
    ("విగ్రహాన్ని", ["వి", "గ్ర", "హా", "న్ని"]),
    ("ఎక్కడికెళ్తే", ["ఎ", "క్క", "డి", "కె", "ళ్తే"]),
    ("అర్ధమయ్యింది", ["అ", "ర్ధ", "మ", "య్యిం", "ది"]),
    ("సుందరవనంలో", ["సుం", "ద", "ర", "వ", "నం", "లో"]),
    ("జంతువులకు", ["జం", "తు", "వు", "ల", "కు"]),
    ("ఆహారం", ["ఆ", "హా", "రం"]),
    ("దూరం", ["దూ", "రం"]),
    ("ఓ", ["ఓ"]),
    ("ఆకలితో", ["ఆ", "క", "లి", "తో"]),
    ("ఒకసారి", ["ఒ", "క", "సా", "రి"]),
    ("అదుగో", ["అ", "దు", "గో"]),
    ("ఇంత", ["ఇం", "త"]),
    ("గొర్రెలన్నీ", ["గొ", "ర్రె", "ల", "న్నీ"]),
    ("మమ్మల్ని", ["మ", "మ్మ", "ల్ని"]),
    ("అన్నిటికన్నా", ["అ", "న్ని", "టి", "క", "న్నా"]),
    ("దాంతో", ["దాం", "తో"]),
    ("రెండు", ["రెం", "డు"]),
    ("పుస్తకం", ["పు", "స్త", "కం"]),
    ("క్షమ", ["క్ష", "మ"]),
    ("ఐదు", ["ఐ", "దు"]),
    ("గౌరవం", ["గౌ", "ర", "వం"]),
]

for (word, expected) in segmented {
    expect(Syllables.split(word), expected, "split \(word)")
}
// Punctuation and Latin around a word are dropped; ZWNJ blocks the conjunct.
expect(Syllables.split("'నక్క.."), ["న", "క్క"], "split strips punctuation")
expect(Syllables.split("న్\u{200C}న"), ["న్", "న"], "split honours ZWNJ")
expect(Syllables.split(""), [], "split empty")

// MARK: Skills per syllable

expect(Syllables.skills(of: "క"), ["క"], "skills bare consonant")
expect(Syllables.skills(of: "కా"), ["క", "gunintha:ఆ"], "skills sign")
expect(Syllables.skills(of: "కం"), ["క", "gunintha:అం"], "skills anusvara after consonant")
expect(Syllables.skills(of: "అం"), ["అ", "అం"], "skills anusvara after vowel")
expect(Syllables.skills(of: "స్తు"), ["స", "vatthu:త", "gunintha:ఉ"], "skills conjunct + sign")
expect(Syllables.skills(of: "ర్థం"), ["ర", "vatthu:థ", "gunintha:అం"], "skills ర cluster")
expect(Syllables.skills(of: "క్ష"), ["క", "vatthu:ష"], "skills క్ష")
expect(Syllables.skills(of: "స్త్రా"), ["స", "vatthu:త", "vatthu:ర", "gunintha:ఆ"], "skills triple cluster")
expect(Syllables.skills(of: "ఐ"), ["ఐ"], "skills vowel")
expect(Syllables.skills(of: "గౌ"), ["గ", "gunintha:ఔ"], "skills au sign")
expect(Syllables.skills(ofWord: "విశ్రాంతి"),
       ["వ", "gunintha:ఇ", "శ", "vatthu:ర", "gunintha:ఆ", "gunintha:అం", "త"],
       "skills of word, deduped in order")

// MARK: Kinds

expect(Syllables.kind(of: "అ"), .vowel, "kind vowel")
expect(Syllables.kind(of: "ఆం"), .vowel, "kind vowel + anusvara")
expect(Syllables.kind(of: "క"), .consonant, "kind consonant")
expect(Syllables.kind(of: "కి"), .sign, "kind sign")
expect(Syllables.kind(of: "కం"), .sign, "kind anusvara")
expect(Syllables.kind(of: "క్క"), .conjunct, "kind conjunct")

// MARK: Readability

expect(Syllables.isReadable("అమ్మ", known: ["అ", "మ", "vatthu:మ"]), true, "readable అమ్మ")
expect(Syllables.isReadable("అమ్మ", known: ["అ", "మ"]), false, "అమ్మ needs the మ vatthu")
expect(Syllables.isReadable("కాక", known: ["క", "gunintha:ఆ"]), true, "readable కాక")
expect(Syllables.isReadable("కాకి", known: ["క", "gunintha:ఆ"]), false, "కాకి needs the gudi sign")

print(failures == 0 ? "All \(checks) checks passed." : "\(failures) of \(checks) checks FAILED.")
exit(failures == 0 ? 0 : 1)
