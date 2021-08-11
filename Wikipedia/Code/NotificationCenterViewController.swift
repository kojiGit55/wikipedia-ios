
import UIKit

extension Notification.Name {
    static let removeNotificationsBadge = Notification.Name("removeNotificationsBadge")
}

class NotificationCenterViewController: UIViewController {
    
    private let tableView: UITableView = {
        let tableView = UITableView(frame: .zero)
        return tableView
    }()
    
    private let reuseIdentifier = "NotificationCenterTableViewCell"
    private let dataStore: MWKDataStore
    
    private let refreshControl = UIRefreshControl()
    
    fileprivate lazy var fetchedResultsController: NSFetchedResultsController<RemoteNotification>? = {
        
        guard let viewContext = self.dataStore.remoteNotificationsController.viewContext else {
            return nil
        }
        
        let fetchRequest: NSFetchRequest<RemoteNotification> = RemoteNotification.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]

        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: viewContext, sectionNameKeyPath: nil, cacheName: nil)

        fetchedResultsController.delegate = self

        return fetchedResultsController
    }()
    
    init(dataStore: MWKDataStore) {
        self.dataStore = dataStore
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .white
        setupTableView()
        self.navigationController?.setNavigationBarHidden(false, animated: false)
        
        do {
            try self.fetchedResultsController?.performFetch()
        } catch {
            let fetchError = error as NSError
            print("Unable to Perform Fetch Request")
            print("\(fetchError), \(fetchError.localizedDescription)")
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        dataStore.remoteNotificationsController.importPreferredWikiNotificationsIfNeeded {
            print("import complete")
        }
        
        NotificationCenter.default.post(name: NSNotification.Name.removeNotificationsBadge, object: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        self.navigationController?.setNavigationBarHidden(true, animated: false)
    }
    
    private func setupTableView() {
        tableView.dataSource = self
        tableView.register(NotificationCenterTableViewCell.self, forCellReuseIdentifier: reuseIdentifier)
        tableView.refreshControl = refreshControl
        refreshControl.addTarget(self, action: #selector(refresh(_:)), for: .valueChanged)
        view.addSubview(tableView)
        view.wmf_addConstraintsToEdgesOfView(tableView)
    }
    
    @objc private func refresh(_ sender: Any) {
        dataStore.remoteNotificationsController.refreshImportedNotifications { [weak self] in
            DispatchQueue.main.async {
                print("refresh complete")
                self?.refreshControl.endRefreshing()
            }
        }
    }
}

extension NotificationCenterViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        guard let notifications = fetchedResultsController?.fetchedObjects else { return 0 }
        return notifications.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath)
        
        guard let notificationCell = cell as? NotificationCenterTableViewCell,
              let fetchedResultsController = fetchedResultsController else {
            return cell
        }
        
        let notification = fetchedResultsController.object(at: indexPath)
        
        notificationCell.delegate = self
        notificationCell.configure(notification: notification)
        return notificationCell
    }
    
    
}

extension NotificationCenterViewController: NSFetchedResultsControllerDelegate {
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.beginUpdates()
    }

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch (type) {
        case .insert:
            if let indexPath = newIndexPath {
                tableView.insertRows(at: [indexPath], with: .fade)
            }
            break;
        case .delete:
            if let indexPath = indexPath {
                tableView.deleteRows(at: [indexPath], with: .fade)
            }
            break;
        case .update:
            if let indexPath = indexPath,
               let notification = fetchedResultsController?.object(at: indexPath),
               let cell = tableView.cellForRow(at: indexPath) as? NotificationCenterTableViewCell {
                cell.configure(notification: notification)
            }
        case .move:
            if let indexPath = indexPath,
               let newIndexPath = newIndexPath {
                tableView.deleteRows(at: [indexPath], with: .fade)
                tableView.insertRows(at: [newIndexPath], with: .fade)
            }
            break
        @unknown default:
            break
        }
    }
}

extension NotificationCenterViewController: NotificationCenterTableViewCellDelegate {
    func markNotificationAsRead(_ notification: RemoteNotification) {
        self.dataStore.remoteNotificationsController.markAsRead(notification: notification) {
            print("marked as read")
        }
    }
}
