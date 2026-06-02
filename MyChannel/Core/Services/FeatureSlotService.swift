//
//  FeatureSlotService.swift
//  MyChannel
//
//  Source of truth for the ranked Feature Card (#1–#10) booking system.
//
//  Responsibilities:
//   • Load bookings + waitlist in real time from Firestore.
//   • Compute slot availability for any date / date-range (powers the calendar).
//   • Create bookings, approve / reject (admin), cancel, and expire.
//   • Sync currently-live approved bookings into the `featured_videos`
//     collection that FeaturedStore reads — so a paid slot ACTUALLY appears
//     on the Home feature carousel (previously broken).
//   • Manage the waitlist and notify creators when a matching slot frees up.
//

import Foundation
import SwiftUI
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
final class FeatureSlotService: ObservableObject {
    static let shared = FeatureSlotService()

    // MARK: - Published state

    /// Bookings that still matter (anything not completed/rejected/cancelled).
    @Published private(set) var bookings: [FeatureSlotBooking] = []
    @Published private(set) var waitlist: [FeatureSlotWaitlistEntry] = []
    @Published private(set) var isLoading: Bool = false
    @Published var lastError: String?

    /// Admin-internal pay-by deadlines for approved-awaiting-payment bookings,
    /// keyed by booking id. Not part of the public model.
    private var payByDates: [String: Date] = [:]

    /// Pay-by deadline for an approved booking, if one was set.
    func payByDate(for booking: FeatureSlotBooking) -> Date? {
        payByDates[booking.id]
    }

    // MARK: - Collections

    private let bookingsCollection = "feature_slot_bookings"
    private let waitlistCollection = "feature_slot_waitlist"
    private let featuredCollection = "featured_videos"   // read by FeaturedStore
    private let notificationsCollection = "notifications" // read by NotificationsInboxService

    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    private var bookingsListener: ListenerRegistration?
    private var waitlistListener: ListenerRegistration?
    #endif

    private var expirationTimer: Timer?

    /// Owner/admin accounts allowed to write the live feature card + moderate.
    private let adminEmails: Set<String> = ["keontapeat@mychannel.live", "keontapeat@gmail.com"]

    private var isAdmin: Bool {
        let email = (AppState.shared.currentUser?.email ?? AuthenticationManager.shared.currentUser?.email ?? "").lowercased()
        return adminEmails.contains(email)
    }

    private init() {
        Task {
            await loadBookings()
            await loadWaitlist()
            startListening()
        }
        startExpirationTimer()
    }

    // MARK: - Loading

    func loadBookings() async {
        #if canImport(FirebaseFirestore)
        isLoading = true
        defer { isLoading = false }
        do {
            let snap = try await db.collection(bookingsCollection)
                .whereField("status", in: [
                    FeatureSlotBooking.BookingStatus.pendingReview.rawValue,
                    FeatureSlotBooking.BookingStatus.approvedAwaitingPayment.rawValue,
                    FeatureSlotBooking.BookingStatus.scheduled.rawValue,
                    FeatureSlotBooking.BookingStatus.active.rawValue
                ])
                .getDocuments()
            payByDates.removeAll()
            bookings = snap.documents.compactMap { doc in
                if let ts = doc.data()["payByDate"] as? Timestamp {
                    payByDates[doc.documentID] = ts.dateValue()
                }
                return decodeBooking(from: doc.data(), id: doc.documentID)
            }
            .sorted { $0.rank < $1.rank }
        } catch {
            lastError = error.localizedDescription
            print("❌ [FeatureSlot] loadBookings: \(error)")
        }
        #endif
    }

    func loadWaitlist() async {
        #if canImport(FirebaseFirestore)
        do {
            let snap = try await db.collection(waitlistCollection)
                .whereField("notified", isEqualTo: false)
                .getDocuments()
            waitlist = snap.documents.compactMap { decodeWaitlist(from: $0.data(), id: $0.documentID) }
                .sorted { $0.createdAt < $1.createdAt }
        } catch {
            lastError = error.localizedDescription
            print("❌ [FeatureSlot] loadWaitlist: \(error)")
        }
        #endif
    }

    // MARK: - Availability

