
import SwiftUI

@available(iOS 13.0, *)
struct AggregateView: View {
    
    @SwiftUI.ObservedObject var aggregateDictionary: EchoNotificationAggregateDictionary
    
    var body: some View {
        Text("numProjects: \(aggregateDictionary.numProjects), numNotifications: \(aggregateDictionary.numNotifications)")
    }
}


@available(iOS 13.0, *)
struct NotificationCenterListContainerView: View {
    
    let dataProvider: PushNotificationsDataProvider
    @SwiftUI.ObservedObject var filters = EchoNotificationTypeFilters()
    let aggregateDictionary = EchoNotificationAggregateDictionary(result: [], numProjects: 0, numNotifications: 0)
    @SwiftUI.State private var showingSheet = false
    
    var body: some View {
        VStack {
            HStack {
                Button {
                    showingSheet = true
                } label: {
                    Image(systemName: "line.horizontal.3.decrease.circle")
                }
                AggregateView(aggregateDictionary: aggregateDictionary)
            }
            NotificationCenterListView(typeFilters: filters.typeFilters.filter { $0.isSelected }.map { $0.name }, projectFilters: filters.projectFilters.filter { $0.isSelected }.map { $0.name }, dataProvider: dataProvider, aggregateDictionary: aggregateDictionary)
        }
        .sheet(isPresented: $showingSheet) {
                    NotificationsTypePickerView(filters: filters)
                }
    }
}

@available(iOS 13.0, *)
struct NotificationCenterListView: View {
    
    let dataProvider: PushNotificationsDataProvider
    
    var fetchRequest: FetchRequest<EchoNotification>
    var notifications: FetchedResults<EchoNotification> { fetchRequest.wrappedValue }
    private let projectFilters: [String]
    private let aggregateDictionary: EchoNotificationAggregateDictionary
    
    @SwiftUI.State var loading = false
    @SwiftUI.State var onScreenNotificationIds: [Int64] = []
    
    init(typeFilters: [String], projectFilters: [String], dataProvider: PushNotificationsDataProvider, aggregateDictionary: EchoNotificationAggregateDictionary) {
        fetchRequest = FetchRequest<EchoNotification>(entity: EchoNotification.entity(), sortDescriptors: [NSSortDescriptor(keyPath: \EchoNotification.timestamp, ascending: false)], predicate: NSPredicate(format: "(type IN %@) AND (wiki IN %@)", typeFilters, projectFilters))
        self.dataProvider = dataProvider
        self.projectFilters = projectFilters
        self.aggregateDictionary = aggregateDictionary
        fetchNotifications(projectFilters: projectFilters)
    }
    
    var body: some View {
        List {
            ForEach(notifications, id: \.self) { notification in
                NotificationView(notification: notification)
                    .onAppear() {
                        self.onScreenNotificationIds.append(notification.id)
                        let isLast = notifications.last == notification
                        if isLast {
                            fetchNotifications(fetchType: .page, projectFilters: projectFilters)
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
                                fetchNotifications(projectFilters: projectFilters)
                            } label: {
                                Image(systemName: "arrow.clockwise")
                            }
                        })
    }
    
    private func fetchNotifications(fetchType: PushNotificationsDataProvider.FetchType = .reload, projectFilters: [String]) {
        loading = true
        dataProvider.fetchNotifications(fetchType: fetchType, projectFilters: projectFilters) { result in
            DispatchQueue.main.async {
                loading = false
                
                switch result {
                case .success():
                    print("success!")
                    
                    let notificationsOfType = notifications.filter { $0.type == "edit-user-talk" }
                        if let lastNotificationId = notificationsOfType.last?.id,
                           onScreenNotificationIds.contains(lastNotificationId) {
                            fetchNotifications(fetchType: .page, projectFilters: projectFilters)
                        } else if notificationsOfType.count == 0 {
                            fetchNotifications(fetchType: .page, projectFilters: projectFilters)
                        }
                    
                case .failure(let error):
                    print(error)
                }
                
                dataProvider.fetchAggregateNotifications(aggregateDictionary: aggregateDictionary)
            }
        }
    }
}
@available(iOS 13.0, *)
struct NotificationCenterListView_Previews: PreviewProvider {
    static var previews: some View {
        NotificationCenterListContainerView(dataProvider: PushNotificationsDataProvider.preview)
    }
}
