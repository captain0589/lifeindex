import Foundation
import SwiftUI

// MARK: - Chat Message Model

struct ChatMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let content: String
    let isUser: Bool
    let timestamp: Date
    var isTyping: Bool = false

    init(id: UUID = UUID(), content: String, isUser: Bool, timestamp: Date = Date(), isTyping: Bool = false) {
        self.id = id
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
        self.isTyping = isTyping
    }

    enum CodingKeys: String, CodingKey {
        case id, content, isUser, timestamp
    }
}

// MARK: - Chat Session Model

struct ChatSession: Identifiable, Codable {
    let id: UUID
    let startDate: Date
    var messages: [ChatMessage]
    var title: String

    init(id: UUID = UUID(), startDate: Date = Date(), messages: [ChatMessage] = [], title: String = "") {
        self.id = id
        self.startDate = startDate
        self.messages = messages
        self.title = title
    }

    var displayTitle: String {
        if !title.isEmpty {
            return title
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: startDate)
    }
}

// MARK: - Suggested Question

struct SuggestedQuestion: Identifiable {
    let id = UUID()
    let icon: String
    let text: String
    let category: QuestionCategory

    enum QuestionCategory {
        case sleep
        case activity
        case heart
        case recovery
        case general

        var color: Color {
            switch self {
            case .sleep: return Theme.sleep
            case .activity: return Theme.steps
            case .heart: return Theme.heartRate
            case .recovery: return Theme.recovery
            case .general: return Theme.accentColor
            }
        }
    }
}

// MARK: - Chat Persistence

class ChatPersistence {
    static let shared = ChatPersistence()

    private let sessionsKey = "chat_sessions"
    private let maxSessions = 50

    private init() {}

    func saveSessions(_ sessions: [ChatSession]) {
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: sessionsKey)
        }
    }

    func loadSessions() -> [ChatSession] {
        guard let data = UserDefaults.standard.data(forKey: sessionsKey),
              let sessions = try? JSONDecoder().decode([ChatSession].self, from: data) else {
            return []
        }
        return sessions
    }

    func saveSession(_ session: ChatSession) {
        var sessions = loadSessions()
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        } else {
            sessions.insert(session, at: 0)
        }
        // Keep only recent sessions
        if sessions.count > maxSessions {
            sessions = Array(sessions.prefix(maxSessions))
        }
        saveSessions(sessions)
    }

    func deleteSession(_ sessionId: UUID) {
        var sessions = loadSessions()
        sessions.removeAll { $0.id == sessionId }
        saveSessions(sessions)
    }

    func clearAllSessions() {
        UserDefaults.standard.removeObject(forKey: sessionsKey)
    }
}
