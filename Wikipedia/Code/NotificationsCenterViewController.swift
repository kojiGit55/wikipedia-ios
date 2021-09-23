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

    // MARK: - Lifecycle

    @objc
    init(theme: Theme, viewModel: NotificationsCenterViewModel) {
        self.viewModel = viewModel
        super.init(theme: theme)
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
        notificationsView.collectionView.delegate = self
        
        viewModel.delegate = self
        viewModel.fetchFirstPage()
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

            cell.configure(viewModel: viewModel, theme: self.theme)
            return cell
      })
      return dataSource
    }
    
    // 1
//originally tried calling this in viewDidLoad(), then adding progressive snapshot checking in applySnapshot (see commented out note)
//    func setupInitialSnapshot() {
//        var snapshot = Snapshot()
//        snapshot.appendSections([.main])
//        snapshot.appendItems([])
//        dataSource.apply(snapshot, animatingDifferences: false)
//    }
    
    func applySnapshot(animatingDifferences: Bool = true) {
      //NOTE: if we build off of the last snapshot, the sorting defined in NSFetchedResultsController could get thrown off upon import, so we are creating a brand new snapshot each time to consider.
      //  var snapshot = dataSource.snapshot()

        print("applySnapshot")
      var snapshot = Snapshot()
      snapshot.appendSections([.main]) //tried commenting this out to get progressive working.
      snapshot.appendItems(self.viewModel.cellViewModels)
      dataSource.apply(snapshot, animatingDifferences: animatingDifferences)
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
}

extension NotificationsCenterViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        let count = dataSource.collectionView(collectionView, numberOfItemsInSection: indexPath.section)
        let isLast = indexPath.row == count - 1
        if isLast {
                self.viewModel.fetchNextPage()
        }
    }
}
