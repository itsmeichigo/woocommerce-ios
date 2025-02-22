import Storage
import Networking

// MARK: - AppSettingsStore
//
public class AppSettingsStore: Store {
    /// Loads a plist file at a given URL
    ///
    private let fileStorage: FileStorage

    /// Designated initaliser
    ///
    public init(dispatcher: Dispatcher,
                storageManager: StorageManagerType,
                fileStorage: FileStorage) {
        self.fileStorage = fileStorage
        super.init(dispatcher: dispatcher,
                   storageManager: storageManager,
                   network: NullNetwork())
    }

    /// URL to the plist file that we use to store the user selected
    /// shipment tracing provider. Not declared as `private` so it can
    /// be overridden in tests
    ///
    lazy var selectedProvidersURL: URL = {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        return documents!.appendingPathComponent(Constants.shipmentProvidersFileName)
    }()

    /// URL to the plist file that we use to store the user selected
    /// custom shipment tracing provider. Not declared as `private` so it can
    /// be overridden in tests
    ///
    lazy var customSelectedProvidersURL: URL = {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        return documents!.appendingPathComponent(Constants.customShipmentProvidersFileName)
    }()

    /// URL to the plist file that we use to determine the visibility for stats version banner.
    ///
    private lazy var statsVersionBannerVisibilityURL: URL = {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        return documents!.appendingPathComponent(Constants.statsVersionBannerVisibilityFileName)
    }()

    /// URL to the plist file that we use to store the stats version displayed on Dashboard UI.
    ///
    private lazy var statsVersionLastShownURL: URL = {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        return documents!.appendingPathComponent(Constants.statsVersionLastShownFileName)
    }()

    /// URL to the plist file that we use to determine the visibility for Product features.
    ///
    private lazy var productsFeatureSwitchURL: URL = {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        return documents!.appendingPathComponent(Constants.productsFeatureSwitchFileName)
    }()

    /// URL to the plist file that we use to determine the visibility for Product features M3.
    ///
    private lazy var productsRelease3FeatureSwitchURL: URL = {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        return documents!.appendingPathComponent(Constants.productsRelease3FeatureSwitchFileName)
    }()

    /// URL to the plist file that we use to determine the visibility for Product features M4.
    ///
    private lazy var productsRelease4FeatureSwitchURL: URL = {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        return documents!.appendingPathComponent(Constants.productsRelease4FeatureSwitchFileName)
    }()

    private lazy var generalAppSettingsFileURL: URL! = {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        return documents!.appendingPathComponent(Constants.generalAppSettingsFileName)
    }()

    /// URL to the plist file that we use to determine the settings applied in Products
    ///
    private lazy var productsSettingsURL: URL = {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        return documents!.appendingPathComponent(Constants.productsSettings)
    }()

    /// Registers for supported Actions.
    ///
    override public func registerSupportedActions(in dispatcher: Dispatcher) {
        dispatcher.register(processor: self, for: AppSettingsAction.self)
    }

