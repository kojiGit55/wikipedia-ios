
import Foundation

class RemoteNotificationsAlternativeMarkAsReadOperation: RemoteNotificationsOperation {
    private let notification: RemoteNotification
    init(with apiController: RemoteNotificationsAPIController, modelController: RemoteNotificationsModelController, notification: RemoteNotification) {
        self.notification = notification
        super.init(with: apiController, modelController: modelController)
    }
    
    override func execute() {
        
        self.apiController.markAsRead([notification]) { error in
            if let error = error {
                self.finish(with: error)
            } else {
                self.managedObjectContext.perform {
                    if let backgroundRemoteNotification = self.managedObjectContext.object(
                        with: self.notification.objectID) as? RemoteNotification {
                        self.modelController.markAsRead(backgroundRemoteNotification)
                        self.finish()
                    }
                }
            }
        }
    }
}
