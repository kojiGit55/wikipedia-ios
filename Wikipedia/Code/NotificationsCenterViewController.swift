import UIKit

@objc
final class NotificationsCenterViewController: ViewController {

    // MARK: - Properties

    var notificationsView: NotificationsCenterView {
        return view as! NotificationsCenterView
    }

    let viewModel: NotificationsCenterViewModel
    
    typealias DataSource = UICollectionViewDiffableDataSource<NotificationsCenterSection, NotificationsCenterCellViewModel>
    typealias Snapshot = NSDiffableDataSourceSnapshot<NotificationsCenterSection, NotificationsCenterCellViewModel>
    private lazy var dataSource = makeDataSource()
    
    private let refreshControl = UIRefreshControl()

    // MARK: - Lifecycle

    @objc
    init(theme: Theme, viewModel: NotificationsCenterViewModel) {
        self.viewModel = viewModel
        super.init(theme: theme)
        viewModel.delegate = self
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

	override func loadView() {
		view = NotificationsCenterView(frame: UIScreen.main.bounds)
		scrollView = notificationsView.collectionView
	}

    override func viewDidLoad() {
        super.viewDidLoad()

        notificationsView.apply(theme: theme)

		title = CommonStrings.notificationsCenterTitle
		setupBarButtons()
        setupCollectionView()
        
        viewModel.fetchFirstPage()
	}
    
    func setupCollectionView() {
        notificationsView.collectionView.delegate = self
        notificationsView.collectionView.refreshControl = refreshControl
        refreshControl.addTarget(self, action: #selector(refresh(_:)), for: .valueChanged)
    }
    
    @objc private func refresh(_ sender: Any) {
        viewModel.refreshImportedNotifications(shouldResetData: true) { [weak self] in
            print("refresh complete")
            self?.refreshControl.endRefreshing()
        }
    }
    
    func makeDataSource() -> DataSource {
      // 1
      let dataSource = DataSource(
        collectionView: notificationsView.collectionView,
        cellProvider: { [weak self] (collectionView, indexPath, viewModel) -> 
          UICollectionViewCell? in
            //2
            guard let self = self,
                  let cell = collectionView.dequeueReusableCell(withReuseIdentifier: NotificationsCenterCell.reuseIdentifier, for: indexPath) as? NotificationsCenterCell else {
                return nil
            }
            cell.delegate = self
            cell.configure(viewModel: viewModel, theme: self.theme)
            return cell
      })
      return dataSource
    }
    
    func applySnapshot(animatingDifferences: Bool = true) {
        var snapshot = Snapshot()
        snapshot.appendSections([.main])
        snapshot.appendItems(self.viewModel.cellViewModels)
        self.dataSource.apply(snapshot, animatingDifferences: animatingDifferences)
    }

	// MARK: - Configuration

    fileprivate func setupBarButtons() {
        enableToolbar()
        setToolbarHidden(false, animated: false)

        let editButton = UIBarButtonItem(title: WMFLocalizedString("notifications-center-edit-button", value: "Edit", comment: "Title for navigation bar button to toggle mode for editing notification read status"), style: .plain, target: nil, action: nil)
        navigationItem.rightBarButtonItem = editButton
    }

	// MARK: - Edit button

	@objc func userDidTapEditButton() {

	}
}

extension NotificationsCenterViewController: NotificationCenterViewModelDelegate {
    func cellViewModelsDidChange() {
        applySnapshot(animatingDifferences: true)
    }
    
    func reloadCellWithViewModelIfNeeded(_ viewModel: NotificationsCenterCellViewModel) {
        for cell in notificationsView.collectionView.visibleCells {
            guard let cell = cell as? NotificationsCenterCell,
                  let cellViewModel = cell.viewModel,
                  cellViewModel == viewModel else {
                continue
            }
            
            cell.configure(viewModel: viewModel, theme: theme)
        }
    }
}

extension NotificationsCenterViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        let count = dataSource.collectionView(collectionView, numberOfItemsInSection: indexPath.section)
        let isLast = indexPath.row == count - 1
        if isLast {
            viewModel.fetchNextPage()
        }
    }
}

extension NotificationsCenterViewController: NotificationsCenterCellDelegate {
    func userDidTapSecondaryActionForCellIdentifier(id: String) {
        //nothing
    }
    
    func toggleReadStatus(notification: RemoteNotification) {
        //todo: mark as read/unread API call will be buried in here somewhere, for now just flip the read toggle on background context to demonstrate update flow
        self.viewModel.remoteNotificationsController.toggleNotificationReadStatus(notification: notification)
    }
}
