import UIKit

class PluginListViewController: UIViewController {

    @IBOutlet private var tableView: UITableView!

    private let viewModel: PluginListViewModel

    init?(coder: NSCoder, viewModel: PluginListViewModel) {
        self.viewModel = viewModel
        super.init(coder: coder)
    }

    required init?(coder: NSCoder) {
        fatalError("⛔️ You must create this view controller with a view model!")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureTableView()
        viewModel.activate()
    }
}

// MARK: - UI configurations
//
private extension PluginListViewController {
    func configureTableView() {
        tableView.registerNib(for: PluginTableViewCell.self)
        tableView.estimatedRowHeight = CGFloat(44)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.backgroundColor = .listBackground
        tableView.dataSource = self
        tableView.delegate = self
    }
}

// MARK: - UITableViewDataSource conformance
//
extension PluginListViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        viewModel.numberOfSections
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.numberOfRows(inSection: section)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(PluginTableViewCell.self, for: indexPath)
        let cellModel = viewModel.cellModelForRow(at: indexPath)
        cell.update(viewModel: cellModel)
        return cell
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        viewModel.titleForSection(at: section)
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return UITableView.automaticDimension
    }
}

// MARK: - UITableViewDelegate conformance
//
extension PluginListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
