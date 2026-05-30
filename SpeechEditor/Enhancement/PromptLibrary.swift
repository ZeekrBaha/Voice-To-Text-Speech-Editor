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

    static func action(_ action: EditorAction, text: String,
                       translationLanguage: String = "Spanish") -> String {
        let instruction: String
        switch action {
        case .rewrite:        instruction = "Rewrite the text to be clearer and more concise, preserving meaning."
        case .summarize:      instruction = "Summarize the text in a few sentences."
        case .changeTone:     instruction = "Rewrite the text in a professional, friendly tone."
        case .translate:      instruction = "Translate the text to \(translationLanguage)."
        case .fixGrammar:     instruction = "Fix grammar and spelling only; keep wording otherwise identical."
        case .emailReply:     instruction = "Turn the text into a polite, well-structured email reply."
        case .cleanUpMessage: instruction = "Rewrite the text as a concise, friendly chat message suitable for Slack."
        case .meetingNotes:   instruction = "Reformat the text into clear meeting notes with bullet points and any action items."
        }
        return "\(instruction) Return only the result.\n\nText: \(text)"
    }
}
