
import Foundation
import WMF

class PushNotificationFetchOperation: AsyncOperation {
    
    private let continueId: String?
    private let moc: NSManagedObjectContext
    private let echoFetcher: EchoNotificationsFetcher
    private let notwikis: [String]
    private let subdomain: String
    private let setContinueIdBlock: (String?, URL?) -> Void
    private let getContinueIdBlock: (URL?) -> String?
    private let fetchType: PushNotificationsDataProvider.FetchType
    private let urlKey: URL?
    private let startBlock: () -> Void
    private let completion: (Result<Void, Error>) -> Void
        
    init(continueId: String?, moc: NSManagedObjectContext, echoFetcher: EchoNotificationsFetcher, notwikis: [String], subdomain: String, setContinueIdBlock: @escaping (String?, URL?) -> Void, getContinueIdBlock: @escaping (URL?) -> String?, fetchType: PushNotificationsDataProvider.FetchType, urlKey: URL?, completion: @escaping (Result<Void, Error>) -> Void, startBlock: @escaping () -> Void) {
        self.continueId = continueId
        self.moc = moc
        self.echoFetcher = echoFetcher
        self.notwikis = notwikis
        self.subdomain = subdomain
        self.setContinueIdBlock = setContinueIdBlock
        self.getContinueIdBlock = getContinueIdBlock
        self.fetchType = fetchType
        self.urlKey = urlKey
        self.completion = completion
        self.startBlock = startBlock
    }
    
    override func start() {
        super.start()
        startBlock()
    }
    
    private func oldestNotificationOfWikis(wikis: [String]) throws -> EchoNotification? {
        
        let fetchRequest: NSFetchRequest<EchoNotification> = EchoNotification.fetchRequest()
        fetchRequest.fetchLimit = 1
        fetchRequest.predicate = NSPredicate(format: "wiki IN %@", wikis)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
        return try moc.fetch(fetchRequest).first
    }
    
    private func save(moc: NSManagedObjectContext) throws {
        guard moc.hasChanges else {
            return
        }
        
        try moc.save()
    }
    
    override func execute() {
        
        let cancellationKey = echoFetcher.fetchNotifications(notwikis: notwikis.first!, subdomain: subdomain, continueId: continueId) { result in
            
            switch result {
            case .success(let response):
                
                self.moc.perform {
                    for remoteNotification in response.notifications {
                        let _ = EchoNotification.init(remoteNotification: remoteNotification, moc: self.moc)
                    }
                    
                    do {
                        
                        //by pulling the oldest local notification for continue value instead of going by the network response, we are potentialy reducing the number of network calls for objects we already have locally.
                        if let oldestLocalNotification = try? self.oldestNotificationOfWikis(wikis: self.notwikis) {
                            let unix = oldestLocalNotification.timestampUnix == nil ? "" : "\(oldestLocalNotification.timestampUnix!)|"
                            let identifier = oldestLocalNotification.id
                            let newContinueId = unix + String(identifier)
                            let oldContinueId = self.getContinueIdBlock(self.urlKey)
                            if newContinueId == oldContinueId && self.fetchType == .page { //nothing new, remove key to stop auto-fetching
                                self.setContinueIdBlock(nil, self.urlKey)
                            } else {
                                self.setContinueIdBlock(unix + String(identifier), self.urlKey)
                            }
                        } else {
                            self.setContinueIdBlock(response.continueString, self.urlKey)
                        }
                        
                        try self.save(moc: self.moc)
                        
                        self.completion(.success(()))
                        self.finish()
                    } catch (let error) {
                        self.completion(.failure(error))
                        self.finish(with: error)
                    }
                }
            case .failure(let error):
                self.finish(with: error)
            }
        }
    }
}
