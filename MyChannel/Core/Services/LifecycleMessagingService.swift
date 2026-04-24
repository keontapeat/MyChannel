//
//  LifecycleMessagingService.swift
//  MyChannel
//
//  Phase 54: Lifecycle email/SMS orchestration.
//  Triggers the right server-side campaign (drip emails, re-engagement SMS,
//  creator-milestone) via Cloud Run `email-personalization-ai` and the
//  existing `EmailMarketingService` Firebase Functions pipeline.
//

import Foundation

enum LifecycleCampaign: String, Codable, CaseIterable {
    case welcomeDay0
    case welcomeDay3
    case welcomeDay7
    case upload_first_video
    case watch_progress_nudge
    case dormant_14d
    case dormant_30d
    case creator_milestone_100subs
    case creator_milestone_1ksubs
    case creator_milestone_10ksubs
    case subscription_trial_ending
    case subscription_renew_reminder
    case referral_invite_accepted
    case password_reset_success
}

enum LifecycleChannel: String, Codable {
    case email
    case sms
    case push
    case inApp
}

struct LifecycleDispatch: Codable {
    let uid: String
    let campaign: LifecycleCampaign
    let preferredChannel: LifecycleChannel
    let locale: String
    let payload: [String: String]
}

@MainActor
final class LifecycleMessagingService: ObservableObject {
    static let shared = LifecycleMessagingService()
    private init() {}

    /// Fire a lifecycle event. Server decides final channel + send time.
    func dispatch(
        _ campaign: LifecycleCampaign,
        uid: String,
        preferredChannel: LifecycleChannel = .email,
        locale: String = Locale.current.identifier,
        payload: [String: String] = [:]
    ) async throws {
        guard AppConfig.Features.enableLifecycleMessaging else { return }

        struct Request: Encodable {
            let task: String
            let uid: String
            let campaign: String
            let channel: String
            let locale: String
            let payload: [String: String]
        }
        _ = try await CloudRunAgentRouter.post(
            .emailPersonalization,
            path: "/predict",
            body: Request(
                task: "dispatch",
                uid: uid,
                campaign: campaign.rawValue,
                channel: preferredChannel.rawValue,
                locale: locale,
                payload: payload
            )
        ) as _Ack
    }

    /// Mark a user as unsubscribed from a given campaign family.
    func optOut(uid: String, campaign: LifecycleCampaign) async throws {
        struct Request: Encodable {
            let task: String
            let uid: String
            let campaign: String
        }
        _ = try await CloudRunAgentRouter.post(
            .emailPersonalization,
            path: "/predict",
            body: Request(task: "opt_out", uid: uid, campaign: campaign.rawValue)
        ) as _Ack
    }

    private struct _Ack: Decodable { let ok: Bool? }
}
