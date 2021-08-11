
import Foundation

class RemoteNotificationsRefreshOperation: RemoteNotificationsOperation {
    private let wiki: String
    init(with apiController: RemoteNotificationsAPIController, modelController: RemoteNotificationsModelController, wiki: String) {
        self.wiki = wiki
        super.init(with: apiController, modelController: modelController)
    }
}
