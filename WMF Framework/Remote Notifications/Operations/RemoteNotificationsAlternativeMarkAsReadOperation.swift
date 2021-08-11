
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
                    //todo: notification here will be from view context, need to pull background context managed object and mark it as read in model controller.
                    //self.modelController.markAsRead()
                }
            }
        }
    }
}
