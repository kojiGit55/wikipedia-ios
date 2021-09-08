
import Foundation
import WMF

final class NotificationsCenterCellViewModel {
    
    enum IconType {
        case singleMessage
        case doubleMessage
        case atSymbol
        case undo
        case user
        case checkbox
        case link
        case thanks
        case heart
        case exclamationPoint
        case email
        case bell
    }
    
    enum FooterIconType {
        case user
        case document
        case image
        case lock
        case link
        case none
    }
    
    enum ProjectIconType {
        case language(String)
        case commons
        case wikidata
    }
    
    struct Action {
        let label: String
        let destination: Router.Destination?
    }

    // MARK: - Properties

    private let notification: RemoteNotification
    
    let primaryDestination: Router.Destination
    let secondaryDestination: Router.Destination?
    let swipeActions: [Action]
    let titleText: String
    let subtitleText: String?
    let bodyText: String?
    let footerText: String?
    let iconType: IconType
    let footerIconType: FooterIconType?
    let projectIconType: ProjectIconType

    // MARK: - Lifecycle

    init?(notification: RemoteNotification, languageLinkController: MWKLanguageLinkController) {

        //Validation
        guard let wiki = notification.wiki else {
            return nil
        }
        
        guard let iconType = Self.determineIconType(for: notification) else {
            return nil
        }
        
        guard let projectIconType = Self.determineProjectIconType(wiki: wiki, languageLinkController: languageLinkController) else {
            return nil
        }

        self.notification = notification
        self.iconType = iconType
        self.footerIconType = Self.determineFooterIconType(for: notification)
        self.projectIconType = projectIconType
        self.titleText = Self.determineTitleText(wiki: wiki, notification: notification, languageLinkController: languageLinkController)
        self.subtitleText = Self.determineSubtitleText(for: notification)
        self.bodyText = Self.determineBodyText(for: notification)
        self.footerText = Self.determineFooterText(for: notification)
        self.primaryDestination = Self.determinePrimaryDestination(for: notification)
        self.secondaryDestination = Self.determineSecondaryDestination(for: notification)
        self.swipeActions = Self.determineSwipeActions(for: notification)
    }
    
    private static func determineIconType(for remoteNotification: RemoteNotification) -> IconType? {
        switch remoteNotification.type {
        case .userTalkPageMessage:
            return .singleMessage
        case .mentionInTalkPage,
             .mentionInEditSummary,
             .successfulMention,
             .failedMention:
            return .atSymbol
        case .editReverted:
            return .undo
        case .userRightsChange:
            return .user
        case .pageReviewed:
            return .checkbox
        case .pageLinked,
             .connectionWithWikidata:
            return .link
        case .thanks:
            return .thanks
        case .editMilestone,
             .translationMilestone,
             .welcome:
            return .heart
        case .loginFailKnownDevice,
             .loginFailUnknownDevice,
             .loginSuccessUnknownDevice:
            return .exclamationPoint
        case .emailFromOtherUser:
            return .email
        case .unknownSystem,
             .unknown:
            switch remoteNotification.sectionType {
            case .alert:
                return .bell
            case .message:
                return .exclamationPoint
            default:
                return nil
            }
        }
    }
    
    private static func determineFooterIconType(for remoteNotification: RemoteNotification) -> FooterIconType {
        
        switch remoteNotification.type {
        case .userRightsChange:
            return .document
        case .loginFailKnownDevice,
             .loginFailUnknownDevice,
             .loginSuccessUnknownDevice:
            return .lock
        case .emailFromOtherUser,
             .welcome:
            return .none
        case .unknown,
             .unknownSystem:
            return .link
        default:
            break
        }
        
        switch remoteNotification.namespace {
        case .main, .talk:
            return .document
        case .userTalk:
            return .user
        case .file:
            return .image
        default:
            break
        }
        
        return .none
    }
    
