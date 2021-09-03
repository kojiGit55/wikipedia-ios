import Foundation
import CoreData

@objc(RemoteNotification)
public class RemoteNotification: NSManagedObject {
    lazy var type: RemoteNotificationType = {
        return calculateRemoteNotificationType()
    }()
    
    public override func didChangeValue(forKey key: String,
        withSetMutation mutationKind: NSKeyValueSetMutationKind,
        using objects: Set<AnyHashable>) {
        if key == "categoryString" || key == "typeString" {
            type = calculateRemoteNotificationType()
        }
        super.didChangeValue(forKey: key, withSetMutation: mutationKind, using: objects)
    }
}

private extension RemoteNotification {
    func calculateRemoteNotificationType() -> RemoteNotificationType {
        switch (categoryString, typeString) {
        default:
            return .editReverted
        }
    }
}
