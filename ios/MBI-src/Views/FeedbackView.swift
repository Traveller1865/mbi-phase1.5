// ios/MBI/Views/FeedbackView.swift
// MBI Phase 1 — Feedback Screen
// Felt right / Felt off + optional note (280 char max)

import SwiftUI

struct FeedbackView: View {
    @EnvironmentObject var supabase: SupabaseService
    @Environment(\.dismiss) var dismiss

    let score: DailyScore

    @State private var feltAccurate: Bool? = nil
    @State private var note = ""
    @State private var isSubmitting = false
    @State private var submitted = false
    @State private var error: String?

    private let maxNoteLength = 280

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if submitted {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.white.opacity(0.8))
                    Text("Feedback saved")
                        .font(.system(size: 22, weight: .light))
                        .foregroundColor(.white)
                    Text("Thank you — this helps calibrate your score over time.")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 48)
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { dismiss() }
                }
            } else {
                VStack(spacing: 0) {
                    // Handle
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 36, height: 4)
                        .padding(.top, 12)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Did this feel right?")
                                .font(.system(size: 26, weight: .light))
                                .foregroundColor(.white)
                                .padding(.top, 28)

                            Text("Your Chronos score was \(Int(score.chronosScore)) — \(score.scoreBand.rawValue)")
                                .font(.system(size: 15))
                                .foregroundColor(.white.opacity(0.45))
                                .padding(.top, 8)
                                .padding(.bottom, 32)

                            // Binary choice
                            HStack(spacing: 12) {
                                FeedbackChoiceButton(
                                    label: "Felt right",
                                    systemImage: "hand.thumbsup",
                                    isSelected: feltAccurate == true,
                                    color: Color(red: 0.3, green: 0.85, blue: 0.5)
                                ) { feltAccurate = true }

                                FeedbackChoiceButton(
                                    label: "Felt off",
                                    systemImage: "hand.thumbsdown",
                                    isSelected: feltAccurate == false,
                                    color: Color(red: 1.0, green: 0.5, blue: 0.3)
                                ) { feltAccurate = false }
                            }
                            .padding(.bottom, 28)

                            // Optional note
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Add a note (optional)")
                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.4))
                                    .tracking(1)

                                ZStack(alignment: .topLeading) {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.06))

                                    if note.isEmpty {
                                        Text("What felt different today?")
                                            .foregroundColor(.white.opacity(0.25))
                                            .font(.system(size: 15))
                                            .padding(14)
                                    }

                                    TextEditor(text: $note)
                                        .scrollContentBackground(.hidden)
                                        .background(Color.clear)
                                        .foregroundColor(.white)
                                        .font(.system(size: 15))
                                        .frame(minHeight: 100)
                                        .padding(10)
                                        .onChange(of: note) { _ in
                                            if note.count > maxNoteLength {
                                                note = String(note.prefix(maxNoteLength))
                                            }
                                        }
                                }
                                .frame(minHeight: 120)

                                HStack {
                                    Spacer()
                                    Text("\(note.count)/\(maxNoteLength)")
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.25))
                                }
                            }

                            if let error = error {
                                Text(error)
                                    .font(.system(size: 13))
                                    .foregroundColor(.red.opacity(0.8))
                                    .padding(.top, 12)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                    }

                    // Submit
                    MBIPrimaryButton(
                        title: "Submit Feedback",
                        isLoading: isSubmitting
                    ) {
                        guard let accurate = feltAccurate else { return }
                        isSubmitting = true
                        Task {
                            do {
                                guard let userId = supabase.session?.userId else { return }
                                try await supabase.submitFeedback(
                                    scoreId: score.id,
                                    userId: userId,
                                    date: score.date,
                                    feltAccurate: accurate,
                                    note: note.isEmpty ? nil : note
                                )
                                submitted = true
                            } catch {
                                self.error = error.localizedDescription
                            }
                            isSubmitting = false
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 36)
                    .disabled(feltAccurate == nil)
                    .opacity(feltAccurate == nil ? 0.5 : 1)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }
}

struct FeedbackChoiceButton: View {
    let label: String
    let systemImage: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 16))
                Text(label)
                    .font(.system(size: 15, weight: .medium))
            }
            .foregroundColor(isSelected ? .black : .white.opacity(0.6))
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? color : Color.white.opacity(0.07))
            )
        }
    }
}
