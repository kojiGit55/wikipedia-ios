@objc public final class RemoteNotificationsController: NSObject {
    private let operationsController: RemoteNotificationsOperationsController
    
    public var viewContext: NSManagedObjectContext? {
        return operationsController.viewContext
    }
    
    @objc public required init(session: Session, configuration: Configuration, preferredLanguageCodesProvider: WMFPreferredLanguageInfoProvider) {
        operationsController = RemoteNotificationsOperationsController(session: session, configuration: configuration, preferredLanguageCodesProvider: preferredLanguageCodesProvider)
        super.init()
        
        NotificationCenter.default.addObserver(self, selector: #selector(didBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    @objc private func didBecomeActive() {

        guard UserDefaults.standard.hasImportedNotifications else {
            return
        }
        
        refreshImportedNotifications(fireNewRemoteNotification: true) {
            //do nothing
        }
    }
    
    public func refreshImportedNotifications(fireNewRemoteNotification: Bool = false, completion: @escaping () -> Void) {
        operationsController.refreshImportedNotifications(fireNewRemoteNotification: fireNewRemoteNotification, completion: completion)
    }
    
    public func markAsRead(notification: RemoteNotification, completion: @escaping () -> Void) {
        operationsController.markAsRead(notification: notification, completion: completion)
    }
    
    public func importPreferredWikiNotificationsIfNeeded(_ completion: @escaping () -> Void) {
        //TODO: need more robust method of determining import status (like if preferredLanguages change, etc.)
        guard !UserDefaults.standard.hasImportedNotifications else {
            completion()
            return
        }
        
        operationsController.importPreferredWikiNotifications {
            UserDefaults.standard.hasImportedNotifications = true
            completion()
        }
    }
}

extension RemoteNotificationsController: PeriodicWorker {
    public func doPeriodicWork(_ completion: @escaping () -> Void) {
        //TODO: Disable polling for now, remove later
        //operationsController.doPeriodicWork(completion)
    }
}

extension RemoteNotificationsController: BackgroundFetcher {
    public func performBackgroundFetch(_ completion: @escaping (UIBackgroundFetchResult) -> Void) {
        //TODO: Disable polling for now, remove later
        //operationsController.performBackgroundFetch(completion)
    }
}
