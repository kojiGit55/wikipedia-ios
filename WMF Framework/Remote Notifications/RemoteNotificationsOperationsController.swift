import CocoaLumberjackSwift

class RemoteNotificationsOperationsController: NSObject {
    private let apiController: RemoteNotificationsAPIController
    private let modelController: RemoteNotificationsModelController?
    private let deadlineController: RemoteNotificationsOperationsDeadlineController?
    private let legacyOperationQueue: OperationQueue
    private let importAndRefreshOperationQueue: OperationQueue
    private let preferredLanguageCodesProvider: WMFPreferredLanguageInfoProvider
    
    var viewContext: NSManagedObjectContext? {
        return modelController?.viewContext
    }

    private var isLocked: Bool = false {
        didSet {
            if isLocked {
                stop()
            }
        }
    }

    required init(session: Session, configuration: Configuration, preferredLanguageCodesProvider: WMFPreferredLanguageInfoProvider) {
        apiController = RemoteNotificationsAPIController(session: session, configuration: configuration)
        var modelControllerInitializationError: Error?
        modelController = RemoteNotificationsModelController(&modelControllerInitializationError)
        deadlineController = RemoteNotificationsOperationsDeadlineController(with: modelController?.managedObjectContext)
        if let modelControllerInitializationError = modelControllerInitializationError {
            DDLogError("Failed to initialize RemoteNotificationsModelController and RemoteNotificationsOperationsDeadlineController: \(modelControllerInitializationError)")
            isLocked = true
        }

        legacyOperationQueue = OperationQueue()
        legacyOperationQueue.maxConcurrentOperationCount = 1
        
        importAndRefreshOperationQueue = OperationQueue()
        
        self.preferredLanguageCodesProvider = preferredLanguageCodesProvider
        
        super.init()

        NotificationCenter.default.addObserver(self, selector: #selector(didMakeAuthorizedWikidataDescriptionEdit), name: WikidataFetcher.DidMakeAuthorizedWikidataDescriptionEditNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(modelControllerDidLoadPersistentStores(_:)), name: RemoteNotificationsModelController.didLoadPersistentStoresNotification, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func markAsRead(notification: RemoteNotification, completion: @escaping () -> Void) {
        
        guard let modelController = modelController else {
            assertionFailure("Failure setting up notifications core data stack.")
            return
        }
        
        let completionOperation = BlockOperation(block: completion)
        
        let markAsReadOperation = RemoteNotificationsAlternativeMarkAsReadOperation(with: self.apiController, modelController: modelController, notification: notification)
        completionOperation.addDependency(markAsReadOperation)
        self.legacyOperationQueue.addOperation(markAsReadOperation)
        self.legacyOperationQueue.addOperation(completionOperation)
    }
    
    func importPreferredWikiNotifications(_ completion: @escaping () -> Void) {
        
        guard let modelController = modelController else {
            assertionFailure("Failure setting up notifications core data stack.")
            return
        }
        
        preferredLanguageCodesProvider.getPreferredLanguageCodes({ [weak self] (languageCodes) in
            
            guard let self = self else {
                return
            }
            
            let wikis = languageCodes + ["wikidata"]
            var importOperations: [RemoteNotificationsImportOperation] = []
            for wiki in wikis {
                importOperations.append(RemoteNotificationsImportOperation(with: self.apiController, modelController: modelController, wiki: wiki))
            }
            
            let completionOperation = BlockOperation(block: completion)
            
            for importOperation in importOperations {
                completionOperation.addDependency(importOperation)
            }
            
            for importOperation in importOperations {
                self.importAndRefreshOperationQueue.addOperation(importOperation)
            }
            self.importAndRefreshOperationQueue.addOperation(completionOperation)
        })
    }

    public func stop() {
        legacyOperationQueue.cancelAllOperations()
        importAndRefreshOperationQueue.cancelAllOperations()
    }

    @objc private func sync(_ completion: @escaping () -> Void) {
        let completeEarly = {
            self.legacyOperationQueue.addOperation(completion)
        }

        guard !isLocked else {
            completeEarly()
            return
        }

        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(sync), object: nil)

        guard legacyOperationQueue.operationCount == 0 else {
            completeEarly()
            return
        }

        guard apiController.isAuthenticated else {
            stop()
            completeEarly()
            return
        }
        
        guard deadlineController?.isBeforeDeadline ?? false else {
            completeEarly()
            return
        }
    
        guard let modelController = self.modelController else {
                completeEarly()
                return
        }
        
        let markAsReadOperation = RemoteNotificationsMarkAsReadOperation(with: apiController, modelController: modelController)
        preferredLanguageCodesProvider.getPreferredLanguageCodes({ (languageCodes) in
            let targetWikis = languageCodes + ["wikidata"]
            let fetchOperation = RemoteNotificationsFetchOperation(with: self.apiController, modelController: modelController, targetWikis: targetWikis)
            let completionOperation = BlockOperation(block: completion)
            
            fetchOperation.addDependency(markAsReadOperation)
            completionOperation.addDependency(fetchOperation)
            
            self.legacyOperationQueue.addOperation(markAsReadOperation)
            self.legacyOperationQueue.addOperation(fetchOperation)
            self.legacyOperationQueue.addOperation(completionOperation)
        })
    }

