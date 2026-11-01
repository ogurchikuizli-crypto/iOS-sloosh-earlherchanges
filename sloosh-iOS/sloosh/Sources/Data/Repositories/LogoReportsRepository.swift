import Foundation
import SwiftUI
import Combine

public struct LogoReportDto: Identifiable, Codable, Sendable, Equatable {
    public var id: String
    public var mediaId: String
    public var mediaTitle: String
    public var mediaType: String
    public var kpId: Int?
    public var tmdbId: Int?
    public var currentLogoUrl: String?
    public var suggestedLogoUrl: String
    public var suggestedByUid: String
    public var suggestedByName: String
    public var comment: String?
    public var createdAtMs: Int64
    public var status: String

    public init(
        id: String = UUID().uuidString,
        mediaId: String,
        mediaTitle: String,
        mediaType: String,
        kpId: Int? = nil,
        tmdbId: Int? = nil,
        currentLogoUrl: String? = nil,
        suggestedLogoUrl: String,
        suggestedByUid: String = "",
        suggestedByName: String = "",
        comment: String? = nil,
        createdAtMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        status: String = "pending"
    ) {
        self.id = id
        self.mediaId = mediaId
        self.mediaTitle = mediaTitle
        self.mediaType = mediaType
        self.kpId = kpId
        self.tmdbId = tmdbId
        self.currentLogoUrl = currentLogoUrl
        self.suggestedLogoUrl = suggestedLogoUrl
        self.suggestedByUid = suggestedByUid
        self.suggestedByName = suggestedByName
        self.comment = comment
        self.createdAtMs = createdAtMs
        self.status = status
    }
}

@MainActor
public final class LogoReportsRepository: ObservableObject {
    public static let shared = LogoReportsRepository()

    @Published public private(set) var pendingReports: [LogoReportDto] = []
    @Published public private(set) var isLoading: Bool = false

    private let databaseBaseURL = "https://sloosh-77434-default-rtdb.firebaseio.com"

    private init() {}

    private var authQueryParam: String {
        guard let token = AuthRepository.shared.currentUser?.idToken, !token.isEmpty else {
            return ""
        }
        return "?auth=\(token)"
    }

    public func submitReport(
        mediaId: String,
        mediaTitle: String,
        mediaType: String,
        kpId: Int?,
        tmdbId: Int?,
        currentLogoUrl: String?,
        suggestedLogoUrl: String,
        comment: String?
    ) async throws {
        let user = AuthRepository.shared.currentUser
        let uid = user?.id ?? ""
        let name = user?.displayTitle ?? "Пользователь"
        let reportId = UUID().uuidString

        let report = LogoReportDto(
            id: reportId,
            mediaId: mediaId,
            mediaTitle: mediaTitle,
            mediaType: mediaType,
            kpId: kpId,
            tmdbId: tmdbId,
            currentLogoUrl: currentLogoUrl,
            suggestedLogoUrl: suggestedLogoUrl,
            suggestedByUid: uid,
            suggestedByName: name,
            comment: comment,
            createdAtMs: Int64(Date().timeIntervalSince1970 * 1000),
            status: "pending"
        )

        guard let url = URL(string: "\(databaseBaseURL)/logo_reports/\(reportId).json\(authQueryParam)") else {
            throw URLError(.badURL)
        }

        let data = try JSONEncoder().encode(report)
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = data

        let (_, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
    }

    public func fetchReports() async {
        isLoading = true
        defer { isLoading = false }

        guard let url = URL(string: "\(databaseBaseURL)/logo_reports.json\(authQueryParam)") else { return }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return }
            if data.isEmpty || String(data: data, encoding: .utf8) == "null" {
                self.pendingReports = []
                return
            }

            let dict = try JSONDecoder().decode([String: LogoReportDto].self, from: data)
            let reports = dict.values
                .filter { $0.status == "pending" }
                .sorted { $0.createdAtMs > $1.createdAtMs }
            self.pendingReports = reports
        } catch {
            print("[LogoReportsRepository] fetchReports error: \(error)")
        }
    }

    public func approveReport(_ report: LogoReportDto) async -> Bool {
        try? await MediaOverridesRepository.shared.saveOverride(
            mediaId: report.mediaId,
            kpId: report.kpId,
            tmdbId: report.tmdbId,
            title: report.mediaTitle,
            posterUrl: nil,
            logoUrl: report.suggestedLogoUrl,
            backdropUrl: nil,
            backdropUrls: nil
        )

        return await deleteReport(report.id)
    }

    public func rejectReport(_ report: LogoReportDto) async -> Bool {
        return await deleteReport(report.id)
    }

    private func deleteReport(_ reportId: String) async -> Bool {
        guard let url = URL(string: "\(databaseBaseURL)/logo_reports/\(reportId).json\(authQueryParam)") else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            if let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                self.pendingReports.removeAll { $0.id == reportId }
                return true
            }
        } catch {}
        return false
    }
}
