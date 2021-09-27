
import Foundation

public extension Notification.Name {
    static let addNotificationsBadge = Notification.Name("addNotificationsBadge")
}

class RemoteNotificationsRefreshOperation: RemoteNotificationsOperation {
    
    private let languageCode: String
    private let fireNewRemoteNotification: Bool
    private var foundNewNotifications: Bool = false
    init(with apiController: RemoteNotificationsAPIController, modelController: RemoteNotificationsModelController, languageCode: String, fireNewRemoteNotification: Bool = false) {
        self.languageCode = languageCode
        self.fireNewRemoteNotification = fireNewRemoteNotification
        super.init(with: apiController, modelController: modelController)
    }
    
    //TODO: DRY with import operation
    override func execute() {
        getNewNotifications(from: languageCode, continueId: nil) { [weak self] result in
            
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
    
    private func getNewNotifications(from languageCode: String, continueId: String?, completion: @escaping (Result<Void, Error>) -> Void) {
        
        self.apiController.getAllNotifications(continueId: continueId, languageCode: languageCode) { [weak self] result, error in
            
            guard let self = self else {
                return
            }
            
            if let error = error {
                completion(.failure(error))
                return
            }
                
            guard let fetchedNotifications = result?.list else {
                completion(.failure(RequestError.unexpectedResponse))
                return
            }
            
            let backgroundContext = self.modelController.newBackgroundContext()
            var shouldContinueToPage = true
            let containsNewNotifications = self.areAnyNotificationsNew(moc: backgroundContext, notifications: fetchedNotifications)
            
            if !containsNewNotifications {
                shouldContinueToPage = false
            } else {
                shouldContinueToPage = self.shouldContinueToPage(moc: backgroundContext, lastNotification: fetchedNotifications.last)
            }
            
            self.foundNewNotifications = containsNewNotifications
            
            do {
                let backgroundContext = self.modelController.newBackgroundContext()
                try self.modelController.createNewNotifications(moc: backgroundContext, notificationsFetchedFromTheServer: Set(fetchedNotifications), completion: { [weak self] in

                    guard let self = self else {
                        return
                    }

                    guard let newContinueId = result?.continueId,
                          newContinueId != continueId,
                          shouldContinueToPage == true else {
                        completion(.success(()))
                        return
                    }

                    self.getNewNotifications(from: languageCode, continueId: continueId, completion: completion)
                })
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    private func areAnyNotificationsNew(moc: NSManagedObjectContext, notifications: [RemoteNotificationsAPIController.NotificationsResult.Notification]) -> Bool {
        
        let notificationKeys = notifications.map{$0.key}
        
        var containsNewNotifications = false
        moc.performAndWait {
            
            let fetchRequest: NSFetchRequest<RemoteNotification> = RemoteNotification.fetchRequest()
            let predicate = NSPredicate(format: "key IN %@", notificationKeys)
            fetchRequest.predicate = predicate
            let count = try? moc.count(for: fetchRequest)
            if notifications.count > (count ?? 0) {
                containsNewNotifications = true
            }
        }
        
        return containsNewNotifications
    }
    
    private func shouldContinueToPage(moc: NSManagedObjectContext, lastNotification: RemoteNotificationsAPIController.NotificationsResult.Notification?) -> Bool {
        
        guard let lastNotification = lastNotification else {
            return false
        }
        
        var shouldContinueToPage = true
        
        moc.performAndWait {
            
            //Is last notification already in the database? If so, don't continue to page.
            let fetchRequest: NSFetchRequest<RemoteNotification> = RemoteNotification.fetchRequest()
            fetchRequest.fetchLimit = 1
            let predicate = NSPredicate(format: "key == %@", lastNotification.key)
            fetchRequest.predicate = predicate
            
            let result = try? moc.fetch(fetchRequest)
            if result?.first != nil {
                shouldContinueToPage = false
            }
        }
        
        return shouldContinueToPage
    }
}
