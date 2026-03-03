import Foundation

public enum LiberalDateParser {
    /// Parse a date from a string using multiple strategies.
    ///
    /// - Parameters:
    ///   - input: The text containing a date.
    ///   - reference: Used for relative dates like "tomorrow" (handled by NSDataDetector).
    ///   - timeZone: Preferred timezone for formats that don’t include one.
    ///   - locale: Preferred locale for month/day names. Use en_US_POSIX for stable parsing.
    /// - Returns: A Date if anything matches.
    public static func parse(
        _ input: String,
        reference: Date = Date(),
        timeZone: TimeZone = .current,
        locale: Locale = Locale(identifier: "en_US_POSIX")
    ) -> Date? {
        let s = normalize(input)
        guard !s.isEmpty else { return nil }

        // 1) ISO 8601 variants
        if let d = parseISO8601(s) { return d }

        // 2) NSDataDetector date extraction (very liberal; can find dates inside text)
        if let d = detectDate(in: s, reference: reference) { return d }

        // 3) Try explicit formats
        if let d = parseWithFormatters(s, timeZone: timeZone, locale: locale) { return d }

        // 4) Heuristic for numeric ambiguous formats (mm/dd vs dd/mm)
        if let d = parseAmbiguousNumeric(s, timeZone: timeZone, locale: locale) { return d }

        return nil
    }

    // MARK: - Strategy 1: ISO 8601

    private static func parseISO8601(_ s: String) -> Date? {
        // Try ISO8601DateFormatter with different options.
        let iso = ISO8601DateFormatter()

        // Common variants (with/without fractional seconds).
        let optionSets: [ISO8601DateFormatter.Options] = [
            [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime, .withTimeZone],
            [.withInternetDateTime, .withFractionalSeconds, .withDashSeparatorInDate, .withColonSeparatorInTime, .withTimeZone],
            [.withFullDate, .withDashSeparatorInDate],
            [.withFullTime, .withColonSeparatorInTime, .withTimeZone],
            [.withWeekOfYear, .withDashSeparatorInDate, .withTimeZone],
        ]

        for opts in optionSets {
            iso.formatOptions = opts
            if let d = iso.date(from: s) { return d }
        }

        // Also handle "2026-02-16 12:34:56Z" (space instead of T)
        if s.contains(" "), s.contains("-"), s.contains(":") {
            let t = s.replacingOccurrences(of: " ", with: "T")
            for opts in optionSets {
                iso.formatOptions = opts
                if let d = iso.date(from: t) { return d }
            }
        }

        return nil
    }

    // MARK: - Strategy 2: NSDataDetector

    private static func detectDate(in s: String, reference: Date) -> Date? {
        // NSDataDetector can match "Feb 16, 2026", "tomorrow", and dates embedded in text.
        // It may return multiple matches; we take the first.
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else {
            return nil
        }
        let range = NSRange(s.startIndex..<s.endIndex, in: s)
        let matches = detector.matches(in: s, options: [], range: range)

        // Prefer exact matches that cover most of the string; otherwise take first.
        let sorted = matches.sorted { a, b in
            a.range.length > b.range.length
        }

        for m in sorted {
            if let d = m.date { return d }
            // Some date results can include a time interval.
            if let tz = m.timeZone, let d = m.date {
                // Rarely needed; date already incorporates it. Keep for completeness.
                _ = tz
                return d
            }
            // Relative dates may be provided via duration:
            if m.duration > 0 {
                return reference.addingTimeInterval(m.duration)
            }
        }
        return nil
    }

    // MARK: - Strategy 3: Many DateFormatter patterns