    // MARK: Notifications

    @objc private func didMakeAuthorizedWikidataDescriptionEdit(_ note: Notification) {
        deadlineController?.resetDeadline()
    }

    @objc private func modelControllerDidLoadPersistentStores(_ note: Notification) {
        if let object = note.object, let error = object as? Error {
            DDLogDebug("RemoteNotificationsModelController failed to load persistent stores with error \(error); stopping RemoteNotificationsOperationsController")
            isLocked = true
        } else {
            isLocked = false
        }
    }
}

extension RemoteNotificationsOperationsController: PeriodicWorker {
    func doPeriodicWork(_ completion: @escaping () -> Void) {
        sync(completion)
    }
}

extension RemoteNotificationsOperationsController: BackgroundFetcher {
    func performBackgroundFetch(_ completion: @escaping (UIBackgroundFetchResult) -> Void) {
        doPeriodicWork {
            completion(.noData)
        }
    }
}

// MARK: RemoteNotificationsOperationsDeadlineController

final class RemoteNotificationsOperationsDeadlineController {
    private let remoteNotificationsContext: NSManagedObjectContext

    init?(with remoteNotificationsContext: NSManagedObjectContext?) {
        guard let remoteNotificationsContext = remoteNotificationsContext else {
            return nil
        }
        self.remoteNotificationsContext = remoteNotificationsContext
    }

    let startTimeKey = "WMFRemoteNotificationsOperationsStartTime"
    let deadline: TimeInterval = 86400 // 24 hours
    private var now: CFAbsoluteTime {
        return CFAbsoluteTimeGetCurrent()
    }

    private func save() {
        guard remoteNotificationsContext.hasChanges else {
            return
        }
        do {
            try remoteNotificationsContext.save()
        } catch let error {
            DDLogError("Error saving managedObjectContext: \(error)")
        }
    }

    public var isBeforeDeadline: Bool {
        guard let startTime = startTime else {
            return false
        }
        return now - startTime < deadline
    }

    private var startTime: CFAbsoluteTime? {
        set {
            let moc = remoteNotificationsContext
            moc.perform {
                if let newValue = newValue {
                    moc.wmf_setValue(NSNumber(value: newValue), forKey: self.startTimeKey)
                } else {
                    moc.wmf_setValue(nil, forKey: self.startTimeKey)
                }
                self.save()
            }
        }
        get {
            let moc = remoteNotificationsContext
            let value: CFAbsoluteTime? = moc.performWaitAndReturn {
                let keyValue = remoteNotificationsContext.wmf_keyValue(forKey: startTimeKey)
                guard let value = keyValue?.value else {
                    return nil
                }
                guard let number = value as? NSNumber else {
                    assertionFailure("Expected keyValue \(startTimeKey) to be of type NSNumber")
                    return nil
                }
                return number.doubleValue
            }
            return value
        }
    }

    public func resetDeadline() {
        startTime = now
    }
}
