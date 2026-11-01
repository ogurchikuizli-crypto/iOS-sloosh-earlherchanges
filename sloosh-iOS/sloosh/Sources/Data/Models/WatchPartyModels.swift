import Foundation

// MARK: - Watch Party Status

public enum WatchPartyStatus: String, Codable, Sendable, Equatable, Hashable {
    case active = "active"
    case closed = "closed"

    public var isPlayable: Bool {
        self == .active
    }
}

// MARK: - Watch Party Action Type

public enum WatchPartyActionType: String, Codable, Sendable, Equatable, Hashable {
    case play = "play"
    case pause = "pause"
    case seek = "seek"
    case changeEpisode = "change_episode"
    case changeSpeed = "change_speed"
    case leave = "leave"
}

// MARK: - Watch Party Playback State

public struct WatchPartyPlayback: Codable, Sendable, Equatable, Hashable {
    public var isPlaying: Bool
    public var positionSec: Double
    public var updatedAtMs: Int64
    public var lastActionByUid: String
    public var lastActionByName: String
    public var actionType: WatchPartyActionType
    public var actionTargetTime: Double?
    public var scheduledStartMs: Int64?
    public var speed: Float

    public init(
        isPlaying: Bool,
        positionSec: Double,
        updatedAtMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        lastActionByUid: String = "",
        lastActionByName: String = "",
        actionType: WatchPartyActionType = .play,
        actionTargetTime: Double? = nil,
        scheduledStartMs: Int64? = nil,
        speed: Float = 1.0
    ) {
        self.isPlaying = isPlaying
        self.positionSec = positionSec
        self.updatedAtMs = updatedAtMs
        self.lastActionByUid = lastActionByUid
        self.lastActionByName = lastActionByName
        self.actionType = actionType
        self.actionTargetTime = actionTargetTime
        self.scheduledStartMs = scheduledStartMs
        self.speed = speed
    }

    private enum CodingKeys: String, CodingKey {
        case isPlaying
        case positionSec
        case updatedAtMs
        case lastActionByUid
        case lastActionByName
        case actionType
        case actionTargetTime
        case scheduledStartMs
        case speed
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.isPlaying = try container.decode(Bool.self, forKey: .isPlaying)
        self.positionSec = try container.decode(Double.self, forKey: .positionSec)
        self.updatedAtMs = try container.decode(Int64.self, forKey: .updatedAtMs)
        self.lastActionByUid = try container.decodeIfPresent(String.self, forKey: .lastActionByUid) ?? ""
        self.lastActionByName = try container.decodeIfPresent(String.self, forKey: .lastActionByName) ?? ""
        self.actionType = try container.decodeIfPresent(WatchPartyActionType.self, forKey: .actionType) ?? .play
        self.actionTargetTime = try container.decodeIfPresent(Double.self, forKey: .actionTargetTime)
        self.scheduledStartMs = try container.decodeIfPresent(Int64.self, forKey: .scheduledStartMs)
        self.speed = try container.decodeIfPresent(Float.self, forKey: .speed) ?? 1.0
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isPlaying, forKey: .isPlaying)
        try container.encode(positionSec, forKey: .positionSec)
        try container.encode(updatedAtMs, forKey: .updatedAtMs)
        try container.encode(lastActionByUid, forKey: .lastActionByUid)
        try container.encode(lastActionByName, forKey: .lastActionByName)
        try container.encode(actionType, forKey: .actionType)
        try container.encodeIfPresent(actionTargetTime, forKey: .actionTargetTime)
        try container.encodeIfPresent(scheduledStartMs, forKey: .scheduledStartMs)
        try container.encode(speed, forKey: .speed)
    }

    /// Computes the exact target position at a given current timestamp (Clock Sync formula).
    public func targetPosition(at currentTimestampMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000)) -> Double {
        if !isPlaying {
            return max(0, positionSec)
        }
        let effectiveStartMs = scheduledStartMs ?? updatedAtMs
        if currentTimestampMs < effectiveStartMs {
            return max(0, positionSec)
        }
        let elapsedSec = max(0, Double(currentTimestampMs - effectiveStartMs) / 1000.0)
        let effectiveSpeed = Double(speed > 0 ? speed : 1.0)
        return max(0, positionSec + (elapsedSec * effectiveSpeed))
    }

    /// Calculates drift between local player position and calculated target position.
    /// Positive drift means local player is ahead; negative means local player is behind.
    public func drift(localCurrentTime: Double, currentTimestampMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000)) -> Double {
        return localCurrentTime - targetPosition(at: currentTimestampMs)
    }
}

// MARK: - Watch Party Session

public struct WatchPartySession: Identifiable, Codable, Sendable, Equatable, Hashable {
    public var id: String // partyId
    public var chatId: String?
    public var hostUid: String
    public var hostName: String
    public var hostAvatarUrl: String?
    public var guestUid: String?
    public var guestName: String?
    public var guestAvatarUrl: String?
    public var mediaId: String
    public var mediaType: String
    public var title: String
    public var posterUrl: String?
    public var season: Int?
    public var episode: Int?
    public var translationId: Int?
    public var translationName: String?
    public var streamSource: String?
    public var playback: WatchPartyPlayback
    public var status: WatchPartyStatus
    public var createdAtMs: Int64
    public var updatedAtMs: Int64

