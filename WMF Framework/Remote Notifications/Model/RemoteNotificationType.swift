import Foundation

public enum RemoteNotificationType {
    case userTalkPageMessage
    case flowUserTalkPageNewTopic
    case flowUserTalkPageReply
    case flowDiscussionNewTopic
    case flowDiscussionReply
    case mentionInTalkPage
    case mentionInEditSummary
    case flowMention
    case editReverted
    case userRightsChange
    //case pageReviewed
    //case pageLinked
    //case connectionWithWikidata
    case thanks
    case flowThanks
    //case translationMilestone(Int)
    case editMilestone
    case welcome
    //case loginFailUnknownDevice
    //case loginFailKnownDevice
    //case loginSuccessUnknownDevice
    case unknownSystem
    case unknown
}
