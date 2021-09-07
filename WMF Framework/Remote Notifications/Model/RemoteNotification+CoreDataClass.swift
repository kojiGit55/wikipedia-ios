import Foundation
import CoreData

@objc(RemoteNotification)
public class RemoteNotification: NSManagedObject {
    public lazy var type: RemoteNotificationType = {
        return calculateRemoteNotificationType()
    }()
    
    public lazy var sectionType: RemoteNotificationSectionType = {
        return calculateRemoteNotificationSectionType()
    }()
    
    public override func didChangeValue(forKey key: String,
        withSetMutation mutationKind: NSKeyValueSetMutationKind,
        using objects: Set<AnyHashable>) {
        if key == "categoryString" || key == "typeString" {
            type = calculateRemoteNotificationType()
        } else if key == "section" {
            sectionType = calculateRemoteNotificationSectionType()
        }
        super.didChangeValue(forKey: key, withSetMutation: mutationKind, using: objects)
    }
}

private extension RemoteNotification {
    func calculateRemoteNotificationType() -> RemoteNotificationType {
        switch (categoryString, typeString) {
        case ("edit-user-talk", "edit-user-talk"):
            return .userTalkPageMessage
        case ("mention", "mention"):
            return .mentionInTalkPage
        case ("mention", "mention-summary"):
            return .mentionInEditSummary
        case ("mention-success", "mention-success"):
            return .successfulMention
        case ("mention-failure", "mention-failure"),
             ("mention-failure", "mention-failure-too-many"):
            return .failedMention
        case ("reverted", "reverted"):
            return .editReverted
        case ("user-rights", "user-rights"):
            return .userRightsChange
        case ("page-review", "pagetriage-mark-as-reviewed"):
            return .pageReviewed
        case ("article-linked", "page-linked"):
            return .pageLinked
        case ("wikibase-action", "page-connection"):
            return .connectionWithWikidata
        case ("emailuser", "emailuser"):
            return .emailFromOtherUser
        case ("edit-thank", "edit-thank"):
            return .thanks
        case ("cx", "cx-first-translation"):
            return .translationMilestone(1)
        case ("cx", "cx-tenth-translation"):
            return .translationMilestone(10)
        case ("cx", "cx-hundredth-translation"):
            return .translationMilestone(100)
        case ("thank-you-edit", "thank-you-edit"):
            return .editMilestone
        case ("system-noemail", "welcome"):
            return .welcome
        case ("login-fail", "login-fail-new"):
            return .loginFailUnknownDevice
        case ("login-fail", "login-fail-known"):
            return .loginFailKnownDevice
        case ("login-success", "login-success"):
            return .loginSuccessUnknownDevice
        case ("system", _),
             ("system-noemail", _),
             ("system-emailonly", _):
            return .unknownSystem
        default:
            return .unknown
        }
        
//Possible flow-related notifications to target. Leaving it to default handling for now but we may need to bring these in for special handling.
//        case ("edit-user-talk", "flowusertalk-new-topic"):
//            return .flowUserTalkPageNewTopic
//        case ("edit-user-talk", "flowusertalk-post-reply"):
//            return .flowUserTalkPageReply
//        case ("flow-discussion", "flow-new-topic"):
//            return .flowDiscussionNewTopic
//        case ("flow-discussion", "flow-post-reply"):
//            return .flowDiscussionReply
//        case ("mention", "flow-mention"):
//            return .flowMention
//        case ("edit-thank", "flow-thank"):
//            return .flowThanks
    }
    
    func calculateRemoteNotificationSectionType() -> RemoteNotificationSectionType {
        guard let section = self.section else {
            return .unknown
        }
        return RemoteNotificationSectionType(rawValue: section) ?? .unknown
    }
}
