//
//  FeatureSlotWaitlistSheet.swift
//  MyChannel
//
//  Lets a creator join the waitlist for a feature slot. They pick a desired
//  rank (or "any") and the earliest date they'd accept, and get notified the
//  moment a matching slot frees up.
//

import SwiftUI

struct FeatureSlotWaitlistSheet: View {
    let video: Video
    let suggestedDate: Date

    @Environment(\.dismiss) private var dismiss
    @StateObject private var slots = FeatureSlotService.shared

    @State private var desiredRank: Int? = nil   // nil = any slot
    @State private var earliestDate: Date
    @State private var isSubmitting = false
    @State private var joined = false
    @State private var errorText: String?

    init(video: Video, suggestedDate: Date) {
        self.video = video
        self.suggestedDate = suggestedDate
        _earliestDate = State(initialValue: Calendar.current.startOfDay(for: suggestedDate))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    rankPicker
                    datePicker
                    if let errorText {
                        Text(errorText).font(.footnote).foregroundColor(.red)
                    }
                    Spacer(minLength: 12)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
            .background(Color(.systemBackground))
            .safeAreaInset(edge: .bottom) { joinButton }
            .navigationTitle("Join Waitlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(.primary)
                }
            }
            .alert("You're on the list ✅", isPresented: $joined) {
                Button("Done") { dismiss() }
            } message: {
                Text("We'll notify you the moment a matching slot opens up. First to book it gets it.")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "bell.badge.fill").foregroundColor(.orange)
                Text("Get notified when a spot opens")
                    .font(.system(size: 16, weight: .semibold))
            }
            Text("Tell us which spot you want and the earliest date you'd take it. We'll ping you the instant it's free.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
    }

    private var rankPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Which spot?")
                .font(.system(size: 14, weight: .semibold))

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                rankChip(title: "Any", isSelected: desiredRank == nil) { desiredRank = nil }
                ForEach(FeatureSlotTier.allRanks, id: \.self) { rank in
                    rankChip(title: "#\(rank)", isSelected: desiredRank == rank) { desiredRank = rank }
                }
            }
        }
    }

    private func rankChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
            HapticManager.shared.impact(style: .light)
        } label: {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isSelected ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? Color(.label) : Color(.systemGray6))
                )
        }
        .buttonStyle(.plain)
    }

    private var datePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Earliest date you'd take it")
                .font(.system(size: 14, weight: .semibold))
            DatePicker(
                "Earliest date",
                selection: $earliestDate,
                in: Calendar.current.startOfDay(for: Date())...,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .tint(Color(.label))
            .padding(.horizontal, 4)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var joinButton: some View {
        Button {
            Task { await join() }
        } label: {
            HStack(spacing: 8) {
                if isSubmitting {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "bell.fill").font(.system(size: 14, weight: .semibold))
                    Text("Notify Me When Open").font(.system(size: 16, weight: .semibold))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(Color.orange))
        }
        .buttonStyle(.plain)
        .disabled(isSubmitting)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private func join() async {
        isSubmitting = true
        errorText = nil
        defer { isSubmitting = false }
        do {
            try await slots.joinWaitlist(video: video, desiredRank: desiredRank, earliestDate: earliestDate)
            HapticManager.shared.notification(type: .success)
            joined = true
        } catch {
            errorText = error.localizedDescription
        }
    }
}
