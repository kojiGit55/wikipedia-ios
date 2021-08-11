
import Foundation

public extension Notification.Name {
    static let addNotificationsBadge = Notification.Name("addNotificationsBadge")
}

class RemoteNotificationsRefreshOperation: RemoteNotificationsOperation {
    
    private let wiki: String
    private let fireNewRemoteNotification: Bool
    private var foundNewNotifications: Bool = false
    init(with apiController: RemoteNotificationsAPIController, modelController: RemoteNotificationsModelController, wiki: String, fireNewRemoteNotification: Bool = false) {
        self.wiki = wiki
        self.fireNewRemoteNotification = fireNewRemoteNotification
        super.init(with: apiController, modelController: modelController)
    }
    
    //TODO: DRY with import operation
    override func execute() {
        getNewNotifications(from: wiki, continueId: nil) { [weak self] result in
            
            guard let self = self else {
                return
            }
            
            switch result {
            case .success:
                if self.foundNewNotifications && self.fireNewRemoteNotification {
                    NotificationCenter.default.post(name: Notification.Name.addNotificationsBadge, object: nil)
                }
                self.finish()
            case .failure(let error):
                self.finish(with: error)
            }
        }
    }
    
    private func getNewNotifications(from subdomain: String, continueId: String?, completion: @escaping (Result<Void, Error>) -> Void) {
        
        self.apiController.getAllNotifications(from: self.wiki, continueId: continueId) { [weak self] result, error in
            
            guard let self = self else {
                return
            }
            
            if let error = error {
                completion(.failure(error))
                return
            }
                
            guard let fetchedNotifications = result?.list else {
                completion(.failure(RemoteNotificationsImportError.missingListInResponse))
                return
            }
            
            var shouldContinueToPage = true
            let containsNewNotifications = self.areAnyNotificationsNew(notifications: fetchedNotifications)
            
            if !containsNewNotifications {
                shouldContinueToPage = false
            } else {
                shouldContinueToPage = self.shouldContinueToPage(lastNotification: fetchedNotifications.last)
            }
            
            self.foundNewNotifications = containsNewNotifications
            
            do {
                try self.modelController.createNewNotifications(from: Set(fetchedNotifications), bypassValidation: true) { [weak self] in
                    
                    guard let self = self else {
                        return
                    }
                    
                    guard let continueId = result?.continue,
                          shouldContinueToPage == true else {
                        completion(.success(()))
                        return
                    }
                    
                    self.getNewNotifications(from: subdomain, continueId: continueId, completion: completion)
                    
                }
            } catch let error {
                completion(.failure(error))
            }
        }
    }
    
    private func areAnyNotificationsNew(notifications: [RemoteNotificationsAPIController.NotificationsResult.Notification]) -> Bool {
        
        let notificationKeys = notifications.map{$0.key}
        
        var containsNewNotifications = false
        self.managedObjectContext.performAndWait {
            
            let fetchRequest: NSFetchRequest<RemoteNotification> = RemoteNotification.fetchRequest()
            let predicate = NSPredicate(format: "key IN %@", notificationKeys)
            fetchRequest.predicate = predicate
            let count = try? self.managedObjectContext.count(for: fetchRequest)
            if notifications.count > (count ?? 0) {
                containsNewNotifications = true
            }
        }
        
        return containsNewNotifications
    }
    
    private func shouldContinueToPage(lastNotification: RemoteNotificationsAPIController.NotificationsResult.Notification?) -> Bool {
        
        guard let lastNotification = lastNotification else {
            return false
        }
        
        var shouldContinueToPage = true
        
        self.managedObjectContext.performAndWait {
            
            //Is last notification already in the database? If so, don't continue to page.
            let fetchRequest: NSFetchRequest<RemoteNotification> = RemoteNotification.fetchRequest()
            fetchRequest.fetchLimit = 1
            let predicate = NSPredicate(format: "key == %@", lastNotification.key)
            fetchRequest.predicate = predicate
            
            let result = try? self.managedObjectContext.fetch(fetchRequest)
            if result?.first != nil {
                shouldContinueToPage = false
            }
        }
        
        return shouldContinueToPage
    }
}
