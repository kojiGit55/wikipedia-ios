import Foundation

@objc
final class NotificationsCenterViewModel: NSObject {

	// MARK: - Properties

	let remoteNotificationsController: RemoteNotificationsController
	let fetchedResultsController: NSFetchedResultsController<RemoteNotification>?

	// MARK: - Lifecycle

	@objc
	init(remoteNotificationsController: RemoteNotificationsController) {
		self.remoteNotificationsController = remoteNotificationsController
		self.fetchedResultsController = remoteNotificationsController.fetchedResultsController()
	}

	// MARK: - Public

	func notificationCellViewModel(indexPath: IndexPath) -> NotificationsCenterCellViewModel? {
		if let remoteNotification = fetchedResultsController?.object(at: indexPath) {
			return NotificationsCenterCellViewModel(remoteNotification: remoteNotification)
		}

		return nil
	}
    
    func populateInitialNotifications() {
        remoteNotificationsController.fetchFirstPageNotifications {
            print("fetched first page")
        }
    }

}

final class NotificationsCenterCellViewModel {

	enum TempRemoteNotificationCategory {
		case thanks
		case other
	}

	let remoteNotification: RemoteNotification

	init(remoteNotification: RemoteNotification) {
		self.remoteNotification = remoteNotification
	}

	var message: String {
		return remoteNotification.messageHeader ?? "–"
	}
    
    func attributedMessageForTheme(_ theme: Theme) -> NSAttributedString? {
        guard let messageHeader = remoteNotification.messageHeader,
              !messageHeader.isEmpty else {
            return NSAttributedString(string: "-")
        }
        
        let strippedMessage = messageHeader.removingHTML
        
        let mutableAttributedString = NSMutableAttributedString(string: strippedMessage)
        if let agentName = remoteNotification.agentName {
            let agentRange = (strippedMessage as NSString).range(of: agentName)
            if agentRange.location != NSNotFound {
                mutableAttributedString.addAttribute(NSAttributedString.Key.foregroundColor, value: theme.colors.link, range: agentRange)
            }
        }
        
        if let titleText = remoteNotification.titleText {
            let titleRange = (strippedMessage as NSString).range(of: titleText)
            if titleRange.location != NSNotFound {
                mutableAttributedString.addAttribute(NSAttributedString.Key.foregroundColor, value: theme.colors.link, range: titleRange)
            }
        }

        let style = NSMutableParagraphStyle()
        style.lineSpacing = 3
        let messageFont = remoteNotification.isRead ? UIFont.systemFont(ofSize: 12) : UIFont.systemFont(ofSize: 12, weight: .bold)
        mutableAttributedString.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: strippedMessage.count))
        mutableAttributedString.addAttribute(.font, value: messageFont, range: NSRange(location: 0, length: strippedMessage.count))
        
        let dateString = " " + (date as NSDate).wmf_fullyLocalizedRelativeDateStringFromLocalDateToNow()
        let dateMutableAttributedString = NSMutableAttributedString(string: dateString)
        let dateFont = UIFont.systemFont(ofSize: 12)
        dateMutableAttributedString.addAttribute(.font, value: dateFont, range: NSRange(location: 0, length: dateString.count))
        dateMutableAttributedString.addAttribute(NSAttributedString.Key.foregroundColor, value: theme.colors.secondaryText, range: NSRange(location: 0, length: dateString.count))
        mutableAttributedString.append(dateMutableAttributedString)
        
        return mutableAttributedString.copy() as? NSAttributedString
    }

	var date: Date {
		return remoteNotification.date ?? Date()
	}

	var type: TempRemoteNotificationCategory {
		if (remoteNotification.categoryString ?? "").contains("thank") {
			return .thanks
		}
		return .other

		// should return remoteNotification.category
	}

}
