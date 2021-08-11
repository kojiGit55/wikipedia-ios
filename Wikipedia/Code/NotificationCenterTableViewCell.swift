
import UIKit

protocol NotificationCenterTableViewCellDelegate: class {
    func markNotificationAsRead(_ notification: RemoteNotification)
}

class NotificationCenterTableViewCell: UITableViewCell {
    
    private var stackView: UIStackView?
    private var titleLabel: UILabel?
    private lazy var markAsReadButton: UIButton = {
        let markAsReadButton = UIButton(type: .system)
        if #available(iOS 13.0, *) {
            markAsReadButton.setImage(UIImage(systemName: "book"), for: .normal)
        } else {
            markAsReadButton.setImage(UIImage(named: "bot"), for: .normal)
        }
        return markAsReadButton
    }()
    weak var delegate: NotificationCenterTableViewCellDelegate?
    private var notification: RemoteNotification?

    func configure(notification: RemoteNotification) {
        addViewsIfNeeded()
        titleLabel?.text = notification.message
        
        if notification.state != .read {
            stackView?.addArrangedSubview(markAsReadButton)
            markAsReadButton.addTarget(self, action: #selector(markAsRead), for: .touchUpInside)
        } else {
            markAsReadButton.removeFromSuperview()
        }
    }
    
    @objc private func markAsRead() {
        guard let notification = notification else {
            return
        }
        
        delegate?.markNotificationAsRead(notification)
    }
    
    private func addViewsIfNeeded() {
        guard stackView == nil else {
            return
        }
        
        let stackView = UIStackView(frame: .zero)
        self.stackView = stackView
        let titleLabel = UILabel(frame: .zero)
        self.titleLabel = titleLabel
        contentView.addSubview(stackView)
        contentView.wmf_addConstraintsToEdgesOfView(stackView)
        stackView.addArrangedSubview(titleLabel)
    }

}
