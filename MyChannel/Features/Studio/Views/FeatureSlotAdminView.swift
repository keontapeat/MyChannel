//
//  FeatureSlotAdminView.swift
//  MyChannel
//
//  Admin console for the ranked Feature Card. Review paid bookings, approve /
//  reject (with refund messaging), see who's live in each ranked slot, view the
//  waitlist, and free up slots. Approved + live bookings are synced to the Home
//  feature carousel automatically.
//

import SwiftUI

struct FeatureSlotAdminView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var slots = FeatureSlotService.shared

    @State private var tab: AdminTab = .review
    @State private var rejectTarget: FeatureSlotBooking?
    @State private var rejectReason: String = ""
    @State private var working = false

    enum AdminTab: String, CaseIterable, Identifiable {
        case review = "Review"
        case live = "Live Slots"
        case waitlist = "Waitlist"
        var id: String { rawValue }
    }

    private var adminId: String {
        AppState.shared.currentUser?.id ?? AuthenticationManager.shared.currentUser?.id ?? "owner"
    }

    private var pendingReview: [FeatureSlotBooking] {
        slots.bookings.filter { $0.status == .pendingReview }.sorted { $0.rank < $1.rank }
    }

    private var liveAndScheduled: [FeatureSlotBooking] {
        slots.bookings
            .filter { $0.status == .active || $0.status == .scheduled || $0.status == .approvedAwaitingPayment }
            .sorted { $0.rank < $1.rank }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("View", selection: $tab) {
                    ForEach(AdminTab.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(16)

                ScrollView {
                    switch tab {
                    case .review:   reviewList
                    case .live:     liveList
                    case .waitlist: waitlistList
                    }
                }
            }
            .background(Color(.systemBackground))
            .navigationTitle("Feature Slots")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await slots.loadBookings()
                await slots.loadWaitlist()
                await slots.processExpirationsAndActivations()
            }
            .sheet(item: $rejectTarget) { booking in
                rejectSheet(booking)
            }
        }
    }

    // MARK: - Review tab

    private var reviewList: some View {
        LazyVStack(spacing: 14) {
            if pendingReview.isEmpty {
                emptyState(icon: "checkmark.seal.fill", color: .green,
                           title: "Nothing to review",
                           subtitle: "New feature requests show up here. Approving one lets the creator pay to lock it in.")
            } else {
                ForEach(pendingReview) { booking in
                    bookingCard(booking, showActions: true)
                }
            }
        }
        .padding(16)
    }

    // MARK: - Live tab

    private var liveList: some View {
        LazyVStack(spacing: 14) {
            if liveAndScheduled.isEmpty {
                emptyState(icon: "star.circle", color: .yellow,
                           title: "No slots filled",
                           subtitle: "Approved bookings will appear here and on the Home feature card.")
            } else {
                ForEach(liveAndScheduled) { booking in
                    bookingCard(booking, showActions: false)
                }
            }
        }
        .padding(16)
    }

    // MARK: - Waitlist tab

    private var waitlistList: some View {
        LazyVStack(spacing: 14) {
            if slots.waitlist.isEmpty {
                emptyState(icon: "person.2.slash", color: .secondary,
                           title: "Waitlist is empty",
                           subtitle: "Creators waiting for a slot will show up here.")
            } else {
                ForEach(slots.waitlist) { entry in
                    waitlistCard(entry)
                }
            }
        }
        .padding(16)
    }

    // MARK: - Cards

    private func bookingCard(_ booking: FeatureSlotBooking, showActions: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(booking.rank == 1 ? Color.yellow : Color(.systemGray5))
                        .frame(width: 44, height: 44)
                    Text("#\(booking.rank)")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundColor(booking.rank == 1 ? .black : .primary)
                }

                FeatureSlotThumbnail(thumbnailURL: booking.videoThumbnail)
                    .frame(width: 96, height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(booking.videoTitle).font(.system(size: 14, weight: .semibold)).lineLimit(2)
                    Text("by \(booking.creatorName)").font(.system(size: 12)).foregroundColor(.secondary)
                }
                Spacer()
            }

            HStack(spacing: 10) {
                tag(booking.status.displayName, color: booking.status.color)
                tag(FeatureSlotPriceFormatter.dollar(FeatureSlotPricing.price(rank: booking.rank, duration: booking.duration)), color: .green)
                tag(booking.duration.displayName, color: .secondary)
            }

            Text("\(booking.startDate.formatted(date: .abbreviated, time: .omitted)) → \(booking.endDate.formatted(date: .abbreviated, time: .omitted))")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            if showActions {
                HStack(spacing: 10) {
                    Button {
                        Task { await approve(booking) }
                    } label: {
                        Label("Approve to Pay", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)

                    Button {
                        rejectReason = ""
                        rejectTarget = booking
                    } label: {
                        Label("Reject", systemImage: "xmark.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
                .disabled(working)
            } else {
                Button(role: .destructive) {
                    Task { await freeUp(booking) }
                } label: {
                    Label("Remove & free this slot", systemImage: "trash")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .disabled(working)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func waitlistCard(_ entry: FeatureSlotWaitlistEntry) -> some View {
        HStack(spacing: 12) {
            FeatureSlotThumbnail(thumbnailURL: entry.videoThumbnail)
                .frame(width: 84, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.videoTitle).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                Text("by \(entry.creatorName)").font(.system(size: 12)).foregroundColor(.secondary)
                HStack(spacing: 8) {
                    tag("Wants \(entry.desiredRankDisplay)", color: .blue)
                    tag("From \(entry.earliestDate.formatted(date: .abbreviated, time: .omitted))", color: .secondary)
                }
            }
            Spacer()
            Button {
                Task { await slots.leaveWaitlist(entry.id) }
            } label: {
                Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Reject sheet

    private func rejectSheet(_ booking: FeatureSlotBooking) -> some View {
        NavigationStack {
            Form {
                Section("Why is this being rejected?") {
                    TextEditor(text: $rejectReason).frame(minHeight: 110)
                }
                Section {
                    Text("The creator is notified and will not be charged. (Payment only happens after approval, so there's nothing to refund.)")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                Section {
                    Button(role: .destructive) {
                        Task { await reject(booking) }
                    } label: {
                        Text("Reject Request")
                    }
                    .disabled(rejectReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("Reject Booking")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { rejectTarget = nil }
                }
            }
        }
    }

    // MARK: - Bits

    private func tag(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(color.opacity(0.14), in: Capsule())
    }

    private func emptyState(icon: String, color: Color, title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 44)).foregroundColor(color)
            Text(title).font(.system(size: 17, weight: .semibold))
            Text(subtitle).font(.system(size: 13)).foregroundColor(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Actions

    private func approve(_ booking: FeatureSlotBooking) async {
        working = true; defer { working = false }
        do {
            try await slots.approveBooking(booking, adminUserId: adminId)
            HapticManager.shared.notification(type: .success)
        } catch {
            NotificationManager.shared.showError(error.localizedDescription)
        }
    }

    private func reject(_ booking: FeatureSlotBooking) async {
        working = true; defer { working = false }
        do {
            try await slots.rejectBooking(booking, adminUserId: adminId, reason: rejectReason.trimmingCharacters(in: .whitespacesAndNewlines))
            rejectTarget = nil
            HapticManager.shared.notification(type: .success)
        } catch {
            NotificationManager.shared.showError(error.localizedDescription)
        }
    }

    private func freeUp(_ booking: FeatureSlotBooking) async {
        working = true; defer { working = false }
        do {
            try await slots.cancelBooking(booking)
            HapticManager.shared.notification(type: .success)
        } catch {
            NotificationManager.shared.showError(error.localizedDescription)
        }
    }
}
