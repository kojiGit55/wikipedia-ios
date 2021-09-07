
import Foundation
import WMF

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

    init?(notification: RemoteNotification, languageLinkController: MWKLanguageLinkController) {

        //Validation
        guard let wiki = notification.wiki else {
            return nil
        }
        
        guard notification.sectionType == .alert ||
                notification.sectionType == .message else {
            return nil
        }

        self.notification = notification
        self.iconType = Self.determineIconType(for: notification)
        self.secondaryActionIconType = Self.determineSecondaryActionIconType(for: notification)
        self.projectIconType = Self.determineProjectIconType(for: notification)
        self.titleText = Self.determineTitleText(wiki: wiki, notification: notification, languageLinkController: languageLinkController)
        self.subtitleText = Self.determineSubtitleText(for: notification)
        self.bodyText = Self.determineBodyText(for: notification)
        self.primaryAction = Self.determinePrimaryAction(for: notification)
        self.secondaryAction = Self.determineSecondaryAction(for: notification)
        self.swipeActions = Self.determineSwipeActions(for: notification)
    }
    
    private static func determineIconType(for remoteNotification: RemoteNotification) -> IconType {
        switch remoteNotification.type {
        case .userTalkPageMessage:
            return .singleMessage
        case .mentionInTalkPage,
             .mentionInEditSummary:
            return .tagUser
        case .editReverted:
            return .undo
        case .userRightsChange:
            return .user
        case .thanks:
            return .thanks
        case .editMilestone,
             .welcome:
            return .heart
        default:
            return .unknown
        }
    }
    
    private static func determineSecondaryActionIconType(for remoteNotification: RemoteNotification) -> SecondaryActionIconType {
        //TODO: finish
        return .unknown
    }
    
    private static func determineProjectIconType(for notification: RemoteNotification) -> ProjectIconType {
        //TODO: finish, switch on notification.wiki
        return .unknown
    }
    
    private static func determineTitleText(wiki: String, notification: RemoteNotification, languageLinkController: MWKLanguageLinkController) -> String {
        switch notification.type {
        case .userTalkPageMessage,
             .mentionInTalkPage,
             .mentionInEditSummary,
             .editReverted,
             .userRightsChange,
             .thanks,
             .pageReviewed,
             .pageLinked,
             .connectionWithWikidata,
             .emailFromOtherUser:
            guard let agentName = notification.agentName else {
                return genericTitleText(notification: notification, wiki: wiki, languageLinkController: languageLinkController)
            }

            return agentName

        case .welcome,
             .editMilestone,
             .translationMilestone:
            return projectName(wiki: wiki, languageLinkController: languageLinkController)
        case .successfulMention:
            
            guard let agentName = notification.agentName else {
                return genericTitleText(notification: notification, wiki: wiki, languageLinkController: languageLinkController)
            }
            
            return mentionText(agentName: agentName)
        case .loginFailKnownDevice,
             .loginFailUnknownDevice,
             .loginSuccessUnknownDevice,
             .failedMention:
            return alertText(wiki: wiki, languageLinkController: languageLinkController)
        case .unknown:
            guard let agentName = notification.agentName else {
                return genericTitleText(notification: notification, wiki: wiki, languageLinkController: languageLinkController)
            }

            return agentName
        case .unknownSystem:
            return genericTitleText(notification: notification, wiki: wiki, languageLinkController: languageLinkController)
        }
        
    }
    
    private static func determineSubtitleText(for remoteNotification: RemoteNotification) -> String {
        //TODO: finish
        return "TODO"
    }
    
    private static func determineBodyText(for remoteNotification: RemoteNotification) -> String {
        //TODO: finish
        return "TODO"
    }
    
    private static func determinePrimaryAction(for remoteNotification: RemoteNotification) -> Action {
        //TODO: finish
        return Action(label: "TODO", link: nil)
    }
    
    private static func determineSecondaryAction(for remoteNotification: RemoteNotification) -> Action {
        //TODO: finish
        return Action(label: "TODO", link: nil)
    }
    
    private static func determineSwipeActions(for remoteNotification: RemoteNotification) -> [Action] {
        //TODO: finish
        return [Action(label: "TODO", link: nil),
                Action(label: "TODO", link: nil),
                Action(label: "TODO", link: nil)]
    }
}

