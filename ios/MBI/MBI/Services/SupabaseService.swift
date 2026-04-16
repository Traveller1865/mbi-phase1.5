// ios/MBI/Services/SupabaseService.swift
// MBI Phase 1 — Supabase Client & API Layer

import Foundation

struct AuthSession: Codable {
    let accessToken: String
    let userId: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
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
        guard let accessToken = data["access_token"] as? String,
              let userDict = data["user"] as? [String: Any],
              let userId = userDict["id"] as? String
        else { throw MBIError.authFailed("Sign up response malformed") }
        let sess = AuthSession(accessToken: accessToken, userId: userId)
        self.session = sess
        try await createUserRow(userId: userId, email: email)
        return sess
    }

    func signIn(email: String, password: String) async throws -> AuthSession {
        let body: [String: Any] = ["email": email, "password": password]
        let data = try await post(path: "/auth/v1/token?grant_type=password", body: body, auth: false)
        guard let accessToken = data["access_token"] as? String,
              let userDict = data["user"] as? [String: Any],
              let userId = userDict["id"] as? String
        else { throw MBIError.authFailed("Sign in response malformed") }
        let sess = AuthSession(accessToken: accessToken, userId: userId)
        self.session = sess
        try await loadCurrentUser(userId: userId)
        return sess
    }

    func signOut() {
        self.session = nil
        self.currentUser = nil
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
        var body: [String: Any] = ["score_id": scoreId, "user_id": userId, "date": date, "felt_accurate": feltAccurate]
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
