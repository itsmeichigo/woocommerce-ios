import XCTest
@testable import Storage
@testable import WooCommerce
@testable import Yosemite

class PluginListViewModelTests: XCTestCase {

    private let sampleSiteID: Int64 = 134

    /// Mock Storage: InMemory
    ///
    private var storageManager: StorageManagerType!

    /// View storage for tests
    ///
    private var storage: StorageType {
        storageManager.viewStorage
    }

    override func setUp() {
        super.setUp()
        storageManager = MockStorageManager()
    }

    override func tearDown() {
        storageManager = nil
        super.tearDown()
    }

    func test_data_source_is_correct_after_activation() {
        // Given
        let activePlugin = SitePlugin.fake().copy(
            siteID: sampleSiteID,
            status: .active,
            name: "BBB",
            descriptionRaw: "Lorem ipsum <strong>random HTML content</strong>"
        )
        insert(activePlugin)

        let inactivePlugin1 = SitePlugin.fake().copy(siteID: sampleSiteID, status: .inactive, name: "CCC")
        insert(inactivePlugin1)

        let inactivePlugin2 = SitePlugin.fake().copy(siteID: sampleSiteID, status: .inactive, name: "AAA")
        insert(inactivePlugin2)

        let viewModel = PluginListViewModel(siteID: sampleSiteID, storageManager: storageManager)

        // When
        viewModel.activate {}

        // Then
        XCTAssertEqual(viewModel.numberOfSections, 2)
        XCTAssertEqual(viewModel.titleForSection(at: 0), "Active Plugins")
        XCTAssertEqual(viewModel.titleForSection(at: 1), "Inactive Plugins")
        XCTAssertEqual(viewModel.numberOfRows(inSection: 0), 1)
        XCTAssertEqual(viewModel.numberOfRows(inSection: 1), 2)
        XCTAssertEqual(viewModel.cellModelForRow(at: IndexPath(row: 0, section: 0)).name, activePlugin.name)
        XCTAssertEqual(viewModel.cellModelForRow(at: IndexPath(row: 0, section: 0)).description, "Lorem ipsum random HTML content")
        XCTAssertEqual(viewModel.cellModelForRow(at: IndexPath(row: 0, section: 1)).name, inactivePlugin2.name)
        XCTAssertEqual(viewModel.cellModelForRow(at: IndexPath(row: 1, section: 1)).name, inactivePlugin1.name)
    }

    func test_data_source_is_correct_after_plugin_status_is_updated() {
        // Given
        let activePlugin = SitePlugin.fake().copy(
            siteID: sampleSiteID,
            status: .active,
            name: "AAA"
        )
        insert(activePlugin)

        let viewModel = PluginListViewModel(siteID: sampleSiteID, storageManager: storageManager)
        let expect = expectation(description: "Section info is updated correctly.")
        viewModel.activate {
            expect.fulfill()
        }
        XCTAssertEqual(viewModel.numberOfSections, 1)
        XCTAssertEqual(viewModel.titleForSection(at: 0), "Active Plugins")

        // When
        updateStorage(with: activePlugin.copy(status: .inactive))

        // Then
        waitForExpectations(timeout: Constants.expectationTimeout) { _ in
            XCTAssertEqual(viewModel.numberOfSections, 1)
            XCTAssertEqual(viewModel.titleForSection(at: 0), "Inactive Plugins")
        }
    }

    func test_data_source_is_correct_after_plugin_is_deleted() {
        // Given
        let plugin1 = SitePlugin.fake().copy(
            siteID: sampleSiteID,
            status: .active,
            name: "AAA"
        )
        insert(plugin1)

        let plugin2 = SitePlugin.fake().copy(
            siteID: sampleSiteID,
            status: .active,
            name: "BBB"
        )
        insert(plugin2)

        let viewModel = PluginListViewModel(siteID: sampleSiteID, storageManager: storageManager)
        let expect = expectation(description: "Data source is updated correctly.")
        viewModel.activate {
            expect.fulfill()
        }
        XCTAssertEqual(viewModel.numberOfRows(inSection: 0), 2)

        // When
        storage.deleteStalePlugins(siteID: sampleSiteID, installedPluginNames: [plugin2.name])

        // Then
        waitForExpectations(timeout: Constants.expectationTimeout) { _ in
            XCTAssertEqual(viewModel.numberOfRows(inSection: 0), 1)
            XCTAssertEqual(viewModel.cellModelForRow(at: IndexPath(row: 0, section: 0)).name, plugin2.name)
        }
    }

