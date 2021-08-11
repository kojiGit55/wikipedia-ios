@objc public final class RemoteNotificationsController: NSObject {
    private let operationsController: RemoteNotificationsOperationsController
    
    //TODO: Basic prevention of importing multiple times while in memory. Replace with something more robust.
    private var needsImport = true
    
    public var viewContext: NSManagedObjectContext? {
        return operationsController.viewContext
    }
    
    @objc public required init(session: Session, configuration: Configuration, preferredLanguageCodesProvider: WMFPreferredLanguageInfoProvider) {
        operationsController = RemoteNotificationsOperationsController(session: session, configuration: configuration, preferredLanguageCodesProvider: preferredLanguageCodesProvider)
        super.init()
    }
    
    public func importPreferredWikiNotificationsIfNeeded(_ completion: @escaping () -> Void) {
        guard needsImport else {
            completion()
            return
        }
        
        operationsController.importPreferredWikiNotifications { [weak self] in
            self?.needsImport = false
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
