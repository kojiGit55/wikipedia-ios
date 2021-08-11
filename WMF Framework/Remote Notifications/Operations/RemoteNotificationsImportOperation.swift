
import Foundation

enum RemoteNotificationsImportError: Error {
    case missingListInResponse
}

class RemoteNotificationsImportOperation: RemoteNotificationsOperation {
    private let wiki: String
    init(with apiController: RemoteNotificationsAPIController, modelController: RemoteNotificationsModelController, wiki: String) {
        self.wiki = wiki
        super.init(with: apiController, modelController: modelController)
    }
    
    override func execute() {
        getAllNotifications(from: wiki, continueId: nil) { [weak self] result in
            
            guard let self = self else {
                return
            }
            
            switch result {
            case .success:
                self.finish()
            case .failure(let error):
                self.finish(with: error)
            }
        }
    }
    
    private func getAllNotifications(from subdomain: String, continueId: String?, completion: @escaping (Result<Void, Error>) -> Void) {
        
        self.apiController.getAllNotifications(from: self.wiki, continueId: continueId) { [weak self] result, error in
            
            guard let self = self else {
                return
            }
            
            if let error = error {
                completion(.failure(error))
                return
            }
                
            guard let fetchedNotifications = result?.list else {
                completion(.failure(RemoteNotificationsImportError.missingListInResponse))
                return
            }
            
            do {
                try self.modelController.createNewNotifications(from: Set(fetchedNotifications), bypassValidation: true) { [weak self] in
                    
                    guard let self = self else {
                        return
                    }
                    
                    guard let continueId = result?.continue else {
                        completion(.success(()))
                        return
                    }
                    
                    self.getAllNotifications(from: subdomain, continueId: continueId, completion: completion)
                    
                }
            } catch let error {
                completion(.failure(error))
            }
        }
    }
}
