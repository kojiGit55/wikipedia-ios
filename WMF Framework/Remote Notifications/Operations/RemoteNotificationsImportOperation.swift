class RemoteNotificationsImportOperation: RemoteNotificationsOperation {
    let languageCode: String

    init(with apiController: RemoteNotificationsAPIController, modelController: RemoteNotificationsModelController, languageCode: String) {
        self.languageCode = languageCode
        super.init(with: apiController, modelController: modelController)
    }
    
    override func execute() {
        importNotifications()
    }
    
    func importNotifications(continueId: String? = nil) {
        self.apiController.getAllNotifications(continueId: continueId, languageCode: self.languageCode) { [weak self] result, error in
            
            guard let self = self else {
                return
            }
            
            if let error = error {
                self.finish(with: error)
                return
            }

            guard let fetchedNotifications = result?.list else {
                self.finish(with: RequestError.unexpectedResponse)
                return
            }

            do {
                let backgroundContext = self.modelController.newBackgroundContext()
                try self.modelController.createNewNotifications(moc: backgroundContext, notificationsFetchedFromTheServer: Set(fetchedNotifications), completion: { [weak self] in

                    guard let self = self else {
                        return
                    }
                    
                    guard let newContinueId = result?.continueId,
                          newContinueId != continueId else {
                        self.finish()
                        return
                    }

                    self.importNotifications(continueId: newContinueId)
                })
            } catch let error {
                self.finish(with: error)
            }
        }
    }
}
