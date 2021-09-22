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
    
    private let serialBackgroundQueue: DispatchQueue = {
        return DispatchQueue(label: "org.wikipedia.notifications.syncCells", qos: .userInitiated)
    }()

	// MARK: - Lifecycle

	@objc
    init(remoteNotificationsController: RemoteNotificationsController) {
		self.remoteNotificationsController = remoteNotificationsController
        super.init()
	}
    
    private func kickoffImport() {
        assert(delegate != nil, "Delegate must not be nil.")
        
        isImporting = true
        remoteNotificationsController.importNotificationsIfNeeded {
            DispatchQueue.main.async { [weak self] in
                self?.isImporting = false
                print("import complete")
            }
        }
    }
    
    //call after delegate is set
    public func fetchFirstPage() {
        assert(delegate != nil, "Delegate must not be nil.")
        
        guard let fetchedResultsController = remoteNotificationsController.fetchedResultsController() else {
            assertionFailure("Failure setting up first page fetched results controller")
            return
        }
        
        appendFetchedResultsController(fetchedResultsController: fetchedResultsController)
        fetchedResultsController.delegate = self
        
        try? fetchedResultsController.performFetch()
        syncCellViewModels() //need to call sync once just in case we've already imported
        
        kickoffImport()
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
        if (nextFetchedResultsController.fetchedObjects ?? []).count == 0 {
            isPagingEnabled = false
            return
        }
        syncCellViewModels()
    }
    
    private func appendFetchedResultsController(fetchedResultsController: NSFetchedResultsController<RemoteNotification>) {
        serialBackgroundQueue.async {
            self.fetchedResultsControllers.append(fetchedResultsController)
        }
    }

    fileprivate func syncCellViewModels() {
        
        //Maybe we could move *something* to a background thread here since it's called so much. Not sure.
        serialBackgroundQueue.async {
            var managedObjects: [RemoteNotification] = []
            for fetchedResultsController in self.fetchedResultsControllers {
                managedObjects.append(contentsOf: (fetchedResultsController.fetchedObjects ?? []))
            }
            
            let cellViewModels = managedObjects.map { NotificationsCenterCellViewModel(notification: $0) }

            DispatchQueue.main.async {
                
                self.cellViewModels = cellViewModels
                self.delegate?.cellViewModelsDidChange()
            }
        }
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
