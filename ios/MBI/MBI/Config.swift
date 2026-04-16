// ios/MBI/Config.swift
import Foundation

enum Config {
    static let supabaseURL = "https://sjhysadnpswrcpmezmoc.supabase.co"
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNqaHlzYWRucHN3cmNwbWV6bW9jIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYyNzA3MjMsImV4cCI6MjA5MTg0NjcyM30.hxIavIKdeekjEioc-pbP1FU9PCX2sJ7jQUPpeNSNIxU"

    static var ingestURL: URL { URL(string: "\(supabaseURL)/functions/v1/ingest")! }
    static var scoreURL: URL { URL(string: "\(supabaseURL)/functions/v1/score")! }
    static var narrateURL: URL { URL(string: "\(supabaseURL)/functions/v1/narrate")! }
    static var adminURL: URL { URL(string: "\(supabaseURL)/functions/v1/admin")! }

    static let defaultStepGoal = 8000
    static let minHistoryDaysForScore = 3
    static let appVersion = "1.0.0"
}
