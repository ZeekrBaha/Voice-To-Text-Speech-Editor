enum EditorAction: CaseIterable, Equatable, Hashable {
    case rewrite, summarize, changeTone, translate, fixGrammar
    case emailReply, cleanUpMessage, meetingNotes

    var title: String {
        switch self {
        case .rewrite: return "Rewrite"
        case .summarize: return "Summarize"
        case .changeTone: return "Change Tone"
        case .translate: return "Translate"
        case .fixGrammar: return "Fix Grammar"
        case .emailReply: return "Email Reply"
        case .cleanUpMessage: return "Clean Up Message"
        case .meetingNotes: return "Meeting Notes"
        }
    }

    var systemImage: String {
        switch self {
        case .rewrite: return "pencil.line"
        case .summarize: return "list.bullet.rectangle"
        case .changeTone: return "theatermasks"
        case .translate: return "globe"
        case .fixGrammar: return "textformat.abc"
        case .emailReply: return "envelope"
        case .cleanUpMessage: return "bubble.left.and.bubble.right"
        case .meetingNotes: return "doc.text"
        }
    }

    /// Primary actions get their own toolbar buttons; the rest live in a "More" menu.
    var isPrimary: Bool {
        switch self {
        case .rewrite, .summarize, .fixGrammar, .translate: return true
        case .changeTone, .emailReply, .cleanUpMessage, .meetingNotes: return false
        }
    }
}

protocol TextEnhancer {
    func clean(_ text: String, vocabulary: [String]) async throws -> String
    func apply(_ action: EditorAction, to text: String) async throws -> String
}
