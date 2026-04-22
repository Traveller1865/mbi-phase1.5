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

    func refreshSessionIfNeeded() async {
        guard let stored = loadSavedSession() else { return }
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
        let score: DailyScore
        do {
            score = try decode(DailyScore.self, from: first)
        } catch {
            print("[fetchMostRecentDashboard] decode failed: \(error)")
            throw error
        }

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
    
    func fetchMostRecentDashboard(userId: String) async throws -> DashboardData? {
        let scoreURL = URL(string: "\(Config.supabaseURL)/rest/v1/daily_scores?user_id=eq.\(userId)&select=*&order=date.desc&limit=1")!
        let scoreData = try await getRequest(url: scoreURL)
        guard let scores = scoreData as? [[String: Any]], let first = scores.first else { return nil }
        let score = try decode(DailyScore.self, from: first)
        let date = score.date

        let explURL = URL(string: "\(Config.supabaseURL)/rest/v1/explanations?user_id=eq.\(userId)&date=eq.\(date)&select=*")!
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
    
    func fetchTrendData(userId: String) async throws -> [TrendPoint] {
        let url = URL(string: "\(Config.supabaseURL)/rest/v1/daily_scores?user_id=eq.\(userId)&select=chronos_score,date&order=date.desc&limit=7")!
        let data = try await getRequest(url: url)
        let rows = (data as? [[String: Any]]) ?? []
        return rows.compactMap { row -> TrendPoint? in
            guard let date = row["date"] as? String,
                  let score = row["chronos_score"] as? Double else { return nil }
            return TrendPoint(date: date, score: score)
        }.reversed()
    }

    func triggerDailySync(userId: String, payload: [String: Any]) async throws {
        // Extract the date from the payload so score/narrate use the same date as ingest
        guard let payloadDate = (payload["metrics"] as? [String: Any]).flatMap({ _ in payload["date"] as? String })
                    ?? (payload["date"] as? String) else {
            throw MBIError.syncFailed("Payload missing date")
        }

        _ = try await callEdgeFunction(url: Config.ingestURL, body: ["payload": payload])
        _ = try await callEdgeFunction(url: Config.scoreURL, body: ["userId": userId, "date": payloadDate])
        _ = try await callEdgeFunction(url: Config.narrateURL, body: [
            "userId": userId,
            "date": payloadDate,
            "timeOfDay": TimeOfDay.current.rawValue   // E-09: morning | daytime | evening
        ])
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
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
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
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, response) = try await URLSession.shared.data(for: request)
        try checkHTTPStatus(response)
    }

    private func getRequest(url: URL) async throws -> Any {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
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
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
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

// MARK: - Session Persistence (Keychain + UserDefaults fallback)
extension SupabaseService {
    private static let keychainService = "com.mbi.chronos"
    private static let keychainAccount = "mbi_session"
    private static let udKey = "mbi_session_v2"
    
    func saveSession(_ session: AuthSession) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        
        // Try Keychain
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: Self.keychainAccount
        ]
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(attributes as CFDictionary, nil)
        
        if status != errSecSuccess {
            print("[MBI] Keychain write failed (\(status)), using UserDefaults fallback")
        }
        
        // Always write UserDefaults as fallback
        UserDefaults.standard.set(data, forKey: Self.udKey)
    }
    
    @discardableResult
    func loadSavedSession() -> AuthSession? {
        // Try Keychain first
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: Self.keychainAccount,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess,
           let data = result as? Data,
           let session = try? JSONDecoder().decode(AuthSession.self, from: data) {
            print("[MBI] Session loaded from Keychain")
            return session
        }
        
        // Fall back to UserDefaults
        if let data = UserDefaults.standard.data(forKey: Self.udKey),
           let session = try? JSONDecoder().decode(AuthSession.self, from: data) {
            print("[MBI] Session loaded from UserDefaults fallback")
            return session
        }
        
        print("[MBI] No stored session found")
        return nil
    }
    
    func clearSavedSession() {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: Self.keychainAccount
        ]
        SecItemDelete(query as CFDictionary)
        UserDefaults.standard.removeObject(forKey: Self.udKey)
        self.session = nil
        self.currentUser = nil
    }
    
    // MARK: - Baselines (for Trend deviation callouts — R-02)
    
    func fetchLatestBaselines(userId: String) async throws -> [String: Double] {
        let url = URL(string: "\(Config.supabaseURL)/rest/v1/baselines?user_id=eq.\(userId)&order=computed_at.desc&limit=1&select=*")!
        let data = try await getRequest(url: url)
        guard let rows = data as? [[String: Any]], let row = rows.first else { return [:] }
        
        // Extract all metric baseline keys — any Double value not a metadata field
        let skip = Set(["id", "user_id", "computed_at", "days_used", "created_at"])
        var result: [String: Double] = [:]
        for (key, val) in row {
            guard !skip.contains(key), let v = val as? Double else { continue }
            result[key] = v
        }
        return result
    }
    
    // MARK: - Driver Streak (for contextual education trigger — E-11)

        func fetchDriverStreak(userId: String, todayDriver: String) async throws -> Int {
            let url = URL(string: "\(Config.supabaseURL)/rest/v1/daily_scores?user_id=eq.\(userId)&select=driver_1,date&order=date.desc&limit=10")!
            let data = try await getRequest(url: url)
            guard let rows = data as? [[String: Any]] else { return 0 }

            var streak = 0
            for row in rows {
                guard let d1 = row["driver_1"] as? String else { break }
                if d1 == todayDriver { streak += 1 } else { break }
            }
            return streak
        }

        // MARK: - D5 History (for Allostatic Portrait — E-11)

        func fetchAllostaticHistory(userId: String) async throws -> [(date: String, value: Double)] {
            let url = URL(string: "\(Config.supabaseURL)/rest/v1/daily_scores?user_id=eq.\(userId)&d5_allostatic=not.is.null&select=date,d5_allostatic&order=date.asc&limit=90")!
            let data = try await getRequest(url: url)
            guard let rows = data as? [[String: Any]] else { return [] }
            return rows.compactMap { row in
                guard let date = row["date"] as? String,
                      let val = row["d5_allostatic"] as? Double else { return nil }
                return (date: date, value: val)
            }
        }
}