    /// Bookings that block a slot (paid+approved or awaiting review/scheduled/active).
    private var blockingBookings: [FeatureSlotBooking] {
        bookings.filter { $0.blocksSlot }
    }

    /// Is a given rank free for the entire window [start, end]?
    func isRankAvailable(_ rank: Int, start: Date, end: Date, excludingBookingId: String? = nil) -> Bool {
        !blockingBookings.contains { booking in
            booking.rank == rank &&
            booking.id != excludingBookingId &&
            booking.overlaps(start: start, end: end)
        }
    }

    /// Ranks free for the entire window [start, end], cheapest-rank-first.
    func availableRanks(start: Date, end: Date) -> [Int] {
        FeatureSlotTier.allRanks.filter { isRankAvailable($0, start: start, end: end) }
    }

    /// Ranks taken on a specific calendar day.
    func takenRanks(on day: Date, calendar: Calendar = .current) -> Set<Int> {
        var taken = Set<Int>()
        for booking in blockingBookings where booking.contains(day, calendar: calendar) {
            taken.insert(booking.rank)
        }
        return taken
    }

    /// Per-day availability for a forward-looking range (powers the calendar grid).
    func availability(from startDay: Date, days: Int, calendar: Calendar = .current) -> [FeatureSlotDayAvailability] {
        let base = calendar.startOfDay(for: startDay)
        return (0..<days).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: base) else { return nil }
            return FeatureSlotDayAvailability(date: day, takenRanks: takenRanks(on: day, calendar: calendar))
        }
    }

    /// Booking currently occupying a rank for a given day, if any.
    func booking(forRank rank: Int, on day: Date, calendar: Calendar = .current) -> FeatureSlotBooking? {
        blockingBookings.first { $0.rank == rank && $0.contains(day, calendar: calendar) }
    }

    /// The soonest date a rank becomes free (for "available again" messaging).
    func nextFreeDate(forRank rank: Int, after date: Date = Date(), calendar: Calendar = .current) -> Date? {
        let relevant = blockingBookings
            .filter { $0.rank == rank && $0.endDate >= date }
            .sorted { $0.startDate < $1.startDate }
        guard let last = relevant.last else { return date } // already free
        return calendar.date(byAdding: .day, value: 1, to: last.endDate)
    }

    // MARK: - Pricing

    func price(forRank rank: Int, duration: FeatureSlotDuration) -> Double {
        duration.price(forRank: rank)
    }

    // MARK: - Create booking (review-before-pay; no charge yet)

    /// Builds a booking REQUEST for the chosen slot/window. Does NOT persist and
    /// does NOT charge — the creator pays via IAP only after admin approval.
    func makeBooking(
        video: Video,
        rank: Int,
        duration: FeatureSlotDuration,
        startDate: Date,
        calendar: Calendar = .current
    ) -> FeatureSlotBooking {
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.date(byAdding: .day, value: duration.days - 1, to: start) ?? start
        let now = Date()
        let price = FeatureSlotPricing.price(rank: rank, duration: duration)
        return FeatureSlotBooking(
            id: UUID().uuidString,
            videoId: video.id,
            creatorId: video.creatorId,
            videoTitle: video.title,
            videoThumbnail: video.thumbnailURL,
            creatorName: video.creator.displayName,
            rank: rank,
            duration: duration,
            pricePaid: price,
            startDate: start,
            endDate: end,
            paymentStatus: .unpaid,        // review-before-pay: not charged yet
            status: .pendingReview,
            paymentTransactionId: nil,
            rejectionReason: nil,
            createdAt: now,
            updatedAt: now
        )
    }

    /// Persists a NEW booking request for review. No payment has happened yet —
    /// the creator is only charged (via IAP) after an admin approves. Re-validates
    /// availability to prevent two creators holding the same slot/dates.
    @discardableResult
    func submitBooking(_ booking: FeatureSlotBooking) async throws -> FeatureSlotBooking {
        guard isRankAvailable(booking.rank, start: booking.startDate, end: booking.endDate, excludingBookingId: booking.id) else {
            throw FeatureSlotError.slotTaken(rank: booking.rank)
        }
        #if canImport(FirebaseFirestore)
        try await db.collection(bookingsCollection).document(booking.id).setData(encode(booking))
        #endif
        await loadBookings()
        return booking
    }

    // MARK: - Creator: pay to lock an approved booking (IAP)

    /// Called after a successful IAP for an APPROVED booking. Stamps the
    /// transaction id, marks it paid, and schedules/activates it. The slot was
    /// already held during review, so no re-validation is needed here.
    func markBookingPaid(_ booking: FeatureSlotBooking, transactionId: String) async throws {
        #if canImport(FirebaseFirestore)
        let now = Date()
        let newStatus: FeatureSlotBooking.BookingStatus =
            (now >= booking.startDate && now <= booking.endDate) ? .active : .scheduled
        try await db.collection(bookingsCollection).document(booking.id).updateData([
            "status": newStatus.rawValue,
            "paymentStatus": FeatureSlotBooking.PaymentStatus.completed.rawValue,
            "paymentTransactionId": transactionId,
            "pricePaid": booking.pricePaid,
            "updatedAt": Timestamp(date: now)
        ])
        #endif
        await loadBookings()
        // Creator-side device can't write the public feature card (admin-only),
        // but the admin listener + timer will sync it; trigger a no-op refresh.
        await syncLiveBookingsToFeaturedCard()
    }

    // MARK: - Admin: approve (unlocks payment) / reject

    /// Approves a booking for payment. This does NOT make it live — the creator
    /// must complete the IAP next. We notify them to pay.
    func approveBooking(_ booking: FeatureSlotBooking, adminUserId: String) async throws {
        #if canImport(FirebaseFirestore)
        let now = Date()
        // Give the creator a window to pay before the hold is released.
        let payByDate = Calendar.current.date(byAdding: .hour, value: 48, to: now) ?? now
        try await db.collection(bookingsCollection).document(booking.id).updateData([
            "status": FeatureSlotBooking.BookingStatus.approvedAwaitingPayment.rawValue,
            "reviewedBy": adminUserId,
            "payByDate": Timestamp(date: payByDate),
            "updatedAt": Timestamp(date: now)
        ])
        #endif
        await notifyCreator(
            booking.creatorId,
            title: "You're approved for slot #\(booking.rank) 🎉",
            body: "Pay within 48 hours to lock in your spot for \(booking.startDate.formatted(date: .abbreviated, time: .omitted)).",
            deepLink: "mychannel://feature-slots"
        )
        await loadBookings()
    }

    func rejectBooking(_ booking: FeatureSlotBooking, adminUserId: String, reason: String) async throws {
        #if canImport(FirebaseFirestore)
        try await db.collection(bookingsCollection).document(booking.id).updateData([
            "status": FeatureSlotBooking.BookingStatus.rejected.rawValue,
            "rejectionReason": reason,
            "reviewedBy": adminUserId,
            "updatedAt": Timestamp(date: Date())
        ])
        #endif
        // No charge ever happened (review-before-pay), so nothing to refund.
        await notifyCreator(
            booking.creatorId,
            title: "Feature request declined",
            body: "Your request for slot #\(booking.rank) wasn't approved. \(reason) You were not charged.",
            deepLink: "mychannel://feature-slots"
        )
        await loadBookings()
        await notifyWaitlistForFreedSlot(rank: booking.rank, start: booking.startDate, end: booking.endDate)
    }

    /// Frees a slot (admin removal or creator cancellation) and alerts the waitlist.
    func cancelBooking(_ booking: FeatureSlotBooking) async throws {
        #if canImport(FirebaseFirestore)
        try await db.collection(bookingsCollection).document(booking.id).updateData([
            "status": FeatureSlotBooking.BookingStatus.cancelled.rawValue,
            "updatedAt": Timestamp(date: Date())
        ])
        #endif
        await loadBookings()
        await syncLiveBookingsToFeaturedCard()
        await notifyWaitlistForFreedSlot(rank: booking.rank, start: booking.startDate, end: booking.endDate)
    }

    // MARK: - Expiration

    private func startExpirationTimer() {
        expirationTimer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.processExpirationsAndActivations() }
        }
    }

    /// Flips scheduled→active when start arrives, active→completed when end
    /// passes, and releases approved-but-unpaid holds past their pay-by date.
    /// Then re-syncs the live feature card.
    func processExpirationsAndActivations() async {
        #if canImport(FirebaseFirestore)
        // Status transitions are admin-only writes (matches Firestore rules).
        guard isAdmin else { return }
        let now = Date()
        var changed = false
        for booking in bookings {
            if booking.status == .scheduled, now >= booking.startDate, now <= booking.endDate {
                try? await db.collection(bookingsCollection).document(booking.id)
                    .updateData(["status": FeatureSlotBooking.BookingStatus.active.rawValue,
                                 "updatedAt": Timestamp(date: now)])
                changed = true
            } else if (booking.status == .active || booking.status == .scheduled), now > booking.endDate {
                try? await db.collection(bookingsCollection).document(booking.id)
                    .updateData(["status": FeatureSlotBooking.BookingStatus.completed.rawValue,
                                 "updatedAt": Timestamp(date: now)])
                changed = true
                await notifyWaitlistForFreedSlot(rank: booking.rank, start: now, end: booking.endDate)
            } else if booking.status == .approvedAwaitingPayment,
                      let payBy = payByDate(for: booking), now > payBy {
                // Creator didn't pay in time — release the hold.
                try? await db.collection(bookingsCollection).document(booking.id)
                    .updateData(["status": FeatureSlotBooking.BookingStatus.paymentExpired.rawValue,
                                 "updatedAt": Timestamp(date: now)])
                changed = true
                await notifyWaitlistForFreedSlot(rank: booking.rank, start: booking.startDate, end: booking.endDate)
            }
        }
        if changed {
            await loadBookings()
            await syncLiveBookingsToFeaturedCard()
        }
        #endif
    }

    // MARK: - Sync live bookings → Home feature card

    /// Writes currently-live approved bookings into `featured_videos` (priority = rank)
    /// so they show on the Home carousel in ranked order. Removes any paid-slot docs
    /// that are no longer live. This is the bridge that was previously missing.
    func syncLiveBookingsToFeaturedCard() async {
        #if canImport(FirebaseFirestore)
        // Only admin devices may write the live feature card (matches Firestore rules).
        guard isAdmin else { return }
        let live = bookings.filter { $0.isCurrentlyLive }.sorted { $0.rank < $1.rank }
        let liveVideoIds = Set(live.map { $0.videoId })

        // 1) Upsert live bookings as featured docs, keyed by videoId, priority = rank.
        for booking in live {
            do {
                // Ensure the underlying video doc exists for FeaturedStore to hydrate.
                try await db.collection("videos").document(booking.videoId).setData([
                    "id": booking.videoId,
                    "title": booking.videoTitle,
                    "thumbnailURL": booking.videoThumbnail,
                    "thumbnailUrl": booking.videoThumbnail,
                    "creatorId": booking.creatorId,
                    "userId": booking.creatorId,
                    "creatorName": booking.creatorName,
                    "creatorDisplayName": booking.creatorName,
                    "isPublic": true,
                    "visibility": "public",
                    "updatedAt": FieldValue.serverTimestamp()
                ], merge: true)

                try await db.collection(featuredCollection).document(booking.videoId).setData([
                    "videoId": booking.videoId,
                    "priority": booking.rank,          // #1 → priority 1 → shown first (ascending)
                    "source": "paid_slot",
                    "bookingId": booking.id,
                    "expiresAt": Timestamp(date: booking.endDate),
                    "addedAt": FieldValue.serverTimestamp()
                ], merge: true)
            } catch {
                print("❌ [FeatureSlot] sync upsert failed for \(booking.videoId): \(error)")
            }
        }

        // 2) Remove paid-slot featured docs that are no longer live.
        do {
            let paidDocs = try await db.collection(featuredCollection)
                .whereField("source", isEqualTo: "paid_slot")
                .getDocuments()
            for doc in paidDocs.documents {
                let vid = doc.data()["videoId"] as? String ?? doc.documentID
                if !liveVideoIds.contains(vid) {
                    try? await doc.reference.delete()
                }
            }
        } catch {
            print("❌ [FeatureSlot] sync cleanup failed: \(error)")
        }

        // Nudge the local store to refresh from Firestore.
        FeaturedStore.shared.syncFromFirestore()
        #endif
    }

    // MARK: - Waitlist

    func joinWaitlist(
        video: Video,
        desiredRank: Int?,
        earliestDate: Date
    ) async throws {
        let entry = FeatureSlotWaitlistEntry(
            id: UUID().uuidString,
            videoId: video.id,
            creatorId: video.creatorId,
            videoTitle: video.title,
            videoThumbnail: video.thumbnailURL,
            creatorName: video.creator.displayName,
            desiredRank: desiredRank,
            earliestDate: Calendar.current.startOfDay(for: earliestDate),
            notified: false,
            createdAt: Date()
        )
        #if canImport(FirebaseFirestore)
        try await db.collection(waitlistCollection).document(entry.id).setData([
            "id": entry.id,
            "videoId": entry.videoId,
            "creatorId": entry.creatorId,
            "videoTitle": entry.videoTitle,
            "videoThumbnail": entry.videoThumbnail,
            "creatorName": entry.creatorName,
            "desiredRank": entry.desiredRank as Any,
            "earliestDate": Timestamp(date: entry.earliestDate),
            "notified": false,
            "createdAt": Timestamp(date: entry.createdAt)
        ])
        #endif
        await loadWaitlist()
    }

    func leaveWaitlist(_ entryId: String) async {
        #if canImport(FirebaseFirestore)
        try? await db.collection(waitlistCollection).document(entryId).delete()
        #endif
        await loadWaitlist()
    }

    /// Notifies waitlisted creators whose desired rank just freed up for a window.
    private func notifyWaitlistForFreedSlot(rank: Int, start: Date, end: Date) async {
        let matches = waitlist.filter { entry in
            guard !entry.notified else { return false }
            let rankMatches = (entry.desiredRank == nil || entry.desiredRank == rank)
            let dateMatches = entry.earliestDate <= end
            return rankMatches && dateMatches
        }
        for entry in matches {
            await notifyCreator(
                entry.creatorId,
                title: "A feature slot just opened 🎉",
                body: "Slot #\(rank) is now available. Tap to grab it before someone else does.",
                deepLink: "mychannel://feature-slots?rank=\(rank)"
            )
            #if canImport(FirebaseFirestore)
            try? await db.collection(waitlistCollection).document(entry.id).updateData(["notified": true])
            #endif
        }
        if !matches.isEmpty { await loadWaitlist() }
    }

    // MARK: - Notifications

    private func notifyCreator(_ userId: String, title: String, body: String, deepLink: String?) async {
        #if canImport(FirebaseFirestore)
        let doc: [String: Any] = [
            "userId": userId,
            "type": "system",
            "title": title,
            "body": body,
            "deepLink": deepLink as Any,
            "isRead": false,
            "groupedCount": 1,
            "createdAt": FieldValue.serverTimestamp()
        ]
        try? await db.collection(notificationsCollection).addDocument(data: doc)
        #endif
    }

    // MARK: - Listeners

    private func startListening() {
        #if canImport(FirebaseFirestore)
        bookingsListener = db.collection(bookingsCollection)
            .addSnapshotListener { [weak self] _, error in
                guard let self else { return }
                if let error = error { self.lastError = error.localizedDescription; return }
                Task { @MainActor in await self.loadBookings() }
            }
        waitlistListener = db.collection(waitlistCollection)
            .whereField("notified", isEqualTo: false)
            .addSnapshotListener { [weak self] _, error in
                guard let self else { return }
                if let error = error { self.lastError = error.localizedDescription; return }
                Task { @MainActor in await self.loadWaitlist() }
            }
        #endif
    }

    deinit {
        expirationTimer?.invalidate()
        #if canImport(FirebaseFirestore)
        bookingsListener?.remove()
        waitlistListener?.remove()
        #endif
    }

    // MARK: - Encode / Decode

    #if canImport(FirebaseFirestore)
    private func encode(_ b: FeatureSlotBooking) -> [String: Any] {
        [
            "id": b.id,
            "videoId": b.videoId,
            "creatorId": b.creatorId,
            "videoTitle": b.videoTitle,
            "videoThumbnail": b.videoThumbnail,
            "creatorName": b.creatorName,
            "rank": b.rank,
            "duration": b.duration.rawValue,
            "pricePaid": b.pricePaid,
            "startDate": Timestamp(date: b.startDate),
            "endDate": Timestamp(date: b.endDate),
            "paymentStatus": b.paymentStatus.rawValue,
            "status": b.status.rawValue,
            "paymentTransactionId": b.paymentTransactionId as Any,
            "rejectionReason": b.rejectionReason as Any,
            "createdAt": Timestamp(date: b.createdAt),
            "updatedAt": Timestamp(date: b.updatedAt)
        ]
    }

    private func decodeBooking(from data: [String: Any], id: String) -> FeatureSlotBooking? {
        guard
            let videoId = data["videoId"] as? String,
            let creatorId = data["creatorId"] as? String,
            let videoTitle = data["videoTitle"] as? String,
            let videoThumbnail = data["videoThumbnail"] as? String,
            let creatorName = data["creatorName"] as? String,
            let rank = data["rank"] as? Int,
            let durationRaw = data["duration"] as? String,
            let duration = FeatureSlotDuration(rawValue: durationRaw),
            let pricePaid = data["pricePaid"] as? Double,
            let startTS = data["startDate"] as? Timestamp,
            let endTS = data["endDate"] as? Timestamp,
            let paymentRaw = data["paymentStatus"] as? String,
            let payment = FeatureSlotBooking.PaymentStatus(rawValue: paymentRaw),
            let statusRaw = data["status"] as? String,
            let status = FeatureSlotBooking.BookingStatus(rawValue: statusRaw),
            let createdTS = data["createdAt"] as? Timestamp,
            let updatedTS = data["updatedAt"] as? Timestamp
        else { return nil }

        return FeatureSlotBooking(
            id: id,
            videoId: videoId,
            creatorId: creatorId,
            videoTitle: videoTitle,
            videoThumbnail: videoThumbnail,
            creatorName: creatorName,
            rank: rank,
            duration: duration,
            pricePaid: pricePaid,
            startDate: startTS.dateValue(),
            endDate: endTS.dateValue(),
            paymentStatus: payment,
            status: status,
            paymentTransactionId: data["paymentTransactionId"] as? String,
            rejectionReason: data["rejectionReason"] as? String,
            createdAt: createdTS.dateValue(),
            updatedAt: updatedTS.dateValue()
        )
    }

    private func decodeWaitlist(from data: [String: Any], id: String) -> FeatureSlotWaitlistEntry? {
        guard
            let videoId = data["videoId"] as? String,
            let creatorId = data["creatorId"] as? String,
            let videoTitle = data["videoTitle"] as? String,
            let videoThumbnail = data["videoThumbnail"] as? String,
            let creatorName = data["creatorName"] as? String,
            let earliestTS = data["earliestDate"] as? Timestamp,
            let createdTS = data["createdAt"] as? Timestamp
        else { return nil }

        return FeatureSlotWaitlistEntry(
            id: id,
            videoId: videoId,
            creatorId: creatorId,
            videoTitle: videoTitle,
            videoThumbnail: videoThumbnail,
            creatorName: creatorName,
            desiredRank: data["desiredRank"] as? Int,
            earliestDate: earliestTS.dateValue(),
            notified: data["notified"] as? Bool ?? false,
            createdAt: createdTS.dateValue()
        )
    }
    #endif
}

// MARK: - Errors

enum FeatureSlotError: LocalizedError {
    case slotTaken(rank: Int)
    case noDateSelected
    case productNotFound
    case paymentFailed(String)
    case userCancelled

    var errorDescription: String? {
        switch self {
        case .slotTaken(let rank):
            return "Slot #\(rank) was just booked for those dates. Pick another slot or date."
        case .noDateSelected:
            return "Choose a start date for your feature."
        case .productNotFound:
            return "This slot isn't available for purchase right now. Please try again."
        case .paymentFailed(let reason):
            return "Payment failed: \(reason)"
        case .userCancelled:
            return "Payment was cancelled."
        }
    }
}
