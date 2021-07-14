
import SwiftUI

@available(iOS 13.0, *)
struct NotificationsTypePickerView: View {
    @SwiftUI.ObservedObject var filters: EchoNotificationTypeFilters
        
        var body: some View {
                List{
                    ForEach(0..<filters.typeFilters.count){ index in
                                HStack {
                                        Button(action: {
                                            filters.typeFilters[index].isSelected = filters.typeFilters[index].isSelected ? false : true
                                        }) {
                                                HStack{
                                                    if filters.typeFilters[index].isSelected {
                                                                Image(systemName: "checkmark.circle.fill")
                                                                        .foregroundColor(.green)
                                                        } else {
                                                                Image(systemName: "circle")
                                                                        .foregroundColor(.primary)
                                                        }
                                                    Text(filters.typeFilters[index].name)
                                                }
                                        }.buttonStyle(BorderlessButtonStyle())
                                }
                        }
                    
                    ForEach(0..<filters.projectFilters.count){ index in
                                HStack {
                                        Button(action: {
                                            filters.projectFilters[index].isSelected = filters.projectFilters[index].isSelected ? false : true
                                        }) {
                                                HStack{
                                                    if filters.projectFilters[index].isSelected {
                                                                Image(systemName: "checkmark.circle.fill")
                                                                        .foregroundColor(.green)
                                                        } else {
                                                                Image(systemName: "circle")
                                                                        .foregroundColor(.primary)
                                                        }
                                                    Text(filters.projectFilters[index].name)
                                                }
                                        }.buttonStyle(BorderlessButtonStyle())
                                }
                        }
                }
        }
}

@available(iOS 13.0, *)
class EchoNotificationTypeFilters: ObservableObject {
    @Published var typeFilters: [EchoNotificationFilter]
    @Published var projectFilters: [EchoNotificationFilter]
    
    init() {
        self.typeFilters = [
            EchoNotificationFilter(name: "edit-user-talk", isSelected: true),
            EchoNotificationFilter(name: "thank-you-edit", isSelected: true),
            EchoNotificationFilter(name: "reverted", isSelected: true),
        ]
        
        //todo: this will need to be populated with preferred language codes, plus wikidatawiki, commons maybe, etc.
        self.projectFilters = [
            EchoNotificationFilter(name: "enwiki", isSelected: false),
            EchoNotificationFilter(name: "wikidatawiki", isSelected: true)
        ]
    }
}

@available(iOS 13.0, *)
class EchoNotificationAggregateDictionary: ObservableObject {
    @Published var result: [[String: Any]]
    @Published var numProjects: Int
    @Published var numNotifications: Int
    
    init(result: [[String: Any]], numProjects: Int, numNotifications: Int) {
        self.result = result
        self.numProjects = numProjects
        self.numNotifications = numNotifications
    }
}

@available(iOS 13.0, *)
struct EchoNotificationFilter {
        let name: String
        var isSelected: Bool
    
    init(name: String, isSelected: Bool) {
        self.name = name
        self.isSelected = isSelected
    }
}
