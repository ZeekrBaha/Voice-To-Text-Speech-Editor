import os

enum Log {
    static let pipeline = Logger(subsystem: "com.baha.speecheditor", category: "pipeline")
    static let audio = Logger(subsystem: "com.baha.speecheditor", category: "audio")
    static let ai = Logger(subsystem: "com.baha.speecheditor", category: "ai")
}
