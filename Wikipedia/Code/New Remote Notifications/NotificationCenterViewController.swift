
import UIKit

class NotificationCenterViewController: UIViewController {
    
    private let tableView: UITableView = {
        let tableView = UITableView(frame: .zero)
        return tableView
    }()
    
    private let reuseIdentifier = "NotificationCenterTableViewCell"
    private let dataProvider: PushNotificationsDataProvider
    
    fileprivate lazy var fetchedResultsController: NSFetchedResultsController<EchoNotification> = {
        // Create Fetch Request
        let fetchRequest: NSFetchRequest<EchoNotification> = EchoNotification.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]

        // Create Fetched Results Controller
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.dataProvider.container.viewContext, sectionNameKeyPath: nil, cacheName: nil)

        // Configure Fetched Results Controller
        fetchedResultsController.delegate = self

        return fetchedResultsController
    }()
    
    init(dataProvider: PushNotificationsDataProvider) {
        self.dataProvider = dataProvider
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
            try self.fetchedResultsController.performFetch()
        } catch {
            let fetchError = error as NSError
            print("Unable to Perform Fetch Request")
            print("\(fetchError), \(fetchError.localizedDescription)")
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        dataProvider.fetchNotifications(projectFilters: ["enwiki"]) { result in
            switch result {
            case .success():
                print("success!")
            case .failure(let error):
                print(error)
            }
        }
    }
    
    private func setupTableView() {
        tableView.dataSource = self
        tableView.register(NotificationCenterTableViewCell.self, forCellReuseIdentifier: reuseIdentifier)
        view.addSubview(tableView)
        view.wmf_addConstraintsToEdgesOfView(tableView)
    }
}

extension NotificationCenterViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        guard let notifications = fetchedResultsController.fetchedObjects else { return 0 }
        return notifications.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath)
        
        guard let notificationCell = cell as? NotificationCenterTableViewCell else {
            return cell
        }
        
        // Fetch Quote
        let notification = fetchedResultsController.object(at: indexPath)
        
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
        default:
            print("...")
            //TODO: update, whatever else
        }
    }
}
