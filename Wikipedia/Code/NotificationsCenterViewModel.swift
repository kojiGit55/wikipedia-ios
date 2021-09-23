import Foundation
import CocoaLumberjackSwift

@objc protocol NotificationCenterViewModelDelegate: AnyObject {
	func cellViewModelsDidChange()
}

enum NotificationsCenterSection {
  case main
}

@objc
final class NotificationsCenterViewModel: NSObject {

    // MARK: - Properties

    let remoteNotificationsController: RemoteNotificationsController

	fileprivate var fetchedResultsControllers: [NSFetchedResultsController<RemoteNotification>] = []

    weak var delegate: NotificationCenterViewModelDelegate?
    
    private(set) var cellViewModels: [NotificationsCenterCellViewModel] = []
    
    private var isImporting = true
    private var isPagingEnabled = true
    
//    private let serialBackgroundQueue: DispatchQueue = {
//        return DispatchQueue(label: "org.wikipedia.notifications.syncCells", qos: .userInitiated)
//    }()

	// MARK: - Lifecycle

	@objc
    init(remoteNotificationsController: RemoteNotificationsController) {
		self.remoteNotificationsController = remoteNotificationsController
        super.init()
	}
    
    private func kickoffImportIfNeeded() {
        
        isImporting = true
        remoteNotificationsController.importNotificationsIfNeeded {
            DispatchQueue.main.async { [weak self] in
                self?.isImporting = false
                print("import complete")
            }
        }
    }
    
    public func fetchFirstPage() {
        
        guard let fetchedResultsController = remoteNotificationsController.fetchedResultsController() else {
            assertionFailure("Failure setting up first page fetched results controller")
            return
        }
        
        appendFetchedResultsController(fetchedResultsController: fetchedResultsController)
        fetchedResultsController.delegate = self
        
        try? fetchedResultsController.performFetch()
        syncCellViewModels()
        
        kickoffImportIfNeeded()
    }
    
    public func fetchNextPage() {
        
        guard isImporting == false else {
            DDLogDebug("Request to fetch next page while importing. Ignoring.")
            return
        }
        
        guard isPagingEnabled == true else {
            DDLogDebug("Request to fetch next page while paging is disabled. Ignoring.")
            return
        }
        
        guard let nextFetchedResultsController = remoteNotificationsController.fetchedResultsController(fetchOffset: cellViewModels.count) else {
            assertionFailure("Falure setting up next page fetched results controller")
            return
        }
        
        appendFetchedResultsController(fetchedResultsController: nextFetchedResultsController)
        nextFetchedResultsController.delegate = self
        try? nextFetchedResultsController.performFetch()
        
        guard (nextFetchedResultsController.fetchedObjects ?? []).count > 0 else {
            isPagingEnabled = false
            return
        }
        syncCellViewModels()
    }
    
    private func appendFetchedResultsController(fetchedResultsController: NSFetchedResultsController<RemoteNotification>) {
        self.fetchedResultsControllers.append(fetchedResultsController)
    }

    fileprivate func syncCellViewModels() {
    
        var managedObjects: [RemoteNotification] = []
        for fetchedResultsController in self.fetchedResultsControllers {
            managedObjects.append(contentsOf: (fetchedResultsController.fetchedObjects ?? []))
        }
        
        let cellViewModels = managedObjects.map { NotificationsCenterCellViewModel(notification: $0) }
            
        self.cellViewModels = cellViewModels
        delegate?.cellViewModelsDidChange()
    }
}

extension NotificationsCenterViewModel: NSFetchedResultsControllerDelegate {
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        print("controllerDidChangeContent")
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        print("controllerDidChangeContent")
        syncCellViewModels()
    }
    
}
