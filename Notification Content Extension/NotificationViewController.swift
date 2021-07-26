
import UIKit
import UserNotifications
import UserNotificationsUI
import WMF

class NotificationViewController: UIViewController, UNNotificationContentExtension {

    @IBOutlet var label: UILabel?
    @IBOutlet var textView: UITextView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        textView?.delegate = self
    }
    
    func didReceive(_ notification: UNNotification) {
        let attributedString = "Testing <b>with</b> a <a href=\"https://en.m.wikipedia.org/wiki/Special:PasswordReset\">link</a> here".byAttributingHTML(with: .title3, matching: traitCollection, handlingLinks: true, linkColor: UIColor.blue, handlingLists: false, handlingSuperSubscripts: false, tagMapping: nil, additionalTagAttributes: nil)
        self.label?.attributedText = attributedString
        self.textView?.attributedText = attributedString
        print("stuff here.")
    }

}

extension NotificationViewController: UITextViewDelegate {
    func textView(_ textView: UITextView, shouldInteractWith url: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        
        print("tapped url: \(url)")
        self.extensionContext?.open(url, completionHandler: { success in
            print(success)
        })
        return false
    }
}