    private static func parseWithFormatters(_ s: String, timeZone: TimeZone, locale: Locale) -> Date? {
        // Note: DateFormatter is expensive; cache if you call this a lot.
        // We’ll build a list of formatters and try them in order.
        let formats: [String] = [
            // Named months
            "MMM d, yyyy",
            "MMMM d, yyyy",
            "d MMM yyyy",
            "d MMMM yyyy",
            "EEE, MMM d, yyyy",
            "EEE, d MMM yyyy",
            "EEE, MMM d yyyy",
            "MMM d yyyy",
            "MMMM d yyyy",

            // With time
            "MMM d, yyyy h:mm a",
            "MMM d, yyyy h:mm:ss a",
            "MMMM d, yyyy h:mm a",
            "MMMM d, yyyy h:mm:ss a",
            "d MMM yyyy HH:mm",
            "d MMM yyyy HH:mm:ss",
            "yyyy-MM-dd HH:mm",
            "yyyy-MM-dd HH:mm:ss",

            // RFC 2822-ish / email dates
            "EEE, d MMM yyyy HH:mm:ss Z",
            "EEE, d MMM yyyy HH:mm Z",
            "d MMM yyyy HH:mm:ss Z",
            "d MMM yyyy HH:mm Z",

            // Compact / numeric
            "yyyyMMdd",
            "yyyy/MM/dd",
            "MM/dd/yyyy",
            "M/d/yyyy",
            "dd/MM/yyyy",
            "d/M/yyyy",
            "MM-dd-yyyy",
            "dd-MM-yyyy",

            // With timezone
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
        ]

        for f in formats {
            let df = DateFormatter()
            df.locale = locale
            df.timeZone = timeZone
            df.isLenient = true
            df.dateFormat = f
            if let d = df.date(from: s) { return d }
        }
        return nil
    }

    // MARK: - Strategy 4: Heuristic for ambiguous numeric dates

    private static func parseAmbiguousNumeric(_ s: String, timeZone: TimeZone, locale: Locale) -> Date? {
        // Handle: 02/03/2026 could be Feb 3 or Mar 2.
        // Heuristic: if first component > 12 => it must be day/month.
        // If second > 12 => it must be month/day.
        // Otherwise try both, preferring month/day (US default) unless locale suggests otherwise.
        let separators = CharacterSet(charactersIn: "/-")
        let parts = s.split(whereSeparator: { String($0).rangeOfCharacter(from: separators) != nil })
        guard parts.count >= 3 else { return nil }

        func toInt(_ p: Substring) -> Int? { Int(p.trimmingCharacters(in: .whitespaces)) }
        guard let a = toInt(parts[0]), let b = toInt(parts[1]) else { return nil }

        // Only attempt if looks like purely numeric YMD/MDY/DMY
        if parts.prefix(3).contains(where: { Int($0.trimmingCharacters(in: .whitespaces)) == nil }) {
            return nil
        }

        let preferDMY = locale.identifier.lowercased().contains("gb")
            || locale.identifier.lowercased().contains("fr")
            || locale.identifier.lowercased().contains("de")

        let candidates: [String]
        if a > 12 {
            candidates = ["d/M/yyyy", "d/M/yy", "dd/MM/yyyy", "dd/MM/yy"]
        } else if b > 12 {
            candidates = ["M/d/yyyy", "M/d/yy", "MM/dd/yyyy", "MM/dd/yy"]
        } else {
            candidates = preferDMY
                ? ["d/M/yyyy", "d/M/yy", "M/d/yyyy", "M/d/yy"]
                : ["M/d/yyyy", "M/d/yy", "d/M/yyyy", "d/M/yy"]
        }

        for f in candidates {
            let df = DateFormatter()
            df.locale = locale
            df.timeZone = timeZone
            df.isLenient = true
            df.dateFormat = f
            if let d = df.date(from: s) { return d }
        }
        return nil
    }

    // MARK: - Normalization

    private static func normalize(_ input: String) -> String {
        var s = input.trimmingCharacters(in: .whitespacesAndNewlines)

        // Collapse multiple spaces
        s = s.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)

        // Normalize common unicode punctuation
        s = s.replacingOccurrences(of: "–", with: "-")
        s = s.replacingOccurrences(of: "—", with: "-")
        s = s.replacingOccurrences(of: "，", with: ",")

        // Remove ordinal suffixes: 1st, 2nd, 3rd, 4th...
        s = s.replacingOccurrences(
            of: #"(\d{1,2})(st|nd|rd|th)"#,
            with: "$1",
            options: .regularExpression
        )

        return s
    }
}
