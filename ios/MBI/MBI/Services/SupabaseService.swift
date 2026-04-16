// ios/MBI/MBI/Services/SupabaseService.swift
// MBI Phase 1.5 — Supabase Client & API Layer

import Foundation
import Security

struct AuthSession: Codable {
    let accessToken: String
    let refreshToken: String
    let userId: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case userId = "user_id"
    }
}

@MainActor
class SupabaseService: ObservableObject {
    static let shared = SupabaseService()

    @Published var session: AuthSession?
    @Published var currentUser: MBIUser?

    private var accessToken: String? { session?.accessToken }

    // MARK: - Auth

    func signUp(email: String, password: String) async throws -> AuthSession {
        let body: [String: Any] = ["email": email, "password": password]
        let data = try await post(path: "/auth/v1/signup", body: body, auth: false)
        let sess = try parseAuthSession(from: data)
        self.session = sess
        saveSession(sess)
        try await createUserRow(userId: sess.userId, email: email)
        return sess
    }

    func signIn(email: String, password: String) async throws -> AuthSession {
        let body: [String: Any] = ["email": email, "password": password]
        let data = try await post(path: "/auth/v1/token?grant_type=password", body: body, auth: false)
        let sess = try parseAuthSession(from: data)
        self.session = sess
        saveSession(sess)
        try await loadCurrentUser(userId: sess.userId)
        return sess
    }

    func signOut() {
        clearSavedSession()
    }

    // MARK: - Session Refresh

    /// Call this on cold launch before any authenticated request.
    /// Reads stored refresh token, exchanges it for a new access + refresh token pair.
    func refreshSessionIfNeeded() async {
        guard let stored = loadSavedSession() else {
            // No stored session — user needs to sign in
            return
        }

        // Try to refresh using the stored refresh token
        let body: [String: Any] = ["refresh_token": stored.refreshToken]
        do {
            let data = try await post(
                path: "/auth/v1/token?grant_type=refresh_token",
                body: body,
                auth: false
            )
            let newSession = try parseAuthSession(from: data)
            self.session = newSession
            saveSession(newSession)
            try await loadCurrentUser(userId: newSession.userId)
        } catch {
            // Refresh token expired or invalid — clear session, force sign in
            clearSavedSession()
        }
    }

    // MARK: - Auth Response Parser

    private func parseAuthSession(from data: [String: Any]) throws -> AuthSession {
        guard
            let accessToken = data["access_token"] as? String,
            let refreshToken = data["refresh_token"] as? String,
            let userDict = data["user"] as? [String: Any],
            let userId = userDict["id"] as? String
        else {
            throw MBIError.authFailed("Auth response malformed — missing tokens or user id")
        }
        return AuthSession(
            accessToken: accessToken,
            refreshToken: refreshToken,
            userId: userId
        )
    }

    // MARK: - User Profile

    func createUserRow(userId: String, email: String) async throws {
        let body: [String: Any] = [
            "id": userId,
            "email": email,
            "step_goal": Config.defaultStepGoal,
            "onboarding_complete": false,
        ]
        try await postToTable(table: "users", body: body)
    }

    func updateUser(userId: String, displayName: String, stepGoal: Int) async throws {
        let url = URL(string: "\(Config.supabaseURL)/rest/v1/users?id=eq.\(userId)")!
        let body: [String: Any] = ["display_name": displayName, "step_goal": stepGoal]
        try await patchRequest(url: url, body: body)
        try await loadCurrentUser(userId: userId)
    }

    func markOnboardingComplete(userId: String) async throws {
        let url = URL(string: "\(Config.supabaseURL)/rest/v1/users?id=eq.\(userId)")!
        try await patchRequest(url: url, body: ["onboarding_complete": true])
    }

    @discardableResult
    func loadCurrentUser(userId: String) async throws -> MBIUser {
        let url = URL(string: "\(Config.supabaseURL)/rest/v1/users?id=eq.\(userId)&select=*")!
        let data = try await getRequest(url: url)
        guard let users = data as? [[String: Any]], let first = users.first else {
            throw MBIError.notFound("User not found")
        }
        let user = try decode(MBIUser.self, from: first)
        self.currentUser = user
        return user
    }

    // MARK: - Dashboard

