
import Foundation

public struct RemoteEchoNotificationResponse: Decodable {
    public let query: RemoteEchoNotificationQuery
}

public struct RemoteEchoNotificationQuery: Decodable {
    public let notifications: RemoteEchoNotificationsList
}

public struct RemoteEchoNotificationsList: Decodable {
    public let list: [RemoteEchoNotification]
    public let continueString: String?
    
    enum CodingKeys: String, CodingKey {
        case list = "list"
        case continueString = "continue"
    }
}

public struct RemoteEchoNotification: Decodable {
    
    public enum EchoType: String, Decodable {
        case editMilestone = "thank-you-edit"
        case reverted
        case editUserTalk = "edit-user-talk"
        case editThank = "edit-thank"
        case flowPostReply = "flow-post-reply"
        case mentionSummary = "mention-summary"
        case mentionTalk = "mention"
        case loginFailKnown = "login-fail-known"
        case mentionFail = "mention-failure"
        case mentionSuccess = "mention-success"
        case welcome = "welcome"
        
        public var notificationTitle: String {
            switch self {
            case .editMilestone:
                return "You just made your Nth edit, keep going!"
            case .editThank:
                return "Someone said thanks!"
            case .editUserTalk:
                return "Someone left you a message."
            case .flowPostReply:
                return "Someone left a message via Flow."
            case .reverted:
                return "Someone has reverted your edit."
            case .mentionSummary:
                return "Someone mentioned you in an edit summary."
            case .mentionTalk:
                return "Someone mentioned you on a talk page."
            case .loginFailKnown:
                return "There have been N attempts to log into your account from a known device."
            case .mentionFail:
                return "Your mention of [username] was not sent."
            case .mentionSuccess:
                return "Your mention to [username] was successfully sent."
            case .welcome:
                return "Welcome to Wikipedia!"
            }
        }
    }
    
    public let wiki: String
    public let id: UInt
    public let type: RemoteEchoNotification.EchoType
    public let timestamp: Date
    public let timestampUnix: String
    public let title: String
    public let agentId: UInt
    public let agentName: String
    public let revId: UInt?
    public let readDate: Date?
    public let header: String
    
    enum OuterKeys: String, CodingKey {
        case wiki
        case id
        case type
        case revId = "revid"
        case readDate = "read"
        case timestamp
        case title
        case agent
        case info = "*"
    }
    
    enum InfoKeys: String, CodingKey {
        case header
    }
    
    enum TimestampKeys: String, CodingKey {
        case utciso8601
        case unix
    }
    
    enum TitleKeys: String, CodingKey {
        case full
    }
    
    enum AgentKeys: String, CodingKey {
        case id
        case name
    }
    
    public init(from decoder: Decoder) throws {
        let outerContainer = try decoder.container(keyedBy: OuterKeys.self)
        let timestampContainer = try outerContainer.nestedContainer(keyedBy: TimestampKeys.self,
                                                                    forKey: .timestamp)
        let titleContainer = try outerContainer.nestedContainer(keyedBy: TitleKeys.self,
                                                                      forKey: .title)
        let agentContainer = try outerContainer.nestedContainer(keyedBy: AgentKeys.self,
                                                                forKey: .agent)
        
        let infoContainer = try outerContainer.nestedContainer(keyedBy: InfoKeys.self, forKey: .info)

        self.wiki = try outerContainer.decode(String.self, forKey: .wiki)
        self.id = try outerContainer.decode(UInt.self, forKey: .id)
        self.type = try outerContainer.decode(EchoType.self, forKey: .type)
        self.revId = try? outerContainer.decode(UInt.self, forKey: .revId)
        let readDateString = try? outerContainer.decode(String.self, forKey: .readDate)
        
        if let readDateString = readDateString {
            self.readDate = DateFormatter.wmf_englishUTCNonDelimitedYearMonthDayHourMinuteSecond()?.date(from: readDateString)
        } else {
            self.readDate = nil
        }
        
        let timestampDate = try timestampContainer.decode(String.self, forKey: .utciso8601)
        let timestampUnixString = try timestampContainer.decode(String.self, forKey: .unix)
        self.timestamp = (timestampDate as NSString).wmf_iso8601Date()
        self.timestampUnix = timestampUnixString
        self.title = try titleContainer.decode(String.self, forKey: .full)
        self.agentId = try agentContainer.decode(UInt.self, forKey: .id)
        self.agentName = try agentContainer.decode(String.self, forKey: .name)
        self.header = try infoContainer.decode(String.self, forKey: .header)
      }
}
