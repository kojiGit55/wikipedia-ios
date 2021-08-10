
import Foundation

extension EchoNotification {
    
    @discardableResult
    static func makePreviews(count: Int) -> [EchoNotification] {
        var echoNotifications = [EchoNotification]()
        let viewContext = PushNotificationsDataProvider.preview.container.viewContext
        for index in 0..<count {
            let echoNotification = EchoNotification(context: viewContext)
            echoNotification.id = Int64(index)
            echoNotification.revId = Int64.random(in: 0...Int64.max)
            let agentId = Int64.random(in: 0...Int64.max)
            echoNotification.agentId = agentId
            echoNotification.agentName = "Name-\(agentId)"
            echoNotification.header = "Header Text"
            echoNotification.readDate = index % 2 == 0 ? Date() : nil
            echoNotification.timestamp = Date()
            echoNotification.title = "Title Text"
            echoNotification.type = "edit-user-talk"
            echoNotification.wiki = "enwiki"
            echoNotifications.append(echoNotification)
        }
        return echoNotifications
    }
    
    convenience init(remoteNotification: RemoteEchoNotification, moc: NSManagedObjectContext) {
        self.init(entity: EchoNotification.entity(), insertInto: moc)
        self.id = Int64(remoteNotification.id)
        if let revId = remoteNotification.revId {
            self.revId = Int64(revId)
        } else {
            self.revId = -1 //todo: maybe NSNumber here to handle optional
        }
        
        if let remoteAgentId = remoteNotification.agentId {
            self.agentId = Int64(remoteAgentId)
        } else {
            self.agentId = 0
        }
        
        self.agentName = remoteNotification.agentName
        self.header = remoteNotification.header
        self.readDate = remoteNotification.readDate
        self.timestamp = remoteNotification.timestamp
        self.timestampUnix = remoteNotification.timestampUnix
        self.title = remoteNotification.title
        self.type = remoteNotification.type.rawValue
        self.wiki = remoteNotification.wiki
    }
}