//MARK: String determination helpers

private extension NotificationsCenterCellViewModel {
    
    static func projectCode(wiki: String) -> String {
        let suffix = "wiki"
        let projectCode = wiki.hasSuffix(suffix) ? String(wiki.dropLast(suffix.count)) : wiki
        return projectCode
    }
    
    static func wikipediaLanguageLink(projectCode: String, languageLinkController: MWKLanguageLinkController) -> MWKLanguageLink? {
        return languageLinkController.allLanguages.first { $0.languageCode == projectCode }
    }
    
    static func projectName(wiki: String, languageLinkController: MWKLanguageLinkController) -> String {
        
        let projectCode = projectCode(wiki: wiki)

        guard let recognizedLanguage = wikipediaLanguageLink(projectCode: projectCode, languageLinkController: languageLinkController) else {
            //TODO: extra handling for non-language projects (Wikidata, Commons, default)
            return wiki
        }

        let format = WMFLocalizedString("project-name-format", value: "%1$@ %2$@", comment: "Format used for the ordering of project name descriptions. For example, \"English Wikipedia\". Use this format to reorder words or insert additional connecting words. For example, \"%2$@ de la %1$@\" would become \"Wikipedia de la inglés\" for devices set to Spanish. Parameters: %1$@ = localized language name (\"English\"), %2$@ = localized name for Wikipedia (\"Wikipedia\")")

        let localizedLanguageName = recognizedLanguage.localizedName
        return String.localizedStringWithFormat(format, localizedLanguageName, CommonStrings.plainWikipediaName)
    }
    
    static func genericTitleText(notification: RemoteNotification, wiki: String, languageLinkController: MWKLanguageLinkController) -> String {
        switch notification.sectionType {
        case .alert:
            return alertText(wiki: wiki, languageLinkController: languageLinkController)
        case .message:
            return noticeText(wiki: wiki, languageLinkController: languageLinkController)
        default:
            assertionFailure("Invalid section type: Notification center expects notification section type to be either 'alert' or 'message' to display proper generic design. Defaulting to Notice.")
            return noticeText(wiki: wiki, languageLinkController: languageLinkController)
        }
    }
    
    static func textInsertingCodedProjectName(to format: String, wiki: String, languageLinkController: MWKLanguageLinkController) -> String {
        
        let projectCode = projectCode(wiki: wiki)

        guard let recognizedLanguage = wikipediaLanguageLink(projectCode: projectCode, languageLinkController: languageLinkController) else {
            //TODO: extra handling for non-language projects (Wikidata, Commons, default)
            let codedProjectName: String
            switch projectCode {
            default:
                codedProjectName = wiki
            }
            return String.localizedStringWithFormat(format, codedProjectName)
        }

        let codedProjectName = "\(recognizedLanguage.languageCode.localizedUppercase)-\(CommonStrings.plainWikipediaName)"
        return String.localizedStringWithFormat(format, codedProjectName)
        
    }
    
    static func noticeText(wiki: String, languageLinkController: MWKLanguageLinkController) -> String {
        let format = WMFLocalizedString("notifications-notice-project-title", value: "Notice from %1$@", comment: "Header text for login and default notifce notification cell types in Notification Center. %1$@ is replaced with a coded project name such as \"EN-Wikipedia\".")
        return textInsertingCodedProjectName(to: format, wiki: wiki, languageLinkController: languageLinkController)
    }
    
    static func alertText(wiki: String, languageLinkController: MWKLanguageLinkController) -> String {

        let format = WMFLocalizedString("notifications-alert-project-title", value: "Alert from %1$@", comment: "Header text for login and default alert notification cell types in Notification Center. %1$@ is replaced with a coded project name such as \"EN-Wikipedia\".")
        return textInsertingCodedProjectName(to: format, wiki: wiki, languageLinkController: languageLinkController)
    }
    
    static func mentionText(agentName: String) -> String {
        let format = WMFLocalizedString("notifications-mention-title", value: "To: %1$@", comment: "Header text for successful mention notification cell types in Notification Center. %1$@ is replaced with the mentioned username (e.g. To: LadyTanner).")
        return String.localizedStringWithFormat(format, agentName)
    }
}