    /// Receives and executes Actions.
    ///
    override public func onAction(_ action: Action) {
        guard let action = action as? AppSettingsAction else {
            assertionFailure("ShipmentStore received an unsupported action")
            return
        }

        switch action {
        case .addTrackingProvider(let siteID, let providerName, let onCompletion):
            addTrackingProvider(siteID: siteID,
                                providerName: providerName,
                                onCompletion: onCompletion)
        case .loadTrackingProvider(let siteID, let onCompletion):
            loadTrackingProvider(siteID: siteID,
                                 onCompletion: onCompletion)
        case .addCustomTrackingProvider(let siteID,
                                        let providerName,
                                        let providerURL,
                                        let onCompletion):
            addCustomTrackingProvider(siteID: siteID,
                                      providerName: providerName,
                                      providerURL: providerURL,
                                      onCompletion: onCompletion)
        case .loadCustomTrackingProvider(let siteID,
                                         let onCompletion):
            loadCustomTrackingProvider(siteID: siteID,
                                       onCompletion: onCompletion)
        case .resetStoredProviders(let onCompletion):
            resetStoredProviders(onCompletion: onCompletion)
        case .setStatsVersionLastShown(let siteID, let statsVersion):
            setStatsVersionLastShownOrFromUserPreference(siteID: siteID, statsVersion: statsVersion)
        case .loadInitialStatsVersionToShow(let siteID, let onCompletion):
            loadInitialStatsVersionToShow(siteID: siteID, onCompletion: onCompletion)
        case .loadStatsVersionBannerVisibility(let banner, let onCompletion):
            loadStatsVersionBannerVisibility(banner: banner, onCompletion: onCompletion)
        case .setStatsVersionBannerVisibility(let banner, let shouldShowBanner):
            setStatsVersionBannerVisibility(banner: banner, shouldShowBanner: shouldShowBanner)
        case .resetStatsVersionStates:
            resetStatsVersionStates()
        case .loadProductsFeatureSwitch(let onCompletion):
            loadProductsFeatureSwitch(onCompletion: onCompletion)
        case .setProductsFeatureSwitch(let isEnabled, let onCompletion):
            setProductsFeatureSwitch(isEnabled: isEnabled, onCompletion: onCompletion)
        case .resetFeatureSwitches:
            resetFeatureSwitches()
        case .setInstallationDateIfNecessary(let date, let onCompletion):
            setInstallationDateIfNecessary(date: date, onCompletion: onCompletion)
        case .updateFeedbackStatus(let type, let status, let onCompletion):
            updateFeedbackStatus(type: type, status: status, onCompletion: onCompletion)
        case .loadFeedbackVisibility(let type, let onCompletion):
            loadFeedbackVisibility(type: type, onCompletion: onCompletion)
        case .loadProductsSettings(let siteID, let onCompletion):
            loadProductsSettings(siteID: siteID, onCompletion: onCompletion)
        case .upsertProductsSettings(let siteID, let sort, let stockStatusFilter, let productStatusFilter, let productTypeFilter, let onCompletion):
            upsertProductsSettings(siteID: siteID,
                                   sort: sort,
                                   stockStatusFilter: stockStatusFilter,
                                   productStatusFilter: productStatusFilter,
                                   productTypeFilter: productTypeFilter,
                                   onCompletion: onCompletion)
        case .resetProductsSettings:
            resetProductsSettings()
        case .setOrderAddOnsFeatureSwitchState(isEnabled: let isEnabled, onCompletion: let onCompletion):
            setOrderAddOnsFeatureSwitchState(isEnabled: isEnabled, onCompletion: onCompletion)
        case .loadOrderAddOnsSwitchState(onCompletion: let onCompletion):
            loadOrderAddOnsSwitchState(onCompletion: onCompletion)
        }
    }
}

// MARK: - General App Settings

private extension AppSettingsStore {
    /// Save the `date` in `GeneralAppSettings` but only if the `date` is older than the existing
    /// `GeneralAppSettings.installationDate`.
    ///
    /// - Parameter onCompletion: The `Result`'s success value will be `true` if the installation
    ///                           date was changed and `false` if not.
    ///
    func setInstallationDateIfNecessary(date: Date, onCompletion: ((Result<Bool, Error>) -> Void)) {
        do {
            let settings = loadOrCreateGeneralAppSettings()

            if let installationDate = settings.installationDate,
               date > installationDate {
                return onCompletion(.success(false))
            }

            let settingsToSave = settings.copy(installationDate: date)
            try saveGeneralAppSettings(settingsToSave)

            onCompletion(.success(true))
        } catch {
            onCompletion(.failure(error))
        }
    }

    /// Updates the feedback store  in `GeneralAppSettings` with the given `type` and `status`.
    ///
    func updateFeedbackStatus(type: FeedbackType, status: FeedbackSettings.Status, onCompletion: ((Result<Void, Error>) -> Void)) {
        do {
            let settings = loadOrCreateGeneralAppSettings()
            let newFeedback = FeedbackSettings(name: type, status: status)
            let settingsToSave = settings.replacing(feedback: newFeedback)
            try saveGeneralAppSettings(settingsToSave)

            onCompletion(.success(()))
        } catch {
            onCompletion(.failure(error))
        }
    }

    func loadFeedbackVisibility(type: FeedbackType, onCompletion: (Result<Bool, Error>) -> Void) {
        let settings = loadOrCreateGeneralAppSettings()
        let useCase = InAppFeedbackCardVisibilityUseCase(settings: settings, feedbackType: type)

        onCompletion(Result {
            try useCase.shouldBeVisible()
        })
    }

    /// Sets the provided Order Add-Ons beta feature switch state into `GeneralAppSettings`
    ///
    func setOrderAddOnsFeatureSwitchState(isEnabled: Bool, onCompletion: (Result<Void, Error>) -> Void) {
        do {
            let settings = loadOrCreateGeneralAppSettings().copy(isViewAddOnsSwitchEnabled: isEnabled)
            try saveGeneralAppSettings(settings)
            onCompletion(.success(()))
        } catch {
            onCompletion(.failure(error))
        }

    }

