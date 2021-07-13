
import SwiftUI

@available(iOS 13.0, *)
struct NotificationCenterListView: View {
    
    let dataProvider: PushNotificationsDataProvider
    
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \EchoNotification.timestamp, ascending: false)])
    private var notifications: FetchedResults<EchoNotification>
    
    @SwiftUI.State var loading = false
    @SwiftUI.State var onScreenNotificationIds: [Int64] = []
    
    var body: some View {
        List {
            ForEach(notifications, id: \.self) { notification in
                NotificationView(notification: notification)
                    .onAppear() {
                        self.onScreenNotificationIds.append(notification.id)
                        let isLast = notifications.last == notification
                        if isLast {
                            fetchNotifications(fetchType: .page)
                        }
                    }
                    .onDisappear {
                        self.onScreenNotificationIds.removeAll(where: { $0 == notification.id })
                    }
            }
        }
        .navigationBarItems(trailing:
                        HStack {
                            loading ? LoadingIconView() : nil
                            Button {
                                fetchNotifications()
                            } label: {
                                Image(systemName: "arrow.clockwise")
                            }

                        })
        .onAppear {
            fetchNotifications()
        }
    }
    
    private func fetchNotifications(fetchType: PushNotificationsDataProvider.FetchType = .reload) {
        loading = true
        dataProvider.fetchNotifications(fetchType: fetchType) { result in
            DispatchQueue.main.async {
                loading = false
                
                switch result {
                case .success():
                    print("success!")
                    
                        if let lastNotificationId = notifications.last?.id,
                           fetchType == .page,
                           onScreenNotificationIds.contains(lastNotificationId) {
                            fetchNotifications(fetchType: .page)
                        }
                    
                case .failure(let error):
                    print(error)
                }
            }
        }
    }
}
@available(iOS 13.0, *)
struct NotificationCenterListView_Previews: PreviewProvider {
    static var previews: some View {
        NotificationCenterListView(dataProvider: PushNotificationsDataProvider.preview)
    }
}
