
import Foundation

final class NotificationsCenterCellViewModel {
    
    enum IconType {
        case singleMessage
        case doubleMessage
        case tagUser
        case undo
        case user
        case thanks
        case heart
        case exclamationPoint
        case unknown
    }
    
    enum SecondaryActionIconType {
        case user
        case document
        case image
        case lock
        case link
        case unknown
    }
    
    enum ProjectIconType {
        case language(String)
        case commons
        case wikidata
        case unknown
    }
    
    struct Action {
        let label: String
        let link: URL?
    }

    // MARK: - Properties

    private let notification: RemoteNotification
    
    let primaryAction: Action?
    let secondaryAction: Action?
    let swipeActions: [Action]
    let titleText: String
    let subtitleText: String
    let bodyText: String?
    let iconType: IconType
    let secondaryActionIconType: SecondaryActionIconType
    let projectIconType: ProjectIconType

    // MARK: - Lifecycle

    init(notification: RemoteNotification) {
        self.notification = notification
        self.iconType = Self.determineIconType(with: notification)
        self.secondaryActionIconType = Self.determineSecondaryActionIconType(with: notification)
        self.projectIconType = Self.determineProjectIconType(with: notification)
        self.titleText = Self.determineTitleText(with: notification)
        self.subtitleText = Self.determineSubtitleText(with: notification)
        self.bodyText = Self.determineBodyText(with: notification)
        self.primaryAction = Self.determinePrimaryAction(with: notification)
        self.secondaryAction = Self.determineSecondaryAction(with: notification)
        self.swipeActions = Self.determineSwipeActions(with: notification)
    }
    
    private static func determineIconType(with remoteNotification: RemoteNotification) -> IconType {
        switch remoteNotification.type {
        case .userTalkPageMessage,
             .flowUserTalkPageNewTopic,
             .flowDiscussionNewTopic:
            return .singleMessage
        case .flowUserTalkPageReply,
             .flowDiscussionReply:
            return .doubleMessage
        case .mentionInTalkPage,
             .mentionInEditSummary,
             .flowMention:
            return .tagUser
        case .editReverted:
            return .undo
        case .userRightsChange:
            return .user
        case .thanks,
             .flowThanks:
            return .thanks
        case .editMilestone,
             .welcome:
            return .heart
        default:
            return .unknown
        }
    }
    
    private static func determineSecondaryActionIconType(with remoteNotification: RemoteNotification) -> SecondaryActionIconType {
        //TODO: finish
        return .unknown
    }
    
    private static func determineProjectIconType(with notification: RemoteNotification) -> ProjectIconType {
        //TODO: finish, switch on notification.wiki
        return .unknown
    }
    
    private static func determineTitleText(with remoteNotification: RemoteNotification) -> String {
        //TODO: finish
        return "TODO"
    }
    
    private static func determineSubtitleText(with remoteNotification: RemoteNotification) -> String {
        //TODO: finish
        return "TODO"
    }
    
    private static func determineBodyText(with remoteNotification: RemoteNotification) -> String {
        //TODO: finish
        return "TODO"
    }
    
    private static func determinePrimaryAction(with remoteNotification: RemoteNotification) -> Action {
        //TODO: finish
        return Action(label: "TODO", link: nil)
    }
    
    private static func determineSecondaryAction(with remoteNotification: RemoteNotification) -> Action {
        //TODO: finish
        return Action(label: "TODO", link: nil)
    }
    
    private static func determineSwipeActions(with remoteNotification: RemoteNotification) -> [Action] {
        //TODO: finish
        return [Action(label: "TODO", link: nil),
                Action(label: "TODO", link: nil),
                Action(label: "TODO", link: nil)]
    }
}