    /// Loads the current Order Add-Ons beta feature switch state from `GeneralAppSettings`
    ///
    func loadOrderAddOnsSwitchState(onCompletion: (Result<Bool, Error>) -> Void) {
        let settings = loadOrCreateGeneralAppSettings()
        onCompletion(.success(settings.isViewAddOnsSwitchEnabled))
    }

    /// Load the `GeneralAppSettings` from file or create an empty one if it doesn't exist.
    func loadOrCreateGeneralAppSettings() -> GeneralAppSettings {
        guard let settings: GeneralAppSettings = try? fileStorage.data(for: generalAppSettingsFileURL) else {
            return GeneralAppSettings(installationDate: nil, feedbacks: [:], isViewAddOnsSwitchEnabled: false)
        }

        return settings
    }

    /// Save the `GeneralAppSettings` to the appropriate file.
    func saveGeneralAppSettings(_ settings: GeneralAppSettings) throws {
        try fileStorage.write(settings, to: generalAppSettingsFileURL)
    }
}

// MARK: - Shipment tracking providers!
//
private extension AppSettingsStore {
    func addTrackingProvider(siteID: Int64,
                             providerName: String,
                             onCompletion: (Error?) -> Void) {
        addProvider(siteID: siteID,
                    providerName: providerName,
                    fileURL: selectedProvidersURL,
                    onCompletion: onCompletion)

    }

    func addCustomTrackingProvider(siteID: Int64,
                                   providerName: String,
                                   providerURL: String?,
                                   onCompletion: (Error?) -> Void) {
        addProvider(siteID: siteID,
                    providerName: providerName,
                    providerURL: providerURL,
                    fileURL: customSelectedProvidersURL,
                    onCompletion: onCompletion)
    }

    func addProvider(siteID: Int64,
                     providerName: String,
                     providerURL: String? = nil,
                     fileURL: URL,
                     onCompletion: (Error?) -> Void) {
        guard let settings: [PreselectedProvider] = try? fileStorage.data(for: fileURL) else {
            insertNewProvider(siteID: siteID,
                              providerName: providerName,
                              providerURL: providerURL,
                              toFileURL: fileURL,
                              onCompletion: onCompletion)
            return
        }
        upsertTrackingProvider(siteID: siteID,
                               providerName: providerName,
                               preselectedData: settings,
                               toFileURL: fileURL,
                               onCompletion: onCompletion)
    }

    func loadTrackingProvider(siteID: Int64,
                              onCompletion: (ShipmentTrackingProvider?, ShipmentTrackingProviderGroup?, Error?) -> Void) {
        guard let allSavedProviders: [PreselectedProvider] = try? fileStorage.data(for: selectedProvidersURL) else {
            let error = AppSettingsStoreErrors.readPreselectedProvider
            onCompletion(nil, nil, error)
            return
        }

        let providerName = allSavedProviders.filter {
            $0.siteID == siteID
        }.first?.providerName

        guard let name = providerName else {
            let error = AppSettingsStoreErrors.readPreselectedProvider
            onCompletion(nil, nil, error)
            return
        }

        let provider = storageManager
            .viewStorage
            .loadShipmentTrackingProvider(siteID: siteID,
                                          name: name)

        onCompletion(provider?.toReadOnly(), provider?.group?.toReadOnly(), nil)
    }

    func loadCustomTrackingProvider(siteID: Int64,
                                    onCompletion: (ShipmentTrackingProvider?, Error?) -> Void) {
        guard let allSavedProviders: [PreselectedProvider] = try? fileStorage.data(for: customSelectedProvidersURL) else {
            let error = AppSettingsStoreErrors.readPreselectedProvider
            onCompletion(nil, error)
            return
        }

        let providerName = allSavedProviders.filter {
            $0.siteID == siteID
        }.first?.providerName

        let providerURL = allSavedProviders.filter {
            $0.siteID == siteID
        }.first?.providerURL

        guard let name = providerName else {
            let error = AppSettingsStoreErrors.readPreselectedProvider
            onCompletion(nil, error)
            return
        }

        let customProvider = ShipmentTrackingProvider(siteID: siteID,
                                                      name: name,
                                                      url: providerURL ?? "")
        onCompletion(customProvider, nil)
    }

