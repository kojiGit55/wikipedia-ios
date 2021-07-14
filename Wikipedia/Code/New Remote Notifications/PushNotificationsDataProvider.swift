import Foundation
import WMF

enum PushNotificationsDataProviderError: Error {
    case attemptingToPageButNoContinueId
    case alreadyFetching
}

class PushNotificationsDataProvider {
    
    enum FetchType {
        case reload
        case page
    }
    
    //for use with SwiftUI canvas previews
    static let preview: PushNotificationsDataProvider = {
        let provider = PushNotificationsDataProvider(echoFetcher: EchoNotificationsFetcher(), inMemory: true)
        EchoNotification.makePreviews(count: 10)
        return provider
    }()

    private let echoFetcher: EchoNotificationsFetcher
    private let inMemory: Bool
    private var cancellationKeys: [URL: String] = [:] //TODO: why won't CancellationKey type here work
    private var continueIds: [URL: String] = [:]
    private let queue = DispatchQueue(label: "PushNotificationsDataProvider-" + UUID().uuidString)
    private var continueIdInProgress: String? = nil
    private let operationQueue: OperationQueue
    
    init(echoFetcher: EchoNotificationsFetcher, inMemory: Bool) {
        self.echoFetcher = echoFetcher
        self.inMemory = inMemory
        operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = 1
        //kick off persistent container upon init
        let _ = container
    }
    
    /// A persistent container to set up the Core Data stack.
    lazy var container: NSPersistentContainer = {
        /// - Tag: persistentContainer
        let container = NSPersistentContainer(name: "EchoNotifications")

        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("Failed to retrieve a persistent store description.")
        }

        if inMemory {
            description.url = URL(fileURLWithPath: "/dev/null")
        }
        
        print("Push Notification Persistent Store location: \(description.url)")
//
//        // Enable persistent store remote change notifications
//        /// - Tag: persistentStoreRemoteChange
//        description.setOption(true as NSNumber,
//                              forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
//
//        // Enable persistent history tracking
//        /// - Tag: persistentHistoryTracking
//        description.setOption(true as NSNumber,
//                              forKey: NSPersistentHistoryTrackingKey)

        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.name = "viewContext"
        container.viewContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        return container
    }()
    
    /// Creates and configures a private queue context.
    lazy var backgroundContext: NSManagedObjectContext = {
        // Create a private queue context.
        let taskContext = container.newBackgroundContext()
        taskContext.automaticallyMergesChangesFromParent = true
        taskContext.name = "backgroundContext"
        taskContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        return taskContext
    }()
    
    @available(iOS 13.0, *)
    func fetchAggregateNotifications(aggregateDictionary: EchoNotificationAggregateDictionary) {
        
        let keypathExp = NSExpression(forKeyPath: "wiki") // can be any column
        let expression = NSExpression(forFunction: "count:", arguments: [keypathExp])

        let countDesc = NSExpressionDescription()
        countDesc.expression = expression
        countDesc.name = "count"
        countDesc.expressionResultType = .integer64AttributeType
        
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "EchoNotification")
        request.returnsObjectsAsFaults = false
        request.propertiesToGroupBy = ["wiki"]
        request.propertiesToFetch = ["wiki", countDesc]
        request.resultType = .dictionaryResultType
        
        let moc = backgroundContext
        moc.perform {
            do {
                    let results = try moc.fetch(request)
                    if results.count > 0 {
                        DispatchQueue.main.async {
                            aggregateDictionary.result = results as? [[String: Any]] ?? []
                            aggregateDictionary.numProjects = results.count
                            var numNotifications = 0
                            if let resultsDict = results as? [[String: Any]] {
                                for dict in resultsDict {
                                    if let countValue = dict["count"] as? Int {
                                        numNotifications += countValue
                                    }
                                }
                            }
                            aggregateDictionary.numNotifications = numNotifications
                        }
                    }
                } catch let error as NSError {
                    print(error)
                }
        }
        
    }
    
    func fetchNotifications(fetchType: FetchType = .reload, projectFilters: [String], completion: @escaping (Result<Void, Error>) -> Void) {
        
        guard !inMemory else {
            return
        }
        
        let subdomain = "en"
        
        let urlKey: URL? = try? echoFetcher.key(projectFilters: projectFilters, subdomain: subdomain)
        
        var continueId: String? = nil
        if fetchType == .page {
            continueId = getContinueId(for: urlKey)
            if continueId == nil {
                print("end of page, bail")
                completion(.failure(PushNotificationsDataProviderError.attemptingToPageButNoContinueId))
                return
            }
            
            let continueIdInProgress = getContinueIdInProgress()
            print("checking continue id in progress: \(continueId), \(continueIdInProgress)")
            if continueId == getContinueIdInProgress() {
                print("already fetching this")
                completion(.failure(PushNotificationsDataProviderError.alreadyFetching))
                return
            }
        }
        
        let fetchOperation = PushNotificationFetchOperation(continueId: continueId, moc: backgroundContext, echoFetcher: echoFetcher, projectFilters: projectFilters, subdomain: "en", setContinueIdBlock: { continueId, urlKey in
            self.setContinueId(continueId, for: urlKey)
        }, getContinueIdBlock: { urlKey in
            return self.getContinueId(for: urlKey)
        }, fetchType: fetchType, urlKey: urlKey, completion: { result in
            self.setContinueIdInProgress(continueId: nil)
            completion(result)
        }, startBlock: {
            print("setting continue id in progress: \(continueId)")
            self.setContinueIdInProgress(continueId: continueId)
        })
        
        fetchOperation.queuePriority = .veryHigh
        
        operationQueue.addOperation(fetchOperation)
        
        //setCancellationKey(cancellationKey, for: urlKey)
    }
    
    
}

//MARK: Thread-safe accessors for collection properties
private extension PushNotificationsDataProvider {
    func setCancellationKey(_ cancellationKey: String?, for url: URL?) {
        
        guard let url = url else {
            return
        }
        
        queue.async {
            self.cancellationKeys[url] = cancellationKey
        }
    }
    
    func getCancellationKey(for url: URL?) -> String? {
        guard let url = url else {
            return nil
        }
        
        var cancellationKey: String?
        queue.sync {
            cancellationKey = self.cancellationKeys[url]
        }
        
        return cancellationKey
    }
    
    func setContinueId(_ continueId: String?, for url: URL?) {
        
        guard let url = url else {
            return
        }
        
        queue.async {
            self.continueIds[url] = continueId
        }
    }
    
    func getContinueId(for url: URL?) -> String? {
        guard let url = url else {
            return nil
        }
        
        var continueId: String?
        queue.sync {
            continueId = self.continueIds[url]
        }
        
        return continueId
    }
    
    func setContinueIdInProgress(continueId: String?) {
        queue.async {
            self.continueIdInProgress = continueId
        }
    }
    
    func getContinueIdInProgress() -> String? {
        var continueId: String?
        queue.sync {
            continueId = self.continueIdInProgress
        }
        return continueId
    }
}
