import SwiftUI

enum MessageKind: String, CaseIterable, CustomStringConvertible {
    case markdown
    case note
    case bookmark

    init?(_ contentType: String) {
        switch contentType {
        case "text/markdown": self = .markdown
        case "text/x-note": self = .note
        case "multipart/x-bookmark": self = .bookmark
        default: return nil
        }
    }

    var description: String {
        switch self {
        case .markdown: "Markdown"
        case .note: "Note"
        case .bookmark: "Bookmark"
        }
    }

    var contentType: String {
        switch self {
        case .markdown: "text/markdown"
        case .note: "text/x-note"
        case .bookmark: "multipart/x-bookmark"
        }
    }

    var isMultipart: Bool {
        contentType.hasPrefix("multipart")
    }
}

enum PartKind: String, CaseIterable, CustomStringConvertible {
    case book
    case bookProgress
    case review
    case link
    case note

    init?(contentType: String) {
        switch contentType {
        case "text/x-book": self = .book
        case "text/x-book-progress": self = .bookProgress
        case "text/x-review": self = .review
        case "text/x-link": self = .link
        case "text/x-note": self = .note
        default: return nil
        }
    }

    var description: String {
        switch self {
        case .book: "Book"
        case .bookProgress: "Book Progress"
        case .review: "Review"
        case .link: "Link"
        case .note: "Note"
        }
    }

    var contentType: String {
        switch self {
        case .book: "text/x-book"
        case .bookProgress: "text/x-book-progress"
        case .review: "text/x-review"
        case .link: "text/x-link"
        case .note: "text/x-note"
        }
    }

    var headerFields: [PartField] {
        switch self {
        case .book: [.date, .bookTitle, .bookSubtitle, .bookAuthors, .bookPages]
        case .bookProgress: [.date, .bookPage, .bookPages]
        case .review: [.date, .reviewRating, .reviewSpoilers]
        case .link: [.date, .linkURL, .linkTitle]
        case .note: [.date]
        }
    }
}

enum PartField: String, CaseIterable {
    case bookTitle
    case bookSubtitle
    case bookAuthors
    case bookPages
    case bookPage

    case linkURL
    case linkTitle

    case reviewRating
    case reviewSpoilers

    case date

    var key: String {
        switch self {
        case .bookTitle: "Book-Title"
        case .bookSubtitle: "Book-Subtitle"
        case .bookAuthors: "Book-Authors"
        case .bookPages: "Book-Pages"
        case .bookPage: "Book-Page"
        case .linkURL: "Link-URL"
        case .linkTitle: "Link-Title"
        case .date: "Date"
        case .reviewRating: "Rating"
        case .reviewSpoilers: "Spoilers"
        }
    }

    var defaultValue: String {
        switch self {
        case .date: Date.now.rfc1123
        default: ""
        }
    }
}
