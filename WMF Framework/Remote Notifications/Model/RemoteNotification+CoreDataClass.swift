import Foundation
import CoreData

@objc(RemoteNotification)
public class RemoteNotification: NSManagedObject {
    lazy var type: RemoteNotificationType = {
        return calculateRemoteNotificationType()
    }()
    
    public override func didChangeValue(forKey key: String,
        withSetMutation mutationKind: NSKeyValueSetMutationKind,
        using objects: Set<AnyHashable>) {
        if key == "categoryString" || key == "typeString" {
            type = calculateRemoteNotificationType()
        }
        super.didChangeValue(forKey: key, withSetMutation: mutationKind, using: objects)
    }
}

private extension RemoteNotification {
    func calculateRemoteNotificationType() -> RemoteNotificationType {
        switch (categoryString, typeString) {
        case ("edit-user-talk", "edit-user-talk"):
            return .userTalkPageMessage
        case ("edit-user-talk", "flowusertalk-new-topic"):
            return .flowUserTalkPageNewTopic
        case ("edit-user-talk", "flowusertalk-post-reply"):
            return .flowUserTalkPageReply
        case ("flow-discussion", "flow-new-topic"):
            return .flowDiscussionNewTopic
        case ("flow-discussion", "flow-post-reply"):
            return .flowDiscussionReply
        case ("mention", "mention"):
            return .mentionInTalkPage
        case ("mention", "mention-summary"):
            return .mentionInEditSummary
        case ("mention", "flow-mention"):
            return .flowMention
        case ("mention", "flow-mention"):
            return .flowMention
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
        case ("edit-thank", "edit-thank"):
            return .thanks
        case ("edit-thank", "flow-thank"):
            return .flowThanks
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
    }
}
