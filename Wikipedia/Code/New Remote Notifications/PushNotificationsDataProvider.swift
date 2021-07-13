import Foundation
import WMF

enum PushNotificationsDataProviderError: Error {
    case attemptingToPageButNoContinueId
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
    
    init(echoFetcher: EchoNotificationsFetcher, inMemory: Bool) {
        self.echoFetcher = echoFetcher
        self.inMemory = inMemory
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
    
    func oldestNotificationOfWikis(wikis: [String]) throws -> EchoNotification? {
        
        let moc = backgroundContext
        let fetchRequest: NSFetchRequest<EchoNotification> = EchoNotification.fetchRequest()
        fetchRequest.fetchLimit = 1
        fetchRequest.predicate = NSPredicate(format: "wiki IN %@", wikis)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
        return try moc.fetch(fetchRequest).first
    }
    
    func fetchNotifications(fetchType: FetchType = .reload, completion: @escaping (Result<Void, Error>) -> Void) {
        
        guard !inMemory else {
            return
        }
        
        let notwikis = "enwiki"
        let subdomain = "en"
        let urlKey: URL? = try? echoFetcher.key(notwikis: notwikis, subdomain: subdomain)
        
        //todo: don't cancel tasks so frequently, instead run this entire method as an operation (fetch remote, create local objects, pull oldest from local objects and save it's continue id, save local objects to store) serially. this will hopefully result in fewer cancelled tasks and more consistent data. if an operation fails in some way (i.e. server or database is messing up) end recursive fetch calling and cancel tasks.
        if let cancellationKey = getCancellationKey(for: urlKey) {
            self.echoFetcher.cancel(taskFor: cancellationKey)
        }
        
        var continueId: String? = nil
        if fetchType == .page {
            continueId = getContinueId(for: urlKey)
            if continueId == nil {
                print("end of page, bail")
                completion(.failure(PushNotificationsDataProviderError.attemptingToPageButNoContinueId))
                return
            }
        }
        
        let moc = backgroundContext
        let cancellationKey = echoFetcher.fetchNotifications(notwikis: notwikis, subdomain: subdomain, continueId: continueId) { [weak self] result in
            
            guard let self = self else { return }
            
            self.setCancellationKey(nil, for: urlKey)
            
            switch result {
            case .success(let response):
                
                moc.perform {
                    for remoteNotification in response.notifications {
                        let _ = EchoNotification.init(remoteNotification: remoteNotification, moc: moc)
                    }
                    
                    do {
                        
                        //by pulling the oldest local notification for continue value instead of going by the network response, we are potentialy reducing the number of network calls for objects we already have locally.
                        if let oldestLocalNotification = try? self.oldestNotificationOfWikis(wikis: [notwikis]) {
                            let unix = oldestLocalNotification.timestampUnix == nil ? "" : "\(oldestLocalNotification.timestampUnix!)|"
                            let identifier = oldestLocalNotification.id
                            let newContinueId = unix + String(identifier)
                            let oldContinueId = self.getContinueId(for: urlKey)
                            if newContinueId == oldContinueId && fetchType == .page { //nothing new, remove key to stop auto-fetching
                                self.setContinueId(nil, for: urlKey)
                            } else {
                                self.setContinueId(unix + String(identifier), for: urlKey)
                            }
                        } else {
                            self.setContinueId(response.continueString, for: urlKey)
                        }
                        
                        try self.save(moc: moc)
                        
                        completion(.success(()))
                    } catch (let error) {
                        completion(.failure(error))
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
        
        setCancellationKey(cancellationKey, for: urlKey)
    }
    
    func save(moc: NSManagedObjectContext) throws {
        guard moc.hasChanges else {
            return
        }
        
        try moc.save()
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
}
