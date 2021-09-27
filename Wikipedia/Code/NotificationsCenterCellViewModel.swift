import Foundation

final class NotificationsCenterCellViewModel {

	// MARK: - Properties

	let notification: RemoteNotification
	private(set) var displayState: NotificationsCenterCellDisplayState
    private(set) var isRead: Bool
 
	// MARK: - Lifecycle

    init(notification: RemoteNotification, editMode: Bool) {
		self.notification = notification
        self.isRead = notification.isRead
        
        self.displayState = Self.displayStateForNotification(notification, editMode: editMode)
	}
    
    private static func displayStateForNotification(_ notification: RemoteNotification, editMode: Bool) -> NotificationsCenterCellDisplayState {
        switch (editMode, notification.isRead) {
            case (false, true):
            return .defaultRead
            case (false, false):
                return .defaultUnread
            case (true, false):
                return .editUnselectedUnread
            case (true, true):
                return .editUnselectedRead
        }
    }
    
    func copyAnyValuableNewDataFromNotification(_ notification: RemoteNotification, editMode: Bool) {
        self.isRead = notification.isRead
        
        //preserve selected state, unless params indicate edit mode has switched
        if ((self.displayState == .editSelectedRead ||
                self.displayState == .editSelectedUnread ||
                self.displayState == .editUnselectedRead ||
                self.displayState == .editUnselectedUnread) &&
            (editMode == false)) || ((editMode == true) &&
                                                                (self.displayState == .defaultUnread ||
                                                                    self.displayState == .defaultRead))
        {
            self.displayState = Self.displayStateForNotification(notification, editMode: editMode)
        }
        
        //if read flag has flipped, update display state to reflect what it should be.
        switch (self.displayState, self.isRead) {
        case (.defaultRead, false):
            self.displayState = .defaultUnread
        case (.defaultUnread, true):
            self.displayState = .defaultRead
        case (.editSelectedRead, false):
            self.displayState = .editSelectedUnread
        case (.editSelectedUnread, true):
            self.displayState = .editSelectedRead
        case (.editUnselectedRead, false):
            self.displayState = .editUnselectedUnread
        case (.editUnselectedUnread, true):
            self.displayState = .editUnselectedRead
        default:
            break
        }
    }
    
    func toggleCheckedStatus() {
        switch self.displayState {
        case .defaultUnread,
             .defaultRead:
            assertionFailure("This method shouldn't be called while in default state.")
            return
        case .editSelectedRead:
            self.displayState = .editUnselectedRead
        case .editSelectedUnread:
            self.displayState = .editUnselectedUnread
        case .editUnselectedUnread:
            self.displayState = .editSelectedUnread
        case .editUnselectedRead:
            self.displayState = .editSelectedRead
        }
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
