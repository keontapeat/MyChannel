//
//  FeatureSlotBookingView.swift
//  MyChannel
//
//  Creator-facing flow to book a ranked Feature Card slot (#1–#10).
//  Pick a slot, see live availability on a calendar, choose a start date and
//  duration, then SUBMIT FOR REVIEW. No charge happens here — the creator pays
//  via Apple In-App Purchase only after an admin approves (review-before-pay),
//  so there are never refunds for rejected videos. If everything is full, join
//  the waitlist to be notified the moment a slot frees up.
//

import SwiftUI

struct FeatureSlotBookingView: View {
    let video: Video
    @Environment(\.dismiss) private var dismiss

    @StateObject private var slots = FeatureSlotService.shared
    @StateObject private var payment = FeatureSlotPaymentService.shared

    @State private var selectedRank: Int? = nil
    @State private var selectedDuration: FeatureSlotDuration = .oneWeek
    @State private var startDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var isProcessing = false
    @State private var showSuccess = false
    @State private var showWaitlist = false
    @State private var showCalendar = false
    @State private var errorText: String?

    private var calendar: Calendar { .current }

    private var endDate: Date {
        calendar.date(byAdding: .day, value: selectedDuration.days - 1, to: startDate) ?? startDate
    }

    private var availableRanksForWindow: [Int] {
        slots.availableRanks(start: startDate, end: endDate)
    }

    private var allSlotsFull: Bool { availableRanksForWindow.isEmpty }

