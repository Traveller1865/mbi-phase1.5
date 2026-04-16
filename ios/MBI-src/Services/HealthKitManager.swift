// ios/MBI/Services/HealthKitManager.swift
// MBI Phase 1 — HealthKit Integration
// Authorization and reads managed here only. Raw payload sent to ingestion layer.

import Foundation
import HealthKit

class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()
    private let store = HKHealthStore()

    // All 7 primary metrics + distance (supporting)
    private let readTypes: Set<HKObjectType> = {
        var types = Set<HKObjectType>()
        let quantityTypes: [HKQuantityTypeIdentifier] = [
            .heartRateVariabilitySDNN,
            .restingHeartRate,
            .respiratoryRate,
            .stepCount,
            .appleExerciseTime,
            .distanceWalkingRunning,
        ]
        for id in quantityTypes {
            if let t = HKQuantityType.quantityType(forIdentifier: id) { types.insert(t) }
        }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleep)
        }
        return types
    }()

    // ─────────────────────────────────────────
    // AUTHORIZATION
    // ─────────────────────────────────────────

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }
        try await store.requestAuthorization(toShare: [], read: readTypes)
    }

    func authorizationStatus() -> Bool {
        guard let hrv = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return false }
        return store.authorizationStatus(for: hrv) == .sharingAuthorized
    }

    // ─────────────────────────────────────────
    // 7-DAY HISTORY BOOTSTRAP
    // Returns array of RawDayMetrics, one per calendar day
    // ─────────────────────────────────────────

    func readSevenDayHistory() async throws -> [RawDayMetrics] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var results: [RawDayMetrics] = []

        for offset in 1...7 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let metrics = try await readDay(date: day)
            results.append(metrics)
        }

        return results.reversed() // oldest to newest
    }

    // ─────────────────────────────────────────
    // PRIOR DAY READ (daily sync)
    // ─────────────────────────────────────────

    func readYesterday() async throws -> RawDayMetrics {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else {
            throw HealthKitError.readFailed("Could not compute yesterday")
        }
        return try await readDay(date: yesterday)
    }

    // ─────────────────────────────────────────
    // READ ONE CALENDAR DAY
    // ─────────────────────────────────────────

    func readDay(date: Date) async throws -> RawDayMetrics {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
            throw HealthKitError.readFailed("Date range computation failed")
        }

        async let hrv = readHRV(start: start, end: end)
        async let rhr = readRestingHeartRate(start: start, end: end)
        async let rr = readRespiratoryRate(start: start, end: end)
        async let sleep = readSleep(start: start, end: end)
        async let steps = readSteps(start: start, end: end)
        async let activeMin = readActiveMinutes(start: start, end: end)
        async let distance = readDistance(start: start, end: end)

        let (hrvVal, rhrVal, rrVal, sleepData, stepsVal, activeMinVal, distanceVal) =
            try await (hrv, rhr, rr, sleep, steps, activeMin, distance)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        return RawDayMetrics(
            date: formatter.string(from: date),
            hrv_ms: hrvVal,
            resting_hr_bpm: rhrVal,
            respiratory_rate_rpm: rrVal,
            sleep_duration_hrs: sleepData?.duration,
            sleep_efficiency_pct: sleepData?.efficiency,
            steps: stepsVal,
            active_minutes: activeMinVal,
            distance_km: distanceVal
        )
    }

    // ─────────────────────────────────────────
    // INDIVIDUAL METRIC READS
    // ─────────────────────────────────────────

    private func readHRV(start: Date, end: Date) async throws -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return nil }
        return try await readLatestQuantity(type: type, start: start, end: end, unit: HKUnit.secondUnit(with: .milli))
    }

    private func readRestingHeartRate(start: Date, end: Date) async throws -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else { return nil }
        return try await readLatestQuantity(type: type, start: start, end: end, unit: HKUnit.count().unitDivided(by: .minute()))
    }

    private func readRespiratoryRate(start: Date, end: Date) async throws -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .respiratoryRate) else { return nil }
        return try await readAverageQuantity(type: type, start: start, end: end, unit: HKUnit.count().unitDivided(by: .minute()))
    }

    private func readSteps(start: Date, end: Date) async throws -> Int? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return nil }
        guard let val = try await readSumQuantity(type: type, start: start, end: end, unit: .count()) else { return nil }
        return Int(val)
    }

    private func readActiveMinutes(start: Date, end: Date) async throws -> Int? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) else { return nil }
        guard let val = try await readSumQuantity(type: type, start: start, end: end, unit: .minute()) else { return nil }
        return Int(val)
    }

    private func readDistance(start: Date, end: Date) async throws -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) else { return nil }
        guard let val = try await readSumQuantity(type: type, start: start, end: end, unit: .meterUnit(with: .kilo)) else { return nil }
        return val
    }

    private func readSleep(start: Date, end: Date) async throws -> SleepData? {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }

        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let samples = samples as? [HKCategorySample], !samples.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }

                // Calculate total sleep duration (inBed + asleep stages)
                var asleepSeconds: TimeInterval = 0
                var inBedSeconds: TimeInterval = 0

                for sample in samples {
                    let duration = sample.endDate.timeIntervalSince(sample.startDate)
                    if sample.value == HKCategoryValueSleepAnalysis.inBed.rawValue {
                        inBedSeconds += duration
                    } else {
                        // All asleep stages (core, deep, REM)
                        asleepSeconds += duration
                    }
                }

                let totalBed = max(inBedSeconds, asleepSeconds)
                let efficiency = totalBed > 0 ? (asleepSeconds / totalBed) * 100.0 : nil
                let durationHrs = asleepSeconds / 3600.0

                if durationHrs < 0.5 {
                    continuation.resume(returning: nil)
                    return
                }

                continuation.resume(returning: SleepData(
                    duration: durationHrs,
                    efficiency: efficiency
                ))
            }
            store.execute(query)
        }
    }

    // ─────────────────────────────────────────
    // HK QUERY HELPERS
    // ─────────────────────────────────────────

    private func readLatestQuantity(type: HKQuantityType, start: Date, end: Date, unit: HKUnit) async throws -> Double? {
        try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1, sortDescriptors: [sort]) { _, samples, error in
                if let error = error { continuation.resume(throwing: error); return }
                let val = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
                continuation.resume(returning: val)
            }
            store.execute(query)
        }
    }

    private func readAverageQuantity(type: HKQuantityType, start: Date, end: Date, unit: HKUnit) async throws -> Double? {
        try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error = error { continuation.resume(throwing: error); return }
                guard let samples = samples as? [HKQuantitySample], !samples.isEmpty else {
                    continuation.resume(returning: nil); return
                }
                let vals = samples.map { $0.quantity.doubleValue(for: unit) }
                continuation.resume(returning: vals.reduce(0, +) / Double(vals.count))
            }
            store.execute(query)
        }
    }

    private func readSumQuantity(type: HKQuantityType, start: Date, end: Date, unit: HKUnit) async throws -> Double? {
        try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, error in
                if let error = error { continuation.resume(throwing: error); return }
                continuation.resume(returning: stats?.sumQuantity()?.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }
}