    private static func determineProjectIconType(wiki: String, languageLinkController: MWKLanguageLinkController) -> ProjectIconType? {
        let projectCode = projectCode(wiki: wiki)
        if let _ = wikipediaLanguageLink(projectCode: projectCode, languageLinkController: languageLinkController) {
            //recognized language code
            return .language(projectCode)
        } else {
            switch projectCode {
            case "commons":
                return .commons
            case "wikidata":
                return .wikidata
            default:
                return nil
            }
        }
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
    
    private static func determineSubtitleText(for remoteNotification: RemoteNotification) -> String? {
        switch remoteNotification.type {
        case .userTalkPageMessage:
            if let topicTitle = topicTitleFromTalkPageMessage(notification: remoteNotification) {
                return topicTitle
            } else {
                return WMFLocalizedString("notifications-subtitle-talk-page-message", value: "Message on your talk page", comment: "Subtitle text for talk page message notification views in Notification Center.")
            }
        case .mentionInTalkPage:
            if let topicTitle = topicTitleFromTalkPageMessage(notification: remoteNotification) {
                return topicTitle
            } else {
                if remoteNotification.namespace == .talk {
                    return WMFLocalizedString("notifications-subtitle-mention-article-talk-page", value: "Mention on article talk page", comment: "Subtitle text for Talk namespace mention notification views in Notification Center.")
                } else {
                    //TODO: Should we target other talk page types and have a more specific string? See PageNamespace options.
                    return WMFLocalizedString("notifications-subtitle-mention-talk-page", value: "Mention on talk page", comment: "Subtitle text for non-Talk namespace mention notification views in Notification Center.")
                }
                
            }
        case .mentionInEditSummary:
            return WMFLocalizedString("notifications-subtitle-mention-edit-summary", value: "Mention in edit summary", comment: "Subtitle text for 'mention in edit summary' notification views in Notification Center.")
        case .successfulMention:
            return WMFLocalizedString("notifications-subtitle-mention-successful", value: "Successful mention", comment: "Subtitle text for successful mention notification views in Notification Center.")
        case .failedMention:
            return WMFLocalizedString("notifications-subtitle-mention-failed", value: "Failed mention", comment: "Subtitle text for failed mention notification views in Notification Center.")
        case .editReverted:
            return WMFLocalizedString("notifications-subtitle-edit-reverted", value: "Your edit was reverted", comment: "Subtitle text for edit reverted notification views in Notification Center.")
        case .userRightsChange:
            return WMFLocalizedString("notifications-subtitle-user-rights-change", value: "User rights change", comment: "Subtitle text for user rights change notification views in Notification Center.")
        case .pageReviewed:
            return WMFLocalizedString("notifications-subtitle-page-reviewed", value: "Page reviewed", comment: "Subtitle text for page reviewed notification views in Notification Center.")
        case .pageLinked:
            return WMFLocalizedString("notifications-subtitle-page-link", value: "Page link", comment: "Subtitle text for page link notification views in Notification Center.")
        case .connectionWithWikidata:
            return WMFLocalizedString("notifications-subtitle-wikidata-connection", value: "Wikidata connection made", comment: "Subtitle text for 'Wikidata connection made' views in Notification Center.")
        case .emailFromOtherUser:
            return WMFLocalizedString("notifications-subtitle-email-from-other-user", value: "New email", comment: "Subtitle text for 'email from other user' notification views in Notification Center.")
        case .thanks:
            return WMFLocalizedString("notifications-subtitle-thanks", value: "Thanks", comment: "Subtitle text for thanks notification views in Notification Center.")
        case .translationMilestone(_):
            return WMFLocalizedString("notifications-subtitle-translate-milestone", value: "Translation milestone", comment: "Subtitle text for translation milestone notification views in Notification Center.")
        case .editMilestone:
            return WMFLocalizedString("notifications-subtitle-edit-milestone", value: "Editing milestone", comment: "Subtitle text for edit milestone notification views in Notification Center.")
        case .welcome:
            return WMFLocalizedString("notifications-subtitle-welcome", value: "Translation milestone", comment: "Subtitle text for welcome notification views in Notification Center.")
        case .loginFailUnknownDevice:
            return WMFLocalizedString("notifications-subtitle-login-fail-unknown-device", value: "Failed log in attempt", comment: "Subtitle text for 'Failed login from an unknown device' notification views in Notification Center.")
        case .loginFailKnownDevice:
            return WMFLocalizedString("notifications-subtitle-login-fail-known-device", value: "Multiple failed log in attempts", comment: "Subtitle text for 'Failed login from a known device' notification views in Notification Center.")
        case .loginSuccessUnknownDevice:
            return WMFLocalizedString("notifications-subtitle-login-success-unknown-device", value: "Log in from an unfamiliar device", comment: "Subtitle text for 'Successful login from an unknown device' notification views in Notification Center.")
        case .unknownSystem,
             .unknown:
            return remoteNotification.messageHeader?.removingHTML ?? remoteNotification.messageBody?.removingHTML
        }
    }
    
    private static func determineBodyText(for remoteNotification: RemoteNotification) -> String? {
        switch remoteNotification.type {
        case .userTalkPageMessage:
            return remoteNotification.messageBody?.removingHTML
        case .mentionInTalkPage:
            return remoteNotification.messageBody?.removingHTML
        case .mentionInEditSummary:
            return remoteNotification.messageBody?.removingHTML
        case .successfulMention:
            return remoteNotification.messageHeader?.removingHTML
        case .failedMention:
            return remoteNotification.messageHeader?.removingHTML
        case .editReverted:
            return nil
        case .userRightsChange:
            return remoteNotification.messageHeader?.removingHTML
        case .pageReviewed:
            return remoteNotification.messageHeader?.removingHTML
        case .pageLinked:
            return remoteNotification.messageHeader?.removingHTML
        case .connectionWithWikidata:
            return remoteNotification.messageHeader?.removingHTML
        case .emailFromOtherUser:
            return remoteNotification.messageHeader?.removingHTML
        case .thanks:
            return remoteNotification.messageHeader?.removingHTML
        case .translationMilestone:
            return remoteNotification.messageHeader?.removingHTML
        case .editMilestone:
            return remoteNotification.messageHeader?.removingHTML
        case .welcome:
            return remoteNotification.messageHeader?.removingHTML
        case .loginFailUnknownDevice:
            return remoteNotification.messageHeader?.removingHTML
        case .loginFailKnownDevice:
            return remoteNotification.messageHeader?.removingHTML
        case .loginSuccessUnknownDevice:
            return remoteNotification.messageHeader?.removingHTML
        case .unknownSystem:
            return remoteNotification.messageBody?.removingHTML
        case .unknown:
            return remoteNotification.messageBody?.removingHTML
        }
    }
    
    private static func determineFooterText(for remoteNotification: RemoteNotification) -> String? {
        switch remoteNotification.type {
        case .welcome,
             .emailFromOtherUser:
            return nil
        case .loginFailKnownDevice,
             .loginFailUnknownDevice,
             .loginSuccessUnknownDevice:
            return WMFLocalizedString("notifications-footer-change-password", value: "Change password", comment: "Footer text for login-related notification views in Notification Center. Indicates that the user should consider changing their password.")
        case .unknown,
             .unknownSystem:
            guard let primaryLinkTitle = remoteNotification.messageLinks?.primary?.label else {
                return nil
            }
            
            return primaryLinkTitle
        case .userTalkPageMessage,
             .mentionInTalkPage,
             .mentionInEditSummary,
             .successfulMention,
             .failedMention,
             .editReverted,
             .userRightsChange,
             .pageReviewed,
             .pageLinked,
            .connectionWithWikidata,
            .thanks,
            .translationMilestone,
            .editMilestone:
            return remoteNotification.titleFull
        }
    }
    
    private static func determinePrimaryDestination(for remoteNotification: RemoteNotification) -> Router.Destination {
        //TODO: finish
        return .externalLink(URL(string:"https://en.wikipedia.org")!)
    }
    
    private static func determineSecondaryDestination(for remoteNotification: RemoteNotification) -> Router.Destination? {
        //TODO: finish
        return .externalLink(URL(string:"https://en.wikipedia.org")!)
    }
    
    private static func determineSwipeActions(for remoteNotification: RemoteNotification) -> [Action] {
        //TODO: finish
        return [Action(label: "TODO", destination: nil),
                Action(label: "TODO", destination: nil),
                Action(label: "TODO", destination: nil)]
    }
}

//MARK: String determination helpers

private extension NotificationsCenterCellViewModel {
    
