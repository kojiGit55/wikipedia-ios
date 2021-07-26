
import UserNotifications
import WMF

class NotificationService: UNNotificationServiceExtension {

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?
    //note: this may not fly with analytics.
    let session = Session(configuration: Configuration.current)
    lazy var echoFetcher = {
        return EchoNotificationsFetcher(session: session, configuration: Configuration.current)
    }()
    lazy var authManager = {
        return WMFAuthenticationManager(session: session, configuration: Configuration.current)
    }()
    
    private let fallbackTitle = "Heyo"
    private let fallbackBody = "There might be a new notification to look at, check it out!"
    private let fallbackBodyMultiple = "There are for sure multiple new notifications to look at, check it out!"
    private let displayedPushIdKey = "displayedPushIds"

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        
        if let bestAttemptContent = bestAttemptContent {
            // Modify the notification content here...
            
            //todo: look into better credentials storing
            authManager.loginWithSavedCredentials(completion: { result in
                switch result {
                case .alreadyLoggedIn, .success:
                    //todo: pull project filters and subdomain from cache
                    self.echoFetcher.fetchNotifications(projectFilters: ["enwiki", "wikidatawiki"], subdomain: "en", continueId: nil) { result in
                        
                        DispatchQueue.main.async {
                            switch result {
                            case .success(let response):
                                
                                //only consider notifications from the last 10 minutes
                                let cutoffDate = Date().addingTimeInterval(TimeInterval(-60 * 10))
                                let recentNotifications = response.notifications.filter { $0.timestamp > cutoffDate }
                                
                                //only consider those that haven't already been displayed as a push
                                var neverDisplayedNotifications: [RemoteEchoNotification] = recentNotifications
                                var displayedPushIds = UserDefaults.standard.object(forKey: self.displayedPushIdKey) as? [UInt]
                                if let displayedPushIds = displayedPushIds {
                                    neverDisplayedNotifications = recentNotifications.filter { !displayedPushIds.contains($0.id) }
                                }
                                
                                if neverDisplayedNotifications.count > 1 {
                                    bestAttemptContent.title = self.fallbackTitle
                                    bestAttemptContent.subtitle = "subtitle"
                                    bestAttemptContent.categoryIdentifier = "awesomeNotification"
                                    bestAttemptContent.body = self.fallbackBodyMultiple
                                    
                                    for notification in neverDisplayedNotifications {
                                        if displayedPushIds == nil {
                                            displayedPushIds = []
                                        }
                                        displayedPushIds?.append(notification.id)
                                        UserDefaults.standard.setValue(displayedPushIds, forKey: self.displayedPushIdKey)
                                    }
                                } else if let mostRecentNotification = neverDisplayedNotifications.last {
                                    bestAttemptContent.title = mostRecentNotification.type.notificationTitle
                                    bestAttemptContent.body = mostRecentNotification.header
                                    bestAttemptContent.subtitle = "subtitle"
                                    bestAttemptContent.categoryIdentifier = "awesomeNotification"
                                    if displayedPushIds == nil {
                                        displayedPushIds = []
                                    }
                                    displayedPushIds?.append(mostRecentNotification.id)
                                    UserDefaults.standard.setValue(displayedPushIds, forKey: self.displayedPushIdKey)
                                } else {
                                    bestAttemptContent.title = "" //self.fallbackTitle
                                    bestAttemptContent.subtitle = "" //"subtitle"
                                    bestAttemptContent.body = self.fallbackBody
                                    bestAttemptContent.categoryIdentifier = "awesomeNotification"
                                }
                                contentHandler(bestAttemptContent)
                            case .failure(let error):
                                print(error)
                                bestAttemptContent.title = self.fallbackTitle
                                bestAttemptContent.subtitle = "subtitle"
                                bestAttemptContent.body = self.fallbackBody
                                bestAttemptContent.categoryIdentifier = "awesomeNotification"
                                contentHandler(bestAttemptContent)
                            }
                        }
                    }
                case .failure(let error):
                    print(error)
                    bestAttemptContent.title = self.fallbackTitle
                    bestAttemptContent.subtitle = "subtitle"
                    bestAttemptContent.body = self.fallbackBody
                    bestAttemptContent.categoryIdentifier = "awesomeNotification"
                    contentHandler(bestAttemptContent)
                }
            })
        }
    }
    
    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.
        if let contentHandler = contentHandler, let bestAttemptContent =  bestAttemptContent {
            
            bestAttemptContent.title = fallbackTitle
            contentHandler(bestAttemptContent)
        }
    }

}