    func upsertTrackingProvider(siteID: Int64,
                                providerName: String,
                                providerURL: String? = nil,
                                preselectedData: [PreselectedProvider],
                                toFileURL: URL,
                                onCompletion: (Error?) -> Void) {
        let newPreselectedProvider = PreselectedProvider(siteID: siteID,
                                                         providerName: providerName,
                                                         providerURL: providerURL)

        var dataToSave = preselectedData

        if preselectedData.contains(newPreselectedProvider),
           let index = preselectedData.firstIndex(of: newPreselectedProvider) {
            dataToSave[index] = newPreselectedProvider
        } else {
            dataToSave.append(newPreselectedProvider)
        }

        do {
            try fileStorage.write(dataToSave, to: toFileURL)
            onCompletion(nil)
        } catch {
            onCompletion(error)
        }
    }

    func insertNewProvider(siteID: Int64,
                           providerName: String,
                           providerURL: String? = nil,
                           toFileURL: URL,
                           onCompletion: (Error?) -> Void) {
        let preselectedProvider = PreselectedProvider(siteID: siteID,
                                                      providerName: providerName,
                                                      providerURL: providerURL)

        do {
            try fileStorage.write([preselectedProvider], to: toFileURL)
            onCompletion(nil)
        } catch {
            onCompletion(error)
        }
    }

    func resetStoredProviders(onCompletion: ((Error?) -> Void)? = nil) {
        do {
            try fileStorage.deleteFile(at: selectedProvidersURL)
            try fileStorage.deleteFile(at: customSelectedProvidersURL)
            onCompletion?(nil)
        } catch {
            let error = AppSettingsStoreErrors.deletePreselectedProvider
            onCompletion?(error)
        }
    }
}

// MARK: - Stats version
//
private extension AppSettingsStore {
    func setStatsVersionLastShownOrFromUserPreference(siteID: Int64,
                                                      statsVersion: StatsVersion) {
        set(statsVersion: statsVersion, for: siteID, to: statsVersionLastShownURL, onCompletion: { error in
            if let error = error {
                DDLogError("⛔️ Saving the last shown stats version failed: siteID \(siteID). Error: \(error)")
            }
        })
    }

    func loadInitialStatsVersionToShow(siteID: Int64, onCompletion: (StatsVersion?) -> Void) {
        guard let existingData: StatsVersionBySite = try? fileStorage.data(for: statsVersionLastShownURL),
              let statsVersion = existingData.statsVersionBySite[siteID] else {
            onCompletion(nil)
            return
        }
        onCompletion(statsVersion)
    }

    func set(statsVersion: StatsVersion, for siteID: Int64, to fileURL: URL, onCompletion: (Error?) -> Void) {
        guard let existingData: StatsVersionBySite = try? fileStorage.data(for: fileURL) else {
            let statsVersionBySite: StatsVersionBySite = StatsVersionBySite(statsVersionBySite: [siteID: statsVersion])
            do {
                try fileStorage.write(statsVersionBySite, to: fileURL)
                onCompletion(nil)
            } catch {
                onCompletion(error)
            }
            return
        }

        var statsVersionBySite = existingData.statsVersionBySite
        statsVersionBySite[siteID] = statsVersion
        do {
            try fileStorage.write(StatsVersionBySite(statsVersionBySite: statsVersionBySite), to: fileURL)
            onCompletion(nil)
        } catch {
            onCompletion(error)
        }
    }

    func loadStatsVersionBannerVisibility(banner: StatsVersionBannerVisibility.StatsVersionBanner,
                                          onCompletion: (Bool) -> Void) {
        guard let existingData: StatsVersionBannerVisibility = try? fileStorage.data(for: statsVersionBannerVisibilityURL),
              let shouldShowBanner = existingData.visibilityByBanner[banner] else {
            onCompletion(true)
            return
        }
        onCompletion(shouldShowBanner)
    }

    func setStatsVersionBannerVisibility(banner: StatsVersionBannerVisibility.StatsVersionBanner,
                                         shouldShowBanner: Bool) {
        let fileURL = statsVersionBannerVisibilityURL
        guard let existingData: StatsVersionBannerVisibility = try? fileStorage.data(for: statsVersionBannerVisibilityURL) else {
            let statsVersionBySite: StatsVersionBannerVisibility = StatsVersionBannerVisibility(visibilityByBanner: [banner: shouldShowBanner])
            try? fileStorage.write(statsVersionBySite, to: fileURL)
            return
        }

        var visibilityByBanner = existingData.visibilityByBanner
        visibilityByBanner[banner] = shouldShowBanner
        try? fileStorage.write(StatsVersionBannerVisibility(visibilityByBanner: visibilityByBanner), to: fileURL)
    }

    func resetStatsVersionStates() {
        do {
            try fileStorage.deleteFile(at: statsVersionBannerVisibilityURL)
            try fileStorage.deleteFile(at: statsVersionLastShownURL)
        } catch {
            let error = AppSettingsStoreErrors.deleteStatsVersionStates
            DDLogError("⛔️ Deleting the stats version files failed. Error: \(error)")
        }
    }