// ─────────────────────────────────────────
// SUPPORTING TYPES
// ─────────────────────────────────────────

struct RawDayMetrics {
    let date: String
    let hrv_ms: Double?
    let resting_hr_bpm: Double?
    let respiratory_rate_rpm: Double?
    let sleep_duration_hrs: Double?
    let sleep_efficiency_pct: Double?
    let steps: Int?
    let active_minutes: Int?
    let distance_km: Double?

    func toPayloadDict(userId: String) -> [String: Any] {
        var metrics: [String: Any] = [:]
        if let v = hrv_ms { metrics["hrv_ms"] = v }
        if let v = resting_hr_bpm { metrics["resting_hr_bpm"] = v }
        if let v = respiratory_rate_rpm { metrics["respiratory_rate_rpm"] = v }
        if let v = sleep_duration_hrs { metrics["sleep_duration_hrs"] = v }
        if let v = sleep_efficiency_pct { metrics["sleep_efficiency_pct"] = v }
        if let v = steps { metrics["steps"] = v }
        if let v = active_minutes { metrics["active_minutes"] = v }
        if let v = distance_km { metrics["distance_km"] = v }
        return ["userId": userId, "date": date, "metrics": metrics]
    }
}

struct SleepData {
    let duration: Double   // hours
    let efficiency: Double? // 0–100
}

enum HealthKitError: Error, LocalizedError {
    case notAvailable
    case readFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAvailable: return "HealthKit is not available on this device."
        case .readFailed(let msg): return "HealthKit read failed: \(msg)"
        }
    }
}