    static func topicTitleFromTalkPageMessage(notification: RemoteNotification) -> String? {
        guard let primaryUrl = notification.messageLinks?.primary?.url else {
            return nil
        }
        
        let components = URLComponents(url: primaryUrl, resolvingAgainstBaseURL: false)
        guard let fragment = components?.fragment else {
            return nil
        }
        
        return fragment.removingPercentEncoding?.replacingOccurrences(of: "_", with: " ")
    }
    
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

        let format = WMFLocalizedString("notifications-title-project-name-format", value: "%1$@ %2$@", comment: "Format used for the ordering of project name descriptions. This description is displayed as the title text of notification views in Notification Center. For example, \"English Wikipedia\". Use this format to reorder words or insert additional connecting words. For example, \"%2$@ de la %1$@\" would become \"Wikipedia de la inglés\" for devices set to Spanish. Parameters: %1$@ = localized language name (\"English\"), %2$@ = localized name for Wikipedia (\"Wikipedia\")")

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
        let format = WMFLocalizedString("notifications-title-notice-project", value: "Notice from %1$@", comment: "Title text for login and default notifce notification views in Notification Center. %1$@ is replaced with a coded project name such as \"EN-Wikipedia\".")
        return textInsertingCodedProjectName(to: format, wiki: wiki, languageLinkController: languageLinkController)
    }
    
    static func alertText(wiki: String, languageLinkController: MWKLanguageLinkController) -> String {

        let format = WMFLocalizedString("notifications-title-alert-project", value: "Alert from %1$@", comment: "Title text for login and default alert notification views in Notification Center. %1$@ is replaced with a coded project name such as \"EN-Wikipedia\".")
        return textInsertingCodedProjectName(to: format, wiki: wiki, languageLinkController: languageLinkController)
    }
    
    static func mentionText(agentName: String) -> String {
        let format = WMFLocalizedString("notifications-title-mention", value: "To: %1$@", comment: "Title text for successful mention notification views in Notification Center. %1$@ is replaced with the mentioned username (e.g. To: LadyTanner).")
        return String.localizedStringWithFormat(format, agentName)
    }
}
