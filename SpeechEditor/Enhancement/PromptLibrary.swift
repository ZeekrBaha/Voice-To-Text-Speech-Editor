enum PromptLibrary {
    static func clean(text: String, vocabulary: [String]) -> String {
        let vocab = vocabulary.isEmpty ? "" :
            "\nKnown proper nouns to spell correctly: \(vocabulary.joined(separator: ", "))."
        return """
        You clean up dictated speech. Fix filler words, punctuation, and capitalization. \
        Do NOT add new content or change meaning. Return only the cleaned text.\(vocab)

        Text: \(text)
        """
    }

    static func action(_ action: EditorAction, text: String) -> String {
        let instruction: String
        switch action {
        case .rewrite:     instruction = "Rewrite the text to be clearer and more concise, preserving meaning."
        case .summarize:   instruction = "Summarize the text in a few sentences."
        case .changeTone:  instruction = "Rewrite the text in a professional, friendly tone."
        case .translate:   instruction = "Translate the text to Spanish."
        case .fixGrammar:  instruction = "Fix grammar and spelling only; keep wording otherwise identical."
        }
        return "\(instruction) Return only the result.\n\nText: \(text)"
    }
}
