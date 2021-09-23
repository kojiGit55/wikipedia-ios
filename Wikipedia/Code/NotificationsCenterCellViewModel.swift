import Foundation

struct NotificationsCenterCellViewModel {

	// MARK: - Properties

	let notification: RemoteNotification
	var displayState: NotificationsCenterCellDisplayState

	// MARK: - Lifecycle

	init(notification: RemoteNotification, displayState: NotificationsCenterCellDisplayState = .defaultUnread) {
		self.notification = notification
		self.displayState = displayState
	}

	// MARK: - Public

	var isRead: Bool {
		return notification.isRead
	}
}

extension NotificationsCenterCellViewModel: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(notification.key)
    }

    static func == (lhs: NotificationsCenterCellViewModel, rhs: NotificationsCenterCellViewModel) -> Bool {
        return lhs.notification.key == rhs.notification.key &&
        lhs.isRead == rhs.isRead
    }
}
