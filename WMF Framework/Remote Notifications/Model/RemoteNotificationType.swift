import Foundation

public enum RemoteNotificationType {
    case userTalkPageMessage
    case mentionInTalkPage
    case mentionInEditSummary
    case successfulMention
    case failedMention
    case editReverted
    case userRightsChange
    case pageReviewed
    case pageLinked
    case connectionWithWikidata
    case emailFromOtherUser
    case thanks
    case translationMilestone(Int)
    case editMilestone
    case welcome
    case loginFailUnknownDevice
    case loginFailKnownDevice
    case loginSuccessUnknownDevice
    case unknownSystem
    case unknown
    
//Possible flow-related notifications to target. Leaving it to default handling for now but we may need to bring these in for special handling.
//    case flowUserTalkPageNewTopic
//    case flowUserTalkPageReply
//    case flowDiscussionNewTopic
//    case flowDiscussionReply
//    case flowMention
//    case flowThanks
}
