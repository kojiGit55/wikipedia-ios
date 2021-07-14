
import SwiftUI

@available(iOS 13.0, *)
struct NotificationView: View {
    let notification: EchoNotification
    let dataProvider: PushNotificationsDataProvider
    
    private let identifier = UUID()
    var body: some View {
        HStack {
            if notification.readDate == nil {
                Image(systemName: "circle.fill")
                    .foregroundColor(.green)
            }
            Text(notification.header ?? "Unknown type name")
            if notification.readDate == nil {
                Spacer()
                Button {
                    //todo: disable button
                    dataProvider.markNotificationAsRead(notification: notification) { result in
                        //todo: enable button
                    }
                } label: {
                    Image(systemName: "book.fill")
                }
            }
        }
        
    }
}