    public init(
        id: String = UUID().uuidString,
        chatId: String? = nil,
        hostUid: String,
        hostName: String,
        hostAvatarUrl: String? = nil,
        guestUid: String? = nil,
        guestName: String? = nil,
        guestAvatarUrl: String? = nil,
        mediaId: String,
        mediaType: String,
        title: String,
        posterUrl: String? = nil,
        season: Int? = nil,
        episode: Int? = nil,
        translationId: Int? = nil,
        translationName: String? = nil,
        streamSource: String? = nil,
        playback: WatchPartyPlayback,
        status: WatchPartyStatus = .active,
        createdAtMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        updatedAtMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    ) {
        self.id = id
        self.chatId = chatId
        self.hostUid = hostUid
        self.hostName = hostName
        self.hostAvatarUrl = hostAvatarUrl
        self.guestUid = guestUid
        self.guestName = guestName
        self.guestAvatarUrl = guestAvatarUrl
        self.mediaId = mediaId
        self.mediaType = mediaType
        self.title = title
        self.posterUrl = posterUrl
        self.season = season
        self.episode = episode
        self.translationId = translationId
        self.translationName = translationName
        self.streamSource = streamSource
        self.playback = playback
        self.status = status
        self.createdAtMs = createdAtMs
        self.updatedAtMs = updatedAtMs
    }

    public var displaySubtitle: String {
        var parts: [String] = []
        if let s = season, let e = episode {
            parts.append("Сезон \(s), Серия \(e)")
        }
        if let tr = translationName, !tr.isEmpty {
            parts.append(tr)
        }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Watch Party Invite Payload (For Chat Messages)

public struct WatchPartyInvitePayload: Identifiable, Codable, Sendable, Equatable, Hashable {
    public var id: String { partyId }
    public let partyId: String
    public let chatId: String?
    public let mediaId: String
    public let mediaType: String
    public let title: String
    public let posterUrl: String?
    public let season: Int?
    public let episode: Int?
    public let translationName: String?
    public var status: WatchPartyStatus

    public init(
        partyId: String,
        chatId: String? = nil,
        mediaId: String,
        mediaType: String,
        title: String,
        posterUrl: String? = nil,
        season: Int? = nil,
        episode: Int? = nil,
        translationName: String? = nil,
        status: WatchPartyStatus = .active
    ) {
        self.partyId = partyId
        self.chatId = chatId
        self.mediaId = mediaId
        self.mediaType = mediaType
        self.title = title
        self.posterUrl = posterUrl
        self.season = season
        self.episode = episode
        self.translationName = translationName
        self.status = status
    }
}

// MARK: - Watch Party Chat Message

/// A text message sent inside an active watch party (`watch_parties/{partyId}/chat/{messageId}`).
public struct WatchPartyChatMessage: Identifiable, Codable, Sendable, Equatable, Hashable {
    public var id: String
    public var uid: String
    public var name: String
    public var text: String
    public var createdAtMs: Int64

    public init(id: String, uid: String, name: String, text: String, createdAtMs: Int64) {
        self.id = id
        self.uid = uid
        self.name = name
        self.text = text
        self.createdAtMs = createdAtMs
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case uid
        case name
        case text
        case createdAtMs
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.uid = try container.decodeIfPresent(String.self, forKey: .uid) ?? ""
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
        self.createdAtMs = try container.decodeIfPresent(Int64.self, forKey: .createdAtMs) ?? 0
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(uid, forKey: .uid)
        try container.encode(name, forKey: .name)
        try container.encode(text, forKey: .text)
        try container.encode(createdAtMs, forKey: .createdAtMs)
    }
}

// MARK: - Watch Party Timecodes

/// A piece of chat text: either plain text or a detected timecode (e.g. `12:34`, `1:02:03`).
public enum WatchPartyTimecodeSegment: Sendable, Equatable, Hashable {
    case text(String)
    case timecode(String, Double)
}

public enum WatchPartyTimecode {
    /// Formats seconds as `m:ss` or `h:mm:ss`.
    public static func format(_ totalSeconds: Double) -> String {
        let safe = totalSeconds.isFinite ? max(0, totalSeconds) : 0
        let sec = Int(safe)
        let h = sec / 3600
        let m = (sec % 3600) / 60
        let s = sec % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    /// Parses `m:ss` / `mm:ss` / `h:mm:ss` into seconds. Returns nil if the token is not a valid timecode.
    public static func seconds(from token: String) -> Double? {
        let parts = token.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 2 || parts.count == 3 else { return nil }
        for part in parts {
            guard !part.isEmpty, part.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        }
        for part in parts.dropFirst() {
            guard part.count == 2 else { return nil }
        }
        let values = parts.compactMap { Int($0) }
        guard values.count == parts.count else { return nil }

        if values.count == 2 {
            guard parts[0].count <= 3, values[1] < 60 else { return nil }
            return Double(values[0] * 60 + values[1])
        }
        guard parts[0].count <= 2, values[1] < 60, values[2] < 60 else { return nil }
        return Double(values[0] * 3600 + values[1] * 60 + values[2])
    }

    /// Splits text into plain and timecode segments.
    public static func segments(in text: String) -> [WatchPartyTimecodeSegment] {
        var result: [WatchPartyTimecodeSegment] = []
        var buffer = ""
        var run = ""

        func flushRun() {
            guard !run.isEmpty else { return }
            var core = Substring(run)
            var leading = ""
            var trailing = ""
            while core.first == ":" {
                leading.append(":")
                core = core.dropFirst()
            }
            while core.last == ":" {
                trailing.append(":")
                core = core.dropLast()
            }
            buffer += leading
            let token = String(core)
            if let secs = seconds(from: token) {
                if !buffer.isEmpty {
                    result.append(.text(buffer))
                    buffer = ""
                }
                result.append(.timecode(token, secs))
            } else {
                buffer += token
            }
            buffer += trailing
            run = ""
        }

        for character in text {
            if character.isASCII && (character.isNumber || character == ":") {
                run.append(character)
            } else {
                flushRun()
                buffer.append(character)
            }
        }
        flushRun()
        if !buffer.isEmpty {
            result.append(.text(buffer))
        }
        return result
    }
}
