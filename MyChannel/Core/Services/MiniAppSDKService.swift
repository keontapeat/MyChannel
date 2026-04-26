//
//  MiniAppSDKService.swift
//  MyChannel
//
//  Phase 99: MyChannel Mini-App SDK.
//  Third-party developers embed interactive experiences (quizzes, donations,
//  shopping carts, polls) inside video overlays via a sandboxed WKWebView.
//  The mini-app talks to native services through a JavaScript bridge.
//

import Foundation
#if canImport(WebKit)
import WebKit
#endif

struct MiniApp: Codable, Identifiable, Equatable {
    let id: String
    let developerId: String         // matches PublicCreatorAPI client_id
    let name: String
    let description: String
    let iconURL: URL?
    let entryURL: URL               // HTTPS only, loaded in sandboxed WKWebView
    let permissions: [MiniAppPermission]
    let version: String
    let minSDKVersion: Int          // int version e.g. 1
    let approved: Bool
}

enum MiniAppPermission: String, Codable, CaseIterable {
    case readUserProfile      // uid, displayName, avatarURL
    case readVideoContext      // videoId, creatorId, currentSeconds
    case postComment
    case openExternalURL
    case receivePayments       // in-app tip via IAP bridge
    case accessCamera
    case accessMicrophone
}

struct MiniAppInstallation: Codable, Identifiable, Equatable {
    let id: String
    let miniAppId: String
    let installedByUid: String      // creator who embeds it
    let videoId: String?            // nil = all videos
    let grantedPermissions: [MiniAppPermission]
    let installedAt: Date
}

// MARK: - JS Bridge message types (sent by mini-app)

struct MiniAppBridgeMessage: Codable {
    let type: MessageType
    let requestId: String
    let payload: [String: String]

    enum MessageType: String, Codable {
        case getUser, getVideoContext, postComment, openURL, requestPayment, ping
    }
}

@MainActor
final class MiniAppSDKService: NSObject, ObservableObject {
    static let shared = MiniAppSDKService()
    override private init() {}

    @Published private(set) var installedApps: [MiniAppInstallation] = []

    // MARK: - Registry

    func loadInstalled(creatorUid: String) async throws {
        guard AppConfig.Features.enableMiniAppSDK else { return }
        struct Request: Encodable { let task: String; let creatorUid: String }
        struct RawInstall: Decodable {
            let id: String
            let mini_app_id: String
            let video_id: String?
            let granted_permissions: [String]?
            let installed_at: Double
        }
        struct Raw: Decodable { let installs: [RawInstall]? }

        let r: Raw = try await CloudRunAgentRouter.post(
            .superAITeam,
            path: "/predict",
            body: Request(task: "list_installs", creatorUid: creatorUid)
        )
        installedApps = (r.installs ?? []).map {
            MiniAppInstallation(
                id: $0.id,
                miniAppId: $0.mini_app_id,
                installedByUid: creatorUid,
                videoId: $0.video_id,
                grantedPermissions: ($0.granted_permissions ?? []).compactMap(MiniAppPermission.init(rawValue:)),
                installedAt: Date(timeIntervalSince1970: $0.installed_at)
            )
        }
    }

    // MARK: - WKWebView configuration (creator passes this to the host WKWebView)

    /// Returns a WKWebViewConfiguration that:
    ///   • allows only the mini-app's origin
    ///   • injects the JS bridge shim
    ///   • sets up the message handler
    func webViewConfiguration(for app: MiniApp, handler: MiniAppBridgeHandler) -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        #if canImport(WebKit)
        config.userContentController.add(handler, name: "myChannelBridge")

        let bridgeJS = """
        window.MyChannel = {
            call: function(type, payload) {
                return new Promise(function(resolve, reject) {
                    var reqId = Math.random().toString(36).slice(2);
                    window._mcBridgeCallbacks = window._mcBridgeCallbacks || {};
                    window._mcBridgeCallbacks[reqId] = {resolve, reject};
                    window.webkit.messageHandlers.myChannelBridge.postMessage(
                        JSON.stringify({type, requestId: reqId, payload: payload || {}})
                    );
                });
            },
            getUser: function() { return this.call('getUser'); },
            getVideoContext: function() { return this.call('getVideoContext'); },
            openURL: function(url) { return this.call('openURL', {url}); }
        };
        """
        let script = WKUserScript(source: bridgeJS, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        config.userContentController.addUserScript(script)
        config.preferences.javaScriptEnabled = true
        // Sandbox: block camera/mic unless granted.
        if !app.permissions.contains(.accessCamera) && !app.permissions.contains(.accessMicrophone) {
            config.mediaTypesRequiringUserActionForPlayback = .all
        }
        #endif
        return config
    }
}

// MARK: - Bridge handler

#if canImport(WebKit)
final class MiniAppBridgeHandler: NSObject, WKScriptMessageHandler {
    var currentVideoId: String?
    var currentCreatorId: String?
    var currentUserId: String?
    var displayName: String?

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? String,
              let data = body.data(using: .utf8),
              let msg = try? JSONDecoder().decode(MiniAppBridgeMessage.self, from: data) else { return }

        switch msg.type {
        case .getUser:
            let resp = ["uid": currentUserId ?? "", "displayName": displayName ?? ""]
            reply(to: msg.requestId, result: resp, webView: message.webView)
        case .getVideoContext:
            let resp = ["videoId": currentVideoId ?? "", "creatorId": currentCreatorId ?? ""]
            reply(to: msg.requestId, result: resp, webView: message.webView)
        case .ping:
            reply(to: msg.requestId, result: ["pong": "true"], webView: message.webView)
        default:
            break
        }
    }

    private func reply(to reqId: String, result: [String: String], webView: WKWebView?) {
        guard let json = try? JSONEncoder().encode(result),
              let str = String(data: json, encoding: .utf8) else { return }
        let js = "if(window._mcBridgeCallbacks&&window._mcBridgeCallbacks['\(reqId)']){"
            + "window._mcBridgeCallbacks['\(reqId)'].resolve(\(str));"
            + "delete window._mcBridgeCallbacks['\(reqId)'];}"
        webView?.evaluateJavaScript(js, completionHandler: nil)
    }
}
#endif
