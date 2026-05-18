import PDFKit
import Alamofire
import Foundation

/// Generates daily PDF + CSV reports for Command Center: Users, Fraud, Content, Revenue.
@MainActor
final class CommandCenterReportService: ObservableObject {
    static let shared = CommandCenterReportService()

    @Published var isGenerating = false
    @Published var lastGeneratedPDFURL: URL?
    @Published var lastGeneratedCSVURL: URL?

    private let reportsDir: URL = {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CommandCenterReports", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private init() {}

    // MARK: - Daily Report

    func generateDailyReport(metrics: DailyReportData) async -> URL? {
        isGenerating = true
        defer { isGenerating = false }

        let pdfURL = reportsDir.appendingPathComponent("DailyReport_\(dateStamp()).pdf")
        guard let pdf = buildPDF(metrics: metrics) else { return nil }
        pdf.write(to: pdfURL)
        lastGeneratedPDFURL = pdfURL
        AgentLogService.shared.reportGenerated(type: "daily_pdf", rowCount: metrics.userRows.count)
        return pdfURL
    }

    // MARK: - CSV Export

    func exportUsersCSV(rows: [UserReportRow]) async -> URL? {
        isGenerating = true
        defer { isGenerating = false }
        let url = reportsDir.appendingPathComponent("Users_\(dateStamp()).csv")
        var csv = "UserID,DisplayName,Email,SignUpDate,Strikes,Status,TotalVideos\n"
        for row in rows {
            csv += "\(row.userId),\(row.displayName),\(row.email),\(row.signUpDate),\(row.strikeCount),\(row.status),\(row.totalVideos)\n"
        }
        try? csv.write(to: url, atomically: true, encoding: .utf8)
        lastGeneratedCSVURL = url
        AgentLogService.shared.reportGenerated(type: "users_csv", rowCount: rows.count)
        return url
    }

    func exportFraudCSV(rows: [FraudReportRow]) async -> URL? {
        isGenerating = true
        defer { isGenerating = false }
        let url = reportsDir.appendingPathComponent("Fraud_\(dateStamp()).csv")
        var csv = "UserID,Signal,Confidence,DetectedAt,ActionTaken\n"
        for row in rows {
            csv += "\(row.userId),\(row.signal),\(row.confidence),\(row.detectedAt),\(row.actionTaken)\n"
        }
        try? csv.write(to: url, atomically: true, encoding: .utf8)
        lastGeneratedCSVURL = url
        AgentLogService.shared.reportGenerated(type: "fraud_csv", rowCount: rows.count)
        return url
    }

    func exportContentCSV(rows: [ContentReportRow]) async -> URL? {
        isGenerating = true
        defer { isGenerating = false }
        let url = reportsDir.appendingPathComponent("Content_\(dateStamp()).csv")
        var csv = "VideoID,Title,CreatorID,ToxicityScore,Recommendation,ReviewedAt\n"
        for row in rows {
            csv += "\(row.videoId),\(row.title),\(row.creatorId),\(String(format: "%.2f", row.toxicityScore)),\(row.recommendation),\(row.reviewedAt)\n"
        }
        try? csv.write(to: url, atomically: true, encoding: .utf8)
        lastGeneratedCSVURL = url
        AgentLogService.shared.reportGenerated(type: "content_csv", rowCount: rows.count)
        return url
    }

    // MARK: - Share sheet helper

    func shareReport(url: URL) -> [Any] { [url] }

    // MARK: - PDF Builder

    private func buildPDF(metrics: DailyReportData) -> PDFDocument? {
        let pdfMetaData: [CFString: Any] = [
            kCGPDFContextCreator: "MyChannel Command Center",
            kCGPDFContextAuthor: "MyChannel Admin",
            kCGPDFContextTitle: "Daily Platform Report – \(dateStamp())"
        ]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        let data = renderer.pdfData { ctx in
            ctx.beginPage()
            drawPDFContent(context: ctx.cgContext, metrics: metrics, bounds: pageRect)
        }
        return PDFDocument(data: data)
    }

    private func drawPDFContent(context: CGContext, metrics: DailyReportData, bounds: CGRect) {
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 22),
            .foregroundColor: UIColor.black
        ]
        let bodyAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13),
            .foregroundColor: UIColor.darkGray
        ]

        let title = "MyChannel Daily Report — \(dateStamp())"
        title.draw(at: CGPoint(x: 40, y: 40), withAttributes: titleAttrs)

        var y: CGFloat = 90
        let lines = [
            "Total Users:          \(metrics.totalUsers)",
            "New Users Today:      \(metrics.newUsersToday)",
            "Active Now:           \(metrics.activeNow)",
            "Strikes Issued:       \(metrics.strikesIssuedToday)",
            "Bans Today:           \(metrics.bansToday)",
            "Fraud Flags:          \(metrics.fraudFlagsToday)",
            "Videos Uploaded:      \(metrics.videosUploadedToday)",
            "Revenue Today:        $\(String(format: "%.2f", metrics.revenueToday))",
            "Platform Health:      \(String(format: "%.1f%%", metrics.platformHealth * 100))",
        ]
        for line in lines {
            line.draw(at: CGPoint(x: 40, y: y), withAttributes: bodyAttrs)
            y += 24
        }

        y += 20
        "AGI Agents Live: \(metrics.agentsLive) / \(metrics.agentsTotal)".draw(
            at: CGPoint(x: 40, y: y), withAttributes: titleAttrs
        )
    }

    private func dateStamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}

// MARK: - Data Models

struct DailyReportData {
    var totalUsers: Int = 0
    var newUsersToday: Int = 0
    var activeNow: Int = 0
    var strikesIssuedToday: Int = 0
    var bansToday: Int = 0
    var fraudFlagsToday: Int = 0
    var videosUploadedToday: Int = 0
    var revenueToday: Double = 0
    var platformHealth: Double = 1.0
    var agentsLive: Int = 0
    var agentsTotal: Int = 30
    var userRows: [UserReportRow] = []
}

struct UserReportRow {
    let userId: String
    let displayName: String
    let email: String
    let signUpDate: String
    let strikeCount: Int
    let status: String
    let totalVideos: Int
}

struct FraudReportRow {
    let userId: String
    let signal: String
    let confidence: String
    let detectedAt: String
    let actionTaken: String
}

struct ContentReportRow {
    let videoId: String
    let title: String
    let creatorId: String
    let toxicityScore: Double
    let recommendation: String
    let reviewedAt: String
}
