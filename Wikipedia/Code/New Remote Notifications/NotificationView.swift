
import SwiftUI

@available(iOS 13.0, *)
struct NotificationView: View {
    let notification: EchoNotification
    private let identifier = UUID()
    var body: some View {
        Text(notification.agentName ?? "Unknown agent name")
    }
}

@available(iOS 13.0, *)
struct NotificationView_Previews: PreviewProvider {
    static var previews: some View {
        NotificationView(notification: EchoNotification.makePreviews(count: 1).first!)
    }
}
