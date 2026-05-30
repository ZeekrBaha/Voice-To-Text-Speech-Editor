enum EditorAction: CaseIterable, Equatable, Hashable {
    case rewrite, summarize, changeTone, translate, fixGrammar
    var title: String {
        switch self {
        case .rewrite: return "Rewrite"
        case .summarize: return "Summarize"
        case .changeTone: return "Change Tone"
        case .translate: return "Translate"
        case .fixGrammar: return "Fix Grammar"
        }
    }
}

protocol TextEnhancer {
    func clean(_ text: String, vocabulary: [String]) async throws -> String
    func apply(_ action: EditorAction, to text: String) async throws -> String
}