    func test_resyncPlugins_dispatches_correct_action() {
        // Given
        let storesManager = MockPluginStoresManager(shouldSucceed: true)
        let viewModel = PluginListViewModel(siteID: sampleSiteID, storesManager: storesManager)

        // When
        viewModel.resyncPlugins {}

        // Then
        XCTAssertTrue(storesManager.invokedSynchronizePlugins)
        XCTAssertEqual(storesManager.invokedSynchronizePluginsWithSiteID, sampleSiteID)
    }

    func test_resyncPlugins_updates_pluginListState_to_results_when_synchronization_succeeds() {
        // Given
        let delay: TimeInterval = 1
        let expect = expectation(description: "Plugin list state is updated correctly")
        let storesManager = MockPluginStoresManager(shouldSucceed: true, completionDelay: 1)
        let viewModel = PluginListViewModel(siteID: sampleSiteID, storesManager: storesManager)

        // When
        viewModel.resyncPlugins {}

        // Then
        XCTAssertEqual(viewModel.pluginListState, .syncing)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            XCTAssertEqual(viewModel.pluginListState, .results)
            expect.fulfill()
        }
        waitForExpectations(timeout: Constants.expectationTimeout, handler: nil)
    }

    func test_resyncPlugins_updates_pluginListState_to_error_when_synchronization_fails() {
        // Given
        let delay: TimeInterval = 1
        let expect = expectation(description: "Plugin list state is updated correctly")
        let storesManager = MockPluginStoresManager(shouldSucceed: false, completionDelay: delay)
        let viewModel = PluginListViewModel(siteID: sampleSiteID, storesManager: storesManager)

        // When
        viewModel.resyncPlugins {}

        // Then
        XCTAssertEqual(viewModel.pluginListState, .syncing)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            XCTAssertEqual(viewModel.pluginListState, .error)
            expect.fulfill()
        }
        waitForExpectations(timeout: Constants.expectationTimeout, handler: nil)
    }
}

private extension PluginListViewModelTests {
    func insert(_ readOnlyPlugin: Yosemite.SitePlugin) {
        let plugin = storage.insertNewObject(ofType: StorageSitePlugin.self)
        plugin.update(with: readOnlyPlugin)
        storage.saveIfNeeded()
    }

    func updateStorage(with readOnlyPlugin: Yosemite.SitePlugin) {
        guard let plugin = storage.loadPlugin(siteID: readOnlyPlugin.siteID, name: readOnlyPlugin.name) else {
            return
        }
        plugin.update(with: readOnlyPlugin)
        storage.saveIfNeeded()
    }
}

final class MockPluginStoresManager: DefaultStoresManager {
    /// Whether synchronizePlugins action was triggered.
    ///
    var invokedSynchronizePlugins = false

    /// The site ID that the `synchronizePlugins` action was triggered with.
    ///
    var invokedSynchronizePluginsWithSiteID: Int64 = 0

    /// Whether the mock `synchronizePlugins` action handler should succeed.
    ///
    private let shouldSucceed: Bool

    /// Delay time for completion block of the mock `synchronizePlugins` action.
    ///
    private let completionDelay: TimeInterval

    enum MockPluginError: Error {
        case mockError
    }

    init(shouldSucceed: Bool, completionDelay: TimeInterval = 0) {
        self.shouldSucceed = shouldSucceed
        self.completionDelay = completionDelay
        let sessionManager = SessionManager.testingInstance
        sessionManager.setStoreId(134)
        super.init(sessionManager: sessionManager)
    }

    // MARK: - Overridden Methods
    override func dispatch(_ action: Action) {
        if let sitePluginAction = action as? SitePluginAction {
            onPluginAction(sitePluginAction)
        }
    }

    private func onPluginAction(_ action: SitePluginAction) {
        switch action {
        case .synchronizeSitePlugins(let siteID, let onCompletion):
            invokedSynchronizePlugins = true
            invokedSynchronizePluginsWithSiteID = siteID
            DispatchQueue.main.asyncAfter(deadline: .now() + completionDelay) { [weak self] in
                if self?.shouldSucceed == true {
                    onCompletion(.success(()))
                } else {
                    onCompletion(.failure(MockPluginError.mockError))
                }
            }
        }
    }
}
