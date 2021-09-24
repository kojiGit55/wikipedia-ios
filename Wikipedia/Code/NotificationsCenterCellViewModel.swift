import Foundation

final class NotificationsCenterCellViewModel {

	// MARK: - Properties

	let notification: RemoteNotification
	var displayState: NotificationsCenterCellDisplayState
    private(set) var isRead: Bool
 
	// MARK: - Lifecycle

	init(notification: RemoteNotification, displayState: NotificationsCenterCellDisplayState = .defaultUnread) {
		self.notification = notification
		self.displayState = displayState
        self.isRead = notification.isRead
	}
    
    func copyAnyValueableNewDataFromNewViewModel(_ newViewModel: NotificationsCenterCellViewModel) {
        self.isRead = newViewModel.isRead
        //might want to update display state here too.
    }
}

extension NotificationsCenterCellViewModel: Equatable, Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(notification.key)
    }

    static func == (lhs: NotificationsCenterCellViewModel, rhs: NotificationsCenterCellViewModel) -> Bool {
        return lhs.notification.key == rhs.notification.key
    }
}

extension NotificationsCenterCellViewModel: CustomStringConvertible {
    var description: String {
        return "\n\(self.notification.key ?? "nil") - \(Unmanaged.passUnretained(self).toOpaque())"
    }
}