    func loadProductsFeatureSwitch(onCompletion: (Bool) -> Void) {
        guard let existingData: ProductsFeatureSwitchPListWrapper = try? fileStorage.data(for: productsRelease4FeatureSwitchURL) else {
            onCompletion(false)
            return
        }
        onCompletion(existingData.isEnabled)
    }

    func setProductsFeatureSwitch(isEnabled: Bool, onCompletion: () -> Void) {
        let fileURL = productsRelease4FeatureSwitchURL
        let wrapper = ProductsFeatureSwitchPListWrapper(isEnabled: isEnabled)
        do {
            try fileStorage.write(wrapper, to: fileURL)
            onCompletion()
        } catch {
            DDLogError("⛔️ Saving the Products visibility to \(isEnabled) failed: \(error)")
            onCompletion()
        }
    }

    func resetFeatureSwitches() {
        do {
            try fileStorage.deleteFile(at: productsFeatureSwitchURL)
            try fileStorage.deleteFile(at: productsRelease3FeatureSwitchURL)
            try fileStorage.deleteFile(at: productsRelease4FeatureSwitchURL)
        } catch {
            DDLogError("⛔️ Deleting the product feature switch files failed. Error: \(error)")
        }
    }
}

// MARK: - Products Settings
//
private extension AppSettingsStore {
    func loadProductsSettings(siteID: Int64, onCompletion: (Result<StoredProductSettings.Setting, Error>) -> Void) {
        guard let allSavedSettings: StoredProductSettings = try? fileStorage.data(for: productsSettingsURL) else {
            let error = AppSettingsStoreErrors.noProductsSettings
            onCompletion(.failure(error))
            return
        }

        guard let settingsUnwrapped = allSavedSettings.settings[siteID] else {
            let error = AppSettingsStoreErrors.noProductsSettings
            onCompletion(.failure(error))
            return
        }

        onCompletion(.success(settingsUnwrapped))
    }

    func upsertProductsSettings(siteID: Int64,
                                sort: String? = nil,
                                stockStatusFilter: ProductStockStatus? = nil,
                                productStatusFilter: ProductStatus? = nil,
                                productTypeFilter: ProductType? = nil,
                                onCompletion: (Error?) -> Void) {
        var existingSettings: [Int64: StoredProductSettings.Setting] = [:]
        if let storedSettings: StoredProductSettings = try? fileStorage.data(for: productsSettingsURL) {
            existingSettings = storedSettings.settings
        }

        let newSetting = StoredProductSettings.Setting(siteID: siteID,
                                                       sort: sort,
                                                       stockStatusFilter: stockStatusFilter,
                                                       productStatusFilter: productStatusFilter,
                                                       productTypeFilter: productTypeFilter)
        existingSettings[siteID] = newSetting

        let newStoredProductSettings = StoredProductSettings(settings: existingSettings)
        do {
            try fileStorage.write(newStoredProductSettings, to: productsSettingsURL)
            onCompletion(nil)
        } catch {
            onCompletion(AppSettingsStoreErrors.writeProductsSettings)
        }
    }

    func resetProductsSettings() {
        do {
            try fileStorage.deleteFile(at: productsSettingsURL)
        } catch {
            DDLogError("⛔️ Deleting the product settings files failed. Error: \(error)")
        }
    }
}


// MARK: - Errors

/// Errors
///
enum AppSettingsStoreErrors: Error {
    case parsePreselectedProvider
    case writePreselectedProvider
    case readPreselectedProvider
    case deletePreselectedProvider
    case readPListFromFileStorage
    case writePListToFileStorage
    case deleteStatsVersionStates
    case noProductsSettings
    case writeProductsSettings
}


// MARK: - Constants

/// Constants
///
private enum Constants {

    // MARK: File Names
    static let shipmentProvidersFileName = "shipment-providers.plist"
    static let customShipmentProvidersFileName = "custom-shipment-providers.plist"
    static let statsVersionBannerVisibilityFileName = "stats-version-banner-visibility.plist"
    static let statsVersionLastShownFileName = "stats-version-last-shown.plist"
    static let productsFeatureSwitchFileName = "products-feature-switch.plist"
    static let productsRelease3FeatureSwitchFileName = "products-m3-feature-switch.plist"
    static let productsRelease4FeatureSwitchFileName = "products-m4-feature-switch.plist"
    static let generalAppSettingsFileName = "general-app-settings.plist"
    static let productsSettings = "products-settings.plist"
}
