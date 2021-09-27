import CocoaLumberjackSwift

@objc public final class RemoteNotificationsController: NSObject {
    private let operationsController: RemoteNotificationsOperationsController
    private var alreadyImportedThisSession = false
    
    public var viewContext: NSManagedObjectContext? {
        return operationsController.viewContext
    }
    
    @objc public required init(session: Session, configuration: Configuration, preferredLanguageCodesProvider: WMFPreferredLanguageInfoProvider) {
        operationsController = RemoteNotificationsOperationsController(session: session, configuration: configuration, preferredLanguageCodesProvider: preferredLanguageCodesProvider)
        
        super.init()
        
        NotificationCenter.default.addObserver(self, selector: #selector(didBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    @objc private func didBecomeActive() {

        guard alreadyImportedThisSession else {
            return
        }
        
        refreshImportedNotifications(fireNewRemoteNotification: true) {
            //do nothing
        }
    }
    
    @objc func deleteLegacyDatabaseFiles() {
        do {
            try operationsController.deleteLegacyDatabaseFiles()
        } catch (let error) {
            DDLogError("Failure deleting legacy RemoteNotifications database files: \(error)")
        }
    }
    
    public func toggleNotificationReadStatus(notification: RemoteNotification) {
        operationsController.toggleNotificationReadStatus(notification: notification)
    }
    
    public func refreshImportedNotifications(fireNewRemoteNotification: Bool = false, completion: @escaping () -> Void) {
        operationsController.refreshImportedNotifications(fireNewRemoteNotification: fireNewRemoteNotification, completion: completion)
    }
    
    public func importNotificationsIfNeeded(primaryLanguageCompletion: @escaping () -> Void, allProjectsCompletion: @escaping () -> Void) {
        guard !alreadyImportedThisSession else {
            primaryLanguageCompletion()
            allProjectsCompletion()
            return
        }

        operationsController.importNotificationsIfNeeded(primaryLanguageCompletion: primaryLanguageCompletion, allProjectsCompletion: allProjectsCompletion)
        alreadyImportedThisSession = true
    }
    
    public func fetchNotifications(isFilteringOn: Bool = false, fetchLimit: Int = 10, fetchOffset: Int = 0) -> [RemoteNotification] {
        assert(Thread.isMainThread)
        
        guard let viewContext = self.viewContext else {
            DDLogError("Failure fetching notifications from persistence: missing viewContext")
            return []
        }
        
        let fetchRequest: NSFetchRequest<RemoteNotification> = RemoteNotification.fetchRequest()
        if isFilteringOn {
            fetchRequest.predicate = NSPredicate(format: "typeString == %@", "thank-you-edit")
        }
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        fetchRequest.fetchLimit = fetchLimit
        fetchRequest.fetchOffset = fetchOffset
        
        do {
            return try viewContext.fetch(fetchRequest)
        } catch {
            DDLogError("Failure fetching notifications from persistence: \(error)")
            return []
        }
    }
    
    public func fetchedResultsController(isFilteringOn: Bool = false, fetchLimit: Int = 10, fetchOffset: Int = 0) -> NSFetchedResultsController<RemoteNotification>? {
        
        guard let viewContext = self.viewContext else {
            return nil
        }
        
        let fetchRequest: NSFetchRequest<RemoteNotification> = RemoteNotification.fetchRequest()
        if isFilteringOn {
            fetchRequest.predicate = NSPredicate(format: "typeString == %@", "thank-you-edit")
        }
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        fetchRequest.fetchLimit = fetchLimit
        fetchRequest.fetchOffset = fetchOffset

        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: viewContext, sectionNameKeyPath: nil, cacheName: nil)

        return fetchedResultsController
    }
}
