import Foundation
import CocoaLumberjackSwift

protocol NotificationCenterViewModelDelegate: AnyObject {
	func cellViewModelsDidChange()
    func reloadCellWithViewModelIfNeeded(_ viewModel: NotificationsCenterCellViewModel)
}

enum NotificationsCenterSection {
  case main
}

@objc
final class NotificationsCenterViewModel: NSObject {

    // MARK: - Properties

    let remoteNotificationsController: RemoteNotificationsController

	fileprivate var notifications: Set<RemoteNotification> = []

    weak var delegate: NotificationCenterViewModelDelegate?
    
    private var cellViewModelsDict: [String: NotificationsCenterCellViewModel] = [:]
    private(set) var cellViewModels: [NotificationsCenterCellViewModel] = []
    
    private var isImporting = true
    private var isPagingEnabled = true
    private var isFilteringOn = false
    var editMode = false {
        didSet {
            if oldValue != editMode {
                syncCellViewModels()
            }
        }
    }

	// MARK: - Lifecycle

	@objc
    init(remoteNotificationsController: RemoteNotificationsController) {
        print("init")
		self.remoteNotificationsController = remoteNotificationsController
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(contextObjectsDidChange(_:)), name: Notification.Name.NSManagedObjectContextObjectsDidChange, object: remoteNotificationsController.viewContext)
	}
    
    @objc func contextObjectsDidChange(_ notification: NSNotification) {
        print("contextObjectsDidChange")
        guard let refreshedNotifications = notification.userInfo?[NSRefreshedObjectsKey] as? Set<RemoteNotification> else {
            return
        }
        
        for refreshedNotification in refreshedNotifications {
            self.syncNotification(notification: refreshedNotification)
        }
        
        self.finalizeCellViewModelSync()
        
    }
    
    private func kickoffImportIfNeeded(primaryLanguageImportedCompletion: @escaping () -> Void) {
        print("kickoffImportIfNeeded")
        remoteNotificationsController.importNotificationsIfNeeded { [weak self] in
            DispatchQueue.main.async {
                self?.isImporting = false
                primaryLanguageImportedCompletion()
                print("primary language import check complete")
            }
        } allProjectsCompletion: {
            print("all projects import check complete")
        }
    }
    
    public func toggledFilter() {
        print("toggledFilter")
        resetData()
        isFilteringOn.toggle()
        fetchFirstPage()
    }
    
    public func refreshImportedNotifications(shouldResetData: Bool = false, completion: @escaping () -> Void) {
        
        print("refreshImportedNotifications")
        
        if (shouldResetData) {
            resetData()
        }
        
        remoteNotificationsController.refreshImportedNotifications { [weak self] in
            DispatchQueue.main.async {
                self?.fetchFirstPage()
                completion()
            }
        }
    }
    
    private func resetData() {
        print("resetData")
        notifications.removeAll()
        cellViewModelsDict.removeAll()
        cellViewModels.removeAll()
        isPagingEnabled = true
    }
    
    public func fetchFirstPage() {
        print("fetchFirstPage")
        kickoffImportIfNeeded { [weak self] in
            
            guard let self = self else {
                return
            }
            
            let notifications = self.remoteNotificationsController.fetchNotifications(isFilteringOn: self.isFilteringOn)
            for notification in notifications {
                self.notifications.insert(notification)
            }
            
            self.syncCellViewModels()
        }
    }
    
    func toggleCheckedStatus(cellViewModel: NotificationsCenterCellViewModel) {
        print("toggleCheckedStatus")
        cellViewModel.toggleCheckedStatus()
        syncCellViewModels()
    }
    
    func fetchNextPage() {
        print("fetchNextPage")
        guard isImporting == false else {
            DDLogDebug("Request to fetch next page while importing. Ignoring.")
            return
        }
        
        guard isPagingEnabled == true else {
            DDLogDebug("Request to fetch next page while paging is disabled. Ignoring.")
            return
        }
        
        let notifications = self.remoteNotificationsController.fetchNotifications(isFilteringOn: self.isFilteringOn, fetchOffset: notifications.count + 1)
        for notification in notifications {
            self.notifications.insert(notification)
        }
        
        guard notifications.count > 0 else {
            isPagingEnabled = false
            return
        }
        syncCellViewModels()
    }
    
    fileprivate func syncNotification(notification: RemoteNotification) {
        guard let key = notification.key else {
            return
        }
        
        if let currentViewModel = cellViewModelsDict[key] {
            
            //view model already exists. Update existing view model with any valueable new data from managed object (i.e., basically did the underlying core data notification change at all from the server). if it's not on screen, new data will be reflected when it scrolls on screen (this could probably be tested when we refresh. on current screen, when we refresh, if a notification comes back from the server looking different and that notification is persisted locally but not on screen yet, this section of code updates it to display the right thing when it is on screen).
            
            // if it IS on screen, trigger a cell reconfiguration from here.
            
            //this section may be overkill and/or incorrect, but for now it's needed for live reloading of
            //notifications that have changed in core data while a view model is on screen.
            //it seems to me a proper implementation of == in NotificationsCenterCellViewModel should automatically work
            //but it doesn't (causes duplicate cells, etc).
            currentViewModel.copyAnyValuableNewDataFromNotification(notification, editMode: self.editMode)
            delegate?.reloadCellWithViewModelIfNeeded(currentViewModel)
        } else {
            cellViewModelsDict[key] = NotificationsCenterCellViewModel(notification: notification, editMode: self.editMode)
        }
    }
    
    fileprivate func finalizeCellViewModelSync() {
        print("finalizeCellViewModelSync")
        DispatchQueue.main.async { //Note, pull to refresh fails here without the dispatch
            self.cellViewModels = self.cellViewModelsDict.values.sorted { lhs, rhs in
                guard let lhsDate = lhs.notification.date,
                      let rhsDate = rhs.notification.date else {
                    return false
                }
                return lhsDate > rhsDate
            }

            self.delegate?.cellViewModelsDidChange()
        }
    }

    fileprivate func syncCellViewModels() {
        print("syncCellViewModels")
        for notification in notifications {
            syncNotification(notification: notification)
        }
        
        finalizeCellViewModelSync()
    }
}
