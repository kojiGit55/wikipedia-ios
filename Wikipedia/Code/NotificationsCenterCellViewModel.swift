
import Foundation

final class NotificationsCenterCellViewModel {

    // MARK: - Properties

    let notification: RemoteNotification

    // MARK: - Lifecycle

    init(notification: RemoteNotification) {
        self.notification = notification
    }
    
}