    func fetchTodayDashboard(userId: String) async throws -> DashboardData? {
        let today = todayString()
        let scoreURL = URL(string: "\(Config.supabaseURL)/rest/v1/daily_scores?user_id=eq.\(userId)&date=eq.\(today)&select=*")!
        let scoreData = try await getRequest(url: scoreURL)
        guard let scores = scoreData as? [[String: Any]], let first = scores.first else { return nil }
        let score = try decode(DailyScore.self, from: first)

        let explURL = URL(string: "\(Config.supabaseURL)/rest/v1/explanations?user_id=eq.\(userId)&date=eq.\(today)&select=*")!
        let explData = try await getRequest(url: explURL)
        var explanation: Explanation?
        if let expls = explData as? [[String: Any]], let firstExpl = expls.first {
            explanation = try? decode(Explanation.self, from: firstExpl)
        }

        let trendURL = URL(string: "\(Config.supabaseURL)/rest/v1/daily_scores?user_id=eq.\(userId)&select=chronos_score,date&order=date.desc&limit=7")!
        let trendData = try await getRequest(url: trendURL)
        let recentScores = ((trendData as? [[String: Any]]) ?? [])
            .compactMap { $0["chronos_score"] as? Double }
            .reversed()
            .map { $0 }

        return DashboardData(score: score, explanation: explanation, recentScores: recentScores)
    }

    func triggerDailySync(userId: String, payload: [String: Any]) async throws {
        let today = todayString()
        _ = try await callEdgeFunction(url: Config.ingestURL, body: ["payload": payload])
        _ = try await callEdgeFunction(url: Config.scoreURL, body: ["userId": userId, "date": today])
        _ = try await callEdgeFunction(url: Config.narrateURL, body: ["userId": userId, "date": today])
    }

    // MARK: - Feedback

    func submitFeedback(scoreId: String, userId: String, date: String, feltAccurate: Bool, note: String?) async throws {
        var body: [String: Any] = [
            "score_id": scoreId,
            "user_id": userId,
            "date": date,
            "felt_accurate": feltAccurate
        ]
        if let note = note, !note.isEmpty { body["note"] = note }
        try await postToTable(table: "feedback", body: body)
    }

    // MARK: - Admin

    func fetchAdminData() async throws -> [[String: Any]] {
        let data = try await callEdgeFunction(url: Config.adminURL, body: [:])
        return (data["users"] as? [[String: Any]]) ?? []
    }

    // MARK: - HTTP Helpers

    private func post(path: String, body: [String: Any], auth: Bool) async throws -> [String: Any] {
        let url = URL(string: "\(Config.supabaseURL)\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        if auth, let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        try checkHTTPStatus(response)
        return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    private func postToTable(table: String, body: [String: Any]) async throws {
        let url = URL(string: "\(Config.supabaseURL)/rest/v1/\(table)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        if let token = accessToken { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, response) = try await URLSession.shared.data(for: request)
        try checkHTTPStatus(response)
    }

    private func patchRequest(url: URL, body: [String: Any]) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        if let token = accessToken { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, response) = try await URLSession.shared.data(for: request)
        try checkHTTPStatus(response)
    }

    private func getRequest(url: URL) async throws -> Any {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        if let token = accessToken { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let (data, response) = try await URLSession.shared.data(for: request)
        try checkHTTPStatus(response)
        return try JSONSerialization.jsonObject(with: data)
    }

    @discardableResult
    private func callEdgeFunction(url: URL, body: [String: Any]) async throws -> [String: Any] {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        if let token = accessToken { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        try checkHTTPStatus(response)
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    private func checkHTTPStatus(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        if http.statusCode >= 400 { throw MBIError.httpError(http.statusCode) }
    }

    private func decode<T: Codable>(_ type: T.Type, from dict: [String: Any]) throws -> T {
        let data = try JSONSerialization.data(withJSONObject: dict)
        return try JSONDecoder().decode(type, from: data)
    }

    func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

enum MBIError: Error, LocalizedError {
    case authFailed(String)
    case notFound(String)
    case httpError(Int)
    case syncFailed(String)

    var errorDescription: String? {
        switch self {
        case .authFailed(let msg): return "Auth failed: \(msg)"
        case .notFound(let msg): return msg
        case .httpError(let code): return "HTTP error \(code)"
        case .syncFailed(let msg): return "Sync failed: \(msg)"
        }
    }
}

// MARK: - Keychain Session Persistence
extension SupabaseService {
    private static let keychainService = "com.mbi.chronos"
    private static let keychainAccount = "mbi_session"

    func saveSession(_ session: AuthSession) {
        guard let data = try? JSONEncoder().encode(session) else { return }

        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: Self.keychainAccount
        ]

        // Delete any existing entry first
        SecItemDelete(query as CFDictionary)

        // Add new entry
        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        SecItemAdd(attributes as CFDictionary, nil)
    }

    @discardableResult
    func loadSavedSession() -> AuthSession? {
        let query: [String: Any] = [
            kSecClass as String:            kSecClassGenericPassword,
            kSecAttrService as String:      Self.keychainService,
            kSecAttrAccount as String:      Self.keychainAccount,
            kSecReturnData as String:       true,
            kSecMatchLimit as String:       kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let session = try? JSONDecoder().decode(AuthSession.self, from: data)
        else { return nil }

        return session
    }

    func clearSavedSession() {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: Self.keychainAccount
        ]
        SecItemDelete(query as CFDictionary)
        self.session = nil
        self.currentUser = nil
    }
}
