//
//  RegexKit.swift
//  Finlogue
//
//  Thin NSRegularExpression wrapper. Used instead of Swift's `Regex` literals
//  because the project builds in Swift 5 language mode, where bare-slash regex
//  literals are not enabled.
//

import Foundation

enum RegexKit {
    /// Compiled patterns are reused — the SMS pipeline evaluates dozens of
    /// patterns per message and recompiling each time is wasteful.
    private static var cache: [String: NSRegularExpression] = [:]
    private static let lock = NSLock()

    private static func expression(_ pattern: String) -> NSRegularExpression? {
        lock.lock()
        defer { lock.unlock() }
        if let cached = cache[pattern] { return cached }
        guard let expression = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive]
        ) else { return nil }
        cache[pattern] = expression
        return expression
    }

    static func matches(_ pattern: String, in text: String) -> Bool {
        guard let expression = expression(pattern) else { return false }
        let range = NSRange(text.startIndex..., in: text)
        return expression.firstMatch(in: text, range: range) != nil
    }

    /// Returns the capture groups of the first match, index 0 being the whole
    /// match. Groups that did not participate come back as `nil`.
    static func firstMatch(_ pattern: String, in text: String) -> [String?]? {
        guard let expression = expression(pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = expression.firstMatch(in: text, range: range) else { return nil }
        return (0..<match.numberOfRanges).map { index in
            let groupRange = match.range(at: index)
            guard groupRange.location != NSNotFound,
                  let swiftRange = Range(groupRange, in: text)
            else { return nil }
            return String(text[swiftRange])
        }
    }

    /// First capture group of the first matching pattern in `patterns`.
    static func firstCapture(of patterns: [String], in text: String) -> String? {
        for pattern in patterns {
            if let groups = firstMatch(pattern, in: text), groups.count > 1,
               let capture = groups[1], !capture.isEmpty {
                return capture
            }
        }
        return nil
    }
}