    private var selectedPrice: Double {
        guard let rank = selectedRank else { return 0 }
        return payment.displayPrice(rank: rank, duration: selectedDuration)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    videoCard
                    windowSection
                    slotLadderSection
                    if allSlotsFull { fullStateBanner }
                    if let errorText { errorBanner(errorText) }
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)
            }
            .background(Color(.systemBackground))
            .safeAreaInset(edge: .bottom) { bottomBar }
            .navigationTitle("Feature Your Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(.primary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        HapticManager.shared.impact(style: .light)
                        showCalendar = true
                    } label: {
                        Image(systemName: "calendar")
                    }
                    .foregroundColor(.primary)
                }
            }
            .onAppear { Task { await payment.loadProducts() } }
            .sheet(isPresented: $showCalendar) {
                FeatureSlotCalendarView(initialDate: startDate) { picked in
                    startDate = picked
                }
            }
            .sheet(isPresented: $showWaitlist) {
                FeatureSlotWaitlistSheet(video: video, suggestedDate: startDate)
            }
            .alert("Submitted for review 🎉", isPresented: $showSuccess) {
                Button("Done") { dismiss() }
            } message: {
                Text("We'll review your video for slot #\(selectedRank ?? 0). Once approved, you'll get a notification to pay and lock in \(startDate.formatted(date: .abbreviated, time: .omitted)). You're not charged until then.")
            }
        }
    }

    // MARK: - Video card

    private var videoCard: some View {
        HStack(spacing: 14) {
            FeatureSlotThumbnail(thumbnailURL: video.thumbnailURL)
                .frame(width: 132, height: 74)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(video.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                Text("by \(video.creator.displayName)")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Window (date + duration)

    private var windowSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("When")
                .font(.system(size: 15, weight: .semibold))

            Button {
                HapticManager.shared.impact(style: .light)
                showCalendar = true
            } label: {
                HStack {
                    Image(systemName: "calendar")
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Starts \(startDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                        Text("through \(endDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text("Change").font(.system(size: 13, weight: .semibold)).foregroundColor(.accentColor)
                }
                .padding(14)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                ForEach(FeatureSlotDuration.allCases) { duration in
                    durationChip(duration)
                }
            }
        }
    }

    private func durationChip(_ duration: FeatureSlotDuration) -> some View {
        let isSelected = selectedDuration == duration
        return Button {
            selectedDuration = duration
            // Selected rank may no longer be free for the new window.
            if let r = selectedRank, !slots.isRankAvailable(r, start: startDate, end: endDate) {
                selectedRank = nil
            }
            HapticManager.shared.impact(style: .light)
        } label: {
            Text(duration.displayName)
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

    // MARK: - Slot ladder (#1–#10)

    private var slotLadderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Choose Your Spot")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Text("\(availableRanksForWindow.count) of \(FeatureSlotTier.totalSlots) open")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 8) {
                ForEach(FeatureSlotTier.ladder) { tier in
                    slotRow(tier)
                }
            }
        }
    }

    private func slotRow(_ tier: FeatureSlotTier) -> some View {
        let available = slots.isRankAvailable(tier.rank, start: startDate, end: endDate)
        let isSelected = selectedRank == tier.rank
        let price = payment.displayPrice(rank: tier.rank, duration: selectedDuration)
        let nextFree = slots.nextFreeDate(forRank: tier.rank, after: endDate)

        return Button {
            guard available else { return }
            selectedRank = tier.rank
            errorText = nil
            HapticManager.shared.impact(style: .medium)
        } label: {
            HStack(spacing: 14) {
                // Rank badge
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(rankBadgeColor(tier.rank, isSelected: isSelected, available: available))
                        .frame(width: 46, height: 46)
                    Text("#\(tier.rank)")
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .foregroundColor(isSelected || tier.isTopSlot ? .white : .primary)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(slotTitle(tier.rank))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(available ? (isSelected ? .white : .primary) : .secondary)
                        if tier.isTopSlot {
                            Text("TOP")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(Color.yellow, in: Capsule())
                        }
                    }
                    if available {
                        Text("Featured for \(selectedDuration.displayName.lowercased())")
                            .font(.system(size: 12))
                            .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    } else if let nextFree {
                        Text("Taken · free \(nextFree.formatted(date: .abbreviated, time: .omitted))")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.orange)
                    } else {
                        Text("Taken")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.orange)
                    }
                }

                Spacer()

                Text("$\(priceString(price))")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(available ? (isSelected ? .white : .primary) : .secondary)
                    .strikethrough(!available, color: .secondary)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color(.label) : Color(.systemGray6))
                    .opacity(available ? 1 : 0.55)
            )
        }
        .buttonStyle(.plain)
        .disabled(!available)
    }

    private func rankBadgeColor(_ rank: Int, isSelected: Bool, available: Bool) -> Color {
        if !available { return Color(.systemGray4) }
        if isSelected { return .white.opacity(0.22) }
        if rank == 1 { return Color.yellow }
        if rank <= 3 { return Color.orange.opacity(0.85) }
        return Color(.systemGray5)
    }

    private func slotTitle(_ rank: Int) -> String {
        switch rank {
        case 1: return "Top Spot · #1"
        case 2, 3: return "Premium · #\(rank)"
        default: return "Spot #\(rank)"
        }
    }

    // MARK: - Full state + waitlist

    private var fullStateBanner: some View {
        VStack(spacing: 12) {
            Image(systemName: "hourglass")
                .font(.system(size: 30))
                .foregroundColor(.orange)
            Text("All slots are booked for these dates")
                .font(.system(size: 15, weight: .semibold))
                .multilineTextAlignment(.center)
            Text("Pick a later start date, or join the waitlist and we'll notify you the second a slot frees up.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button {
                HapticManager.shared.impact(style: .medium)
                showWaitlist = true
            } label: {
                Text("Join Waitlist")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Color.orange, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func errorBanner(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundColor(.red)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 10) {
            if selectedRank != nil {
                HStack {
                    Text("Price if approved")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("$\(priceString(selectedPrice))")
                        .font(.system(size: 24, weight: .bold))
                }
            }

            Button {
                Task { await submitForReview() }
            } label: {
                HStack(spacing: 8) {
                    if isProcessing {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "paperplane.fill").font(.system(size: 14, weight: .semibold))
                        Text(submitButtonTitle).font(.system(size: 16, weight: .semibold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(selectedRank == nil ? Color(.systemGray3) : Color(.label))
                )
            }
            .buttonStyle(.plain)
            .disabled(selectedRank == nil || isProcessing)

            Text("Free to submit · you only pay (Apple) after it's approved")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }

    private var submitButtonTitle: String {
        guard selectedRank != nil else { return "Select a Slot" }
        return "Submit for Review"
    }

    // MARK: - Helpers

    private func priceString(_ value: Double) -> String {
        FeatureSlotPriceFormatter.string(value)
    }

    // MARK: - Submit for review (NO charge — pay later via IAP after approval)

    private func submitForReview() async {
        guard let rank = selectedRank else { return }
        isProcessing = true
        errorText = nil
        defer { isProcessing = false }

        // Make sure the slot is still open for these dates.
        guard slots.isRankAvailable(rank, start: startDate, end: endDate) else {
            errorText = FeatureSlotError.slotTaken(rank: rank).localizedDescription
            selectedRank = nil
            return
        }

        do {
            let booking = slots.makeBooking(
                video: video,
                rank: rank,
                duration: selectedDuration,
                startDate: startDate
            )
            try await slots.submitBooking(booking)
            HapticManager.shared.notification(type: .success)
            showSuccess = true
        } catch {
            errorText = error.localizedDescription
            HapticManager.shared.notification(type: .error)
        }
    }
}

// MARK: - Shared thumbnail (handles asset:// and remote URLs)

struct FeatureSlotThumbnail: View {
    let thumbnailURL: String

    var body: some View {
        Group {
            if thumbnailURL.hasPrefix("asset://"),
               let name = thumbnailURL.split(separator: "/").last.map(String.init), !name.isEmpty {
                Image(name).resizable().scaledToFill()
            } else if !thumbnailURL.isEmpty, let url = URL(string: thumbnailURL) {
                AppAsyncImage(url: url) { img in
                    img.resizable().scaledToFill()
                } placeholder: {
                    placeholder
                }
            } else {
                placeholder
            }
        }
    }

    private var placeholder: some View {
        Color(.systemGray5).overlay(
            Image(systemName: "play.rectangle.fill").foregroundColor(Color(.systemGray3))
        )
    }
}
