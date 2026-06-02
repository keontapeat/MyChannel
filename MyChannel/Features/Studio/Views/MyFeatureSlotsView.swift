//
//  MyFeatureSlotsView.swift
//  MyChannel
//
//  A creator's own feature-slot bookings: pending review, approved (pay to
//  lock), scheduled, and live. The Apple In-App Purchase happens HERE — only
//  for bookings an admin has already approved (review-before-pay), so Apple is
//  never charged for a video that gets rejected.
//

import SwiftUI

struct MyFeatureSlotsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var slots = FeatureSlotService.shared
    @StateObject private var payment = FeatureSlotPaymentService.shared

    /// Current creator id (their bookings only).
    private var myId: String? {
        AppState.shared.currentUser?.id ?? AuthenticationManager.shared.currentUser?.id
    }

    @State private var payingBookingId: String?
    @State private var errorText: String?

    private var myBookings: [FeatureSlotBooking] {
        guard let myId else { return [] }
        return slots.bookings
            .filter { $0.creatorId == myId }
            .sorted { a, b in
                if a.statusSortRank != b.statusSortRank {
                    return a.statusSortRank < b.statusSortRank
                }
                return a.startDate < b.startDate
            }
    }

    var body: some View {
        NavigationStack {
            Group {
                if myBookings.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            ForEach(myBookings) { booking in
                                bookingCard(booking)
                            }
                            if let errorText {
                                Text(errorText).font(.footnote).foregroundColor(.red)
                                    .multilineTextAlignment(.center).padding(.top, 4)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .background(Color(.systemBackground))
            .navigationTitle("My Feature Slots")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Done") { dismiss() } }
            }
            .task {
                await slots.loadBookings()
                await payment.loadProducts()
            }
        }
    }

    // MARK: - Cards

    private func bookingCard(_ booking: FeatureSlotBooking) -> some View {
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
                    statusPill(booking.status)
                }
                Spacer()
            }

            Text("\(booking.startDate.formatted(date: .abbreviated, time: .omitted)) → \(booking.endDate.formatted(date: .abbreviated, time: .omitted)) · \(booking.duration.displayName)")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            // Action depends on status
            switch booking.status {
            case .approvedAwaitingPayment:
                payToLockButton(booking)
            case .pendingReview:
                Text("We're reviewing your video. You'll get a notification when it's approved — then you pay to lock it in.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                cancelButton(booking, title: "Withdraw request")
            case .scheduled:
                Label("Paid · goes live \(booking.startDate.formatted(date: .abbreviated, time: .omitted))", systemImage: "checkmark.seal.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.green)
            case .active:
                Label("Live on the feature card now", systemImage: "dot.radiowaves.left.and.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.green)
            case .rejected:
                if let reason = booking.rejectionReason {
                    Text("Not approved: \(reason) (You were not charged.)")
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                }
            case .paymentExpired:
                Text("The pay window passed and the hold was released. You can submit again.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            case .completed, .cancelled:
                EmptyView()
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func payToLockButton(_ booking: FeatureSlotBooking) -> some View {
        let price = payment.displayPrice(rank: booking.rank, duration: booking.duration)
        let isPaying = payingBookingId == booking.id
        return VStack(spacing: 8) {
            Button {
                Task { await payAndLock(booking) }
            } label: {
                HStack(spacing: 8) {
                    if isPaying {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "lock.fill").font(.system(size: 14, weight: .semibold))
                        Text("Pay $\(FeatureSlotPriceFormatter.string(price)) & Lock Slot #\(booking.rank)")
                            .font(.system(size: 15, weight: .semibold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(.label)))
            }
            .buttonStyle(.plain)
            .disabled(isPaying)

            Text("Pay within 48 hours of approval or the slot is released.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }

    private func cancelButton(_ booking: FeatureSlotBooking, title: String) -> some View {
        Button(role: .destructive) {
            Task {
                try? await slots.cancelBooking(booking)
            }
        } label: {
            Text(title).font(.system(size: 13, weight: .semibold))
        }
        .buttonStyle(.bordered)
        .tint(.red)
    }

    private func statusPill(_ status: FeatureSlotBooking.BookingStatus) -> some View {
        Text(status.displayName)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(status.color)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(status.color.opacity(0.14), in: Capsule())
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "star.circle").font(.system(size: 46)).foregroundColor(.yellow)
            Text("No feature bookings yet").font(.system(size: 17, weight: .semibold))
            Text("Open any of your videos → \"Feature Video\" to request a slot on the Home feature card.")
                .font(.system(size: 13)).foregroundColor(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Pay & lock (IAP)

    private func payAndLock(_ booking: FeatureSlotBooking) async {
        payingBookingId = booking.id
        errorText = nil
        defer { payingBookingId = nil }
        do {
            let txnId = try await payment.purchase(rank: booking.rank, duration: booking.duration)
            try await slots.markBookingPaid(booking, transactionId: txnId)
            HapticManager.shared.notification(type: .success)
        } catch FeatureSlotError.userCancelled {
            // silent — user backed out of the Apple sheet
        } catch {
            errorText = error.localizedDescription
            HapticManager.shared.notification(type: .error)
        }
    }
}

// MARK: - Sort helper

private extension FeatureSlotBooking {
    /// Orders a creator's bookings: pay-now first, then review, live, scheduled, then the rest.
    var statusSortRank: Int {
        switch status {
        case .approvedAwaitingPayment: return 0
        case .pendingReview:           return 1
        case .active:                  return 2
        case .scheduled:               return 3
        case .completed:               return 4
        case .rejected:                return 5
        case .paymentExpired:          return 6
        case .cancelled:               return 7
        }
    }
}
