// Romanize a JSON array of strings with the app's own Transliterator, so the
// review page matches the reader exactly. Built together with
// Kathalu/Services/Transliterator.swift by build_review.py.
import Foundation
let input = try! JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))) as! [String]
var out: [String: String] = [:]
for s in input { out[s] = Transliterator.transliterate(s) }
FileHandle.standardOutput.write(try! JSONSerialization.data(withJSONObject: out, options: [.sortedKeys]))
