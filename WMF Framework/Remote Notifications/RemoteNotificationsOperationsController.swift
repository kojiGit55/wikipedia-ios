import CocoaLumberjackSwift

class RemoteNotificationsOperationsController: NSObject {
    private let apiController: RemoteNotificationsAPIController
    private let modelController: RemoteNotificationsModelController?
    private let operationQueue: OperationQueue
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
        if let modelControllerInitializationError = modelControllerInitializationError {
            DDLogError("Failed to initialize RemoteNotificationsModelController and RemoteNotificationsOperationsDeadlineController: \(modelControllerInitializationError)")
            isLocked = true
        }

        operationQueue = OperationQueue()
        
        self.preferredLanguageCodesProvider = preferredLanguageCodesProvider
        
        super.init()

        NotificationCenter.default.addObserver(self, selector: #selector(modelControllerDidLoadPersistentStores(_:)), name: RemoteNotificationsModelController.didLoadPersistentStoresNotification, object: nil)
    }
    
    func toggleNotificationReadStatus(notification: RemoteNotification) {
        modelController?.toggleReadStatus(notification)
    }
    
    func deleteLegacyDatabaseFiles() throws {
        modelController?.deleteLegacyDatabaseFiles()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    public func stop() {
        operationQueue.cancelAllOperations()
    }
    
    func importNotificationsIfNeeded(_ completion: @escaping () -> Void) {

        let completeEarly = {
            self.operationQueue.addOperation(completion)
        }

        guard !isLocked else {
            completeEarly()
            return
        }
        
        guard apiController.isAuthenticated else {
            stop()
            completeEarly()
            return
        }
        
        guard let modelController = modelController else {
            assertionFailure("Failure setting up notifications core data stack.")
            return
        }
        
        preferredLanguageCodesProvider.getPreferredLanguageCodes({ [weak self] (preferredLanguageCodes) in
            
            guard let self = self else {
                return
            }

            let languageCodes = preferredLanguageCodes + ["wikidata", "commons"]
            var operations: [RemoteNotificationsImportOperation] = []
            for languageCode in languageCodes {
                let operation = RemoteNotificationsImportOperation(with: self.apiController, modelController: modelController, languageCode: languageCode)
                operations.append(operation)
            }

            let completionOperation = BlockOperation(block: completion)
            completionOperation.queuePriority = .veryHigh

            for operation in operations {
                completionOperation.addDependency(operation)
            }

            self.operationQueue.addOperations(operations + [completionOperation], waitUntilFinished: false)
        })
    }
    
    func refreshImportedNotifications(fireNewRemoteNotification: Bool = false, completion: @escaping () -> Void) {
        
        guard let modelController = modelController else {
            assertionFailure("Failure setting up notifications core data stack.")
            return
        }
        
        //TODO: DRY with importNotificationsIfNeeded
        preferredLanguageCodesProvider.getPreferredLanguageCodes({ [weak self] (preferredLanguageCodes) in
            
            guard let self = self else {
                return
            }
            
            let languageCodes = preferredLanguageCodes + ["wikidata", "commons"]
            var operations: [RemoteNotificationsRefreshOperation] = []
            for languageCode in languageCodes {
                let operation = RemoteNotificationsRefreshOperation(with: self.apiController, modelController: modelController, languageCode: languageCode, fireNewRemoteNotification: fireNewRemoteNotification)
                operation.queuePriority = .normal
                operations.append(operation)
            }
            
            let completionOperation = BlockOperation(block: completion)
            completionOperation.queuePriority = .normal
            
            for operation in operations {
                completionOperation.addDependency(operation)
            }
            
            //TODO: ensure bulk import isn't in the middle of doing stuff?
            self.operationQueue.addOperations(operations + [completionOperation], waitUntilFinished: true)
            
        })
    }

    // MARK: Notifications
    
    @objc private func modelControllerDidLoadPersistentStores(_ note: Notification) {
        if let object = note.object, let error = object as? Error {
            DDLogDebug("RemoteNotificationsModelController failed to load persistent stores with error \(error); stopping RemoteNotificationsOperationsController")
            isLocked = true
        } else {
            isLocked = false
        }
    }
}
