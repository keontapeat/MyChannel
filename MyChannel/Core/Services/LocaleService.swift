//
//  LocaleService.swift
//  MyChannel
//
//  Phase 61: 40-locale launch scaffolding.
//  Complements `MultiLanguageService`. Responsible for: RTL detection,
//  locale override, fallback chain, and remote-translation fetching for
//  user-generated content (video titles, descriptions, comments) via
//  the `aiTranslation` Cloud Run agent.
//

import Foundation

enum SupportedLocale: String, CaseIterable, Codable {
    // Tier 1 — day-one
    case en_US, en_GB, en_CA, en_AU
    case es_ES, es_MX, es_AR
    case pt_BR, pt_PT
    case fr_FR, fr_CA
    case de_DE, it_IT, nl_NL
    case ja_JP, ko_KR
    case zh_CN, zh_TW, zh_HK
    case ru_RU, pl_PL, tr_TR
    case ar_SA, he_IL                 // RTL
    case hi_IN, bn_IN, ta_IN, mr_IN
    case th_TH, id_ID, vi_VN, ms_MY, fil_PH
    case sv_SE, no_NO, da_DK, fi_FI
    case uk_UA, cs_CZ, el_GR
    case ro_RO

    var isRightToLeft: Bool {
        switch self {
        case .ar_SA, .he_IL: return true
        default: return false
        }
    }

    var bcp47: String { rawValue.replacingOccurrences(of: "_", with: "-") }

    /// Fallback chain: `es_MX → es_ES → en_US`.
    var fallbackChain: [SupportedLocale] {
        let parts = rawValue.split(separator: "_")
        let base = parts.first.map(String.init) ?? rawValue
        let sameLanguage = SupportedLocale.allCases.filter { $0.rawValue.hasPrefix(base + "_") && $0 != self }
        return [self] + sameLanguage + [.en_US]
    }
}

@MainActor
final class LocaleService: ObservableObject {
    static let shared = LocaleService()
    private init() { resolveFromSystem() }

    @Published private(set) var active: SupportedLocale = .en_US

    // MARK: - Resolution

    private func resolveFromSystem() {
        let system = Locale.current.identifier                     // e.g. en_US
        if let match = SupportedLocale(rawValue: system) { active = match; return }
        let language = Locale.current.language.languageCode?.identifier ?? "en"
        active = SupportedLocale.allCases.first(where: { $0.rawValue.hasPrefix(language + "_") }) ?? .en_US
    }

    func override(_ locale: SupportedLocale) {
        active = locale
        UserDefaults.standard.set(locale.rawValue, forKey: "user.localeOverride")
    }

    // MARK: - UGC translation

    /// Translate arbitrary UGC text to the active locale. Used in title/description
    /// rendering and comment threads when the source language ≠ active.
    func translate(_ text: String, from sourceBCP47: String?) async throws -> String {
        guard AppConfig.Features.enableFullLocalization else { return text }
        struct Request: Encodable {
            let task: String
            let text: String
            let source: String?
            let target: String
        }
        struct Raw: Decodable { let translated: String? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .aiTranslation,
            path: "/predict",
            body: Request(task: "translate", text: text, source: sourceBCP47, target: active.bcp47)
        )
        return r.translated ?? text
    }
}
