import Yosemite
import Observables

/// Provides data for product form UI, and handles product editing actions.
final class ProductFormViewModel: ProductFormViewModelProtocol {
    typealias ProductModel = EditableProductModel

    /// Emits product on change, except when the product name is the only change (`productName` is emitted for this case).
    var observableProduct: Observable<EditableProductModel> {
        productSubject
    }

    /// Emits product name on change.
    var productName: Observable<String>? {
        productNameSubject
    }

    /// Emits a boolean of whether the product has unsaved changes for remote update.
    var isUpdateEnabled: Observable<Bool> {
        isUpdateEnabledSubject
    }

    /// The latest product value.
    var productModel: EditableProductModel {
        product
    }

    /// The original product value.
    var originalProductModel: EditableProductModel {
        originalProduct
    }

    /// The form type could change from .add to .edit after creation.
    private(set) var formType: ProductFormType

    /// Creates actions available on the bottom sheet.
    private(set) var actionsFactory: ProductFormActionsFactoryProtocol

    private let productSubject: PublishSubject<EditableProductModel> = PublishSubject<EditableProductModel>()
    private let productNameSubject: PublishSubject<String> = PublishSubject<String>()
    private let isUpdateEnabledSubject: PublishSubject<Bool>

    /// The product model before any potential edits; reset after a remote update.
    private var originalProduct: EditableProductModel {
        didSet {
            product = originalProduct
        }
    }

    /// The product model with potential edits; reset after a remote update.
    private var product: EditableProductModel {
        didSet {
            guard product != oldValue else {
                return
            }

            defer {
                isUpdateEnabledSubject.send(hasUnsavedChanges())
            }

            if isNameTheOnlyChange(oldProduct: oldValue, newProduct: product) {
                productNameSubject.send(product.name)
                return
            }

            updateFormTypeIfNeeded(oldProduct: oldValue.product)
            actionsFactory = ProductFormActionsFactory(product: product,
                                                       formType: formType)
            productSubject.send(product)
        }
    }

    /// The product password, fetched in Product Settings
    private var originalPassword: String? {
        didSet {
            password = originalPassword
        }
    }

    private(set) var password: String? {
        didSet {
            if password != oldValue {
                isUpdateEnabledSubject.send(hasUnsavedChanges())
            }
        }
    }

    /// The action buttons that should be rendered in the navigation bar.
    var actionButtons: [ActionButtonType] {
        // Figure out main action button first
        var buttons: [ActionButtonType] = {
            switch (formType, originalProductModel.status, productModel.status, originalProduct.product.existsRemotely, hasUnsavedChanges()) {
            case (.add, .publish, .publish, false, _): // New product with publish status
                return [.publish]

            case (.add, .publish, _, false, _): // New product with a different status
                return [.save] // And publish in more

            case (.edit, .publish, _, true, true): // Existing published product with changes
                return [.save]

            case (.edit, .publish, _, true, false): // Existing published product with no changes
                return []

            case (.edit, _, _, true, true): // Any other existing product with changes
                return [.save] // And publish in more

            case (.edit, _, _, true, false): // Any other existing product with no changes
                return [.publish]

            case (.readonly, _, _, _, _): // Any product on readonly mode
                 return []

            default: // Impossible cases
                return []
            }
        }()

        // Add more button if needed
        if shouldShowMoreOptionsMenu() {
            buttons.append(.more)
        }

        return buttons
    }

    private let productImageActionHandler: ProductImageActionHandler

    private var cancellable: ObservationToken?

    private let stores: StoresManager

    init(product: EditableProductModel,
         formType: ProductFormType,
         productImageActionHandler: ProductImageActionHandler,
         stores: StoresManager = ServiceLocator.stores) {
        self.formType = formType
        self.productImageActionHandler = productImageActionHandler
        self.originalProduct = product
        self.product = product
        self.actionsFactory = ProductFormActionsFactory(product: product,
                                                        formType: formType)
        self.isUpdateEnabledSubject = PublishSubject<Bool>()
        self.stores = stores

        self.cancellable = productImageActionHandler.addUpdateObserver(self) { [weak self] allStatuses in
            if allStatuses.productImageStatuses.hasPendingUpload {
                self?.isUpdateEnabledSubject.send(true)
            }
        }
    }

    deinit {
        cancellable?.cancel()
    }

    func hasUnsavedChanges() -> Bool {
        return product != originalProduct || productImageActionHandler.productImageStatuses.hasPendingUpload || password != originalPassword
    }
}

// MARK: - More menu
//
extension ProductFormViewModel {

    /// Show publish button if the product can be published and the publish button is not already part of the action buttons.
    ///
    func canShowPublishOption() -> Bool {
        let newProduct = formType == .add && !originalProduct.product.existsRemotely
        let existingUnpublishedProduct = formType == .edit && originalProduct.product.existsRemotely && originalProduct.status != .publish

        let productCanBePublished = newProduct || existingUnpublishedProduct
        let publishIsNotAlreadyVisible = !actionButtons.contains(.publish)

        return productCanBePublished && publishIsNotAlreadyVisible
    }

    func canSaveAsDraft() -> Bool {
        formType == .add && productModel.status != .draft
    }

    func canEditProductSettings() -> Bool {
        formType != .readonly
    }

    func canViewProductInStore() -> Bool {
        originalProduct.product.productStatus == .publish && formType != .add
    }

    func canShareProduct() -> Bool {
        formType != .add
    }

    func canDeleteProduct() -> Bool {
        formType == .edit
    }
}

// MARK: Action handling
//
extension ProductFormViewModel {
    func updateName(_ name: String) {
        product = EditableProductModel(product: product.product.copy(name: name))
    }

    func updateImages(_ images: [ProductImage]) {
        product = EditableProductModel(product: product.product.copy(images: images))
    }

    func updateDescription(_ newDescription: String) {
        product = EditableProductModel(product: product.product.copy(fullDescription: newDescription))
    }

    func updatePriceSettings(regularPrice: String?,
                             salePrice: String?,
                             dateOnSaleStart: Date?,
                             dateOnSaleEnd: Date?,
                             taxStatus: ProductTaxStatus,
                             taxClass: TaxClass?) {
        product = EditableProductModel(product: product.product.copy(dateOnSaleStart: dateOnSaleStart,
                                                                     dateOnSaleEnd: dateOnSaleEnd,
                                                                     regularPrice: regularPrice,
                                                                     salePrice: salePrice,
                                                                     taxStatusKey: taxStatus.rawValue,
                                                                     taxClass: taxClass?.slug))
    }

    func updateProductType(productType: ProductType) {
        /// The property `manageStock` is set to `false` if the new `productType` is `affiliate`
        /// because it seems there is a small bug in APIs that doesn't allow us to change type from a product with
        /// manage stock enabled to external product type. More info: PR-2665
        ///
        var manageStock = product.product.manageStock
        if productType == .affiliate {
            manageStock = false
        }
        product = EditableProductModel(product: product.product.copy(productTypeKey: productType.rawValue, manageStock: manageStock))
    }

    func updateInventorySettings(sku: String?,
                                 manageStock: Bool,
                                 soldIndividually: Bool?,
                                 stockQuantity: Decimal?,
                                 backordersSetting: ProductBackordersSetting?,
                                 stockStatus: ProductStockStatus?) {
        product = EditableProductModel(product: product.product.copy(sku: sku,
                                                                     manageStock: manageStock,
                                                                     stockQuantity: stockQuantity,
                                                                     stockStatusKey: stockStatus?.rawValue,
                                                                     backordersKey: backordersSetting?.rawValue,
                                                                     soldIndividually: soldIndividually))
    }

    func updateShippingSettings(weight: String?, dimensions: ProductDimensions, shippingClass: String?, shippingClassID: Int64?) {
        product = EditableProductModel(product: product.product.copy(weight: weight,
                                                                     dimensions: dimensions,
                                                                     shippingClass: shippingClass ?? "",
                                                                     shippingClassID: shippingClassID ?? 0))
    }

    func updateProductCategories(_ categories: [ProductCategory]) {
        product = EditableProductModel(product: product.product.copy(categories: categories))
    }

    func updateProductTags(_ tags: [ProductTag]) {
        product = EditableProductModel(product: product.product.copy(tags: tags))
    }

    func updateShortDescription(_ shortDescription: String) {
        product = EditableProductModel(product: product.product.copy(shortDescription: shortDescription))
    }

    func updateSKU(_ sku: String?) {
        product = EditableProductModel(product: product.product.copy(sku: sku))
    }

    func updateGroupedProductIDs(_ groupedProductIDs: [Int64]) {
        product = EditableProductModel(product: product.product.copy(groupedProducts: groupedProductIDs))
    }

    func updateProductSettings(_ settings: ProductSettings) {
        product = EditableProductModel(product: product.product.copy(slug: settings.slug,
                                                                     statusKey: settings.status.rawValue,
                                                                     featured: settings.featured,
                                                                     catalogVisibilityKey: settings.catalogVisibility.rawValue,
                                                                     virtual: settings.virtual,
                                                                     downloadable: settings.downloadable,
                                                                     reviewsAllowed: settings.reviewsAllowed,
                                                                     purchaseNote: settings.purchaseNote,
                                                                     menuOrder: settings.menuOrder))
        password = settings.password
    }

    func updateExternalLink(externalURL: String?, buttonText: String) {
        product = EditableProductModel(product: product.product.copy(buttonText: buttonText, externalURL: externalURL))
    }

    func updateStatus(_ isEnabled: Bool) {
        // no-op: visibility is editable in product settings for `Product`
    }

    func updateDownloadableFiles(downloadableFiles: [ProductDownload], downloadLimit: Int64, downloadExpiry: Int64) {
        product = EditableProductModel(product: product.product.copy(downloads: downloadableFiles,
                                                                     downloadLimit: downloadLimit,
                                                                     downloadExpiry: downloadExpiry))
    }

    func updateLinkedProducts(upsellIDs: [Int64], crossSellIDs: [Int64]) {
        product = EditableProductModel(product: product.product.copy(upsellIDs: upsellIDs,
                                                                     crossSellIDs: crossSellIDs))
    }

    func updateVariationAttributes(_ attributes: [ProductVariationAttribute]) {
        // no-op
    }

    /// Updates the original product variations(and attributes).
    /// This is needed because variations and attributes, remote updates, happen outside this view model and wee need a way to sync our original product.
    ///
    func updateProductVariations(from newProduct: Product) {
        // ProductID and statusKey could have changed, in case we had to create the product as a draft to create attributes or variations
        let newOriginalProduct = EditableProductModel(product: originalProduct.product.copy(productID: newProduct.productID,
                                                                                            statusKey: newProduct.statusKey,
                                                                                            attributes: newProduct.attributes,
                                                                                            variations: newProduct.variations))

        // Make sure the product is updated locally. Useful for screens that are observing the product or a list of products.
        updateStoredProduct(with: newOriginalProduct.product)

        // If the product doesn't have any pending changes, we can safely override the original product
        guard hasUnsavedChanges() else {
            return resetProduct(newOriginalProduct)
        }

        // If the product has pending changes, we need to override the `originalProduct` first and the `living product` later with a saved copy.
        // This is because, overriding `originalProduct` also overrides the `living product`.
        let productWithChanges = EditableProductModel(product: product.product.copy(productID: newProduct.productID,
                                                                                    statusKey: newProduct.statusKey,
                                                                                    attributes: newProduct.attributes,
                                                                                    variations: newProduct.variations))
        resetProduct(newOriginalProduct)
        product = productWithChanges
    }

    /// Fires a `Yosemite` action to update the product in our storage layer
    ///
    func updateStoredProduct(with newProduct: Product) {
        let action = ProductAction.replaceProductLocally(product: newProduct, onCompletion: {})
        stores.dispatch(action)
    }
}

// MARK: Remote actions
//
extension ProductFormViewModel {
    func saveProductRemotely(status: ProductStatus?, onCompletion: @escaping (Result<EditableProductModel, ProductUpdateError>) -> Void) {
        let productModelToSave: EditableProductModel = {
            guard let status = status, status != product.status else {
                return product
            }
            let productWithStatusUpdated = product.product.copy(statusKey: status.rawValue)
            return EditableProductModel(product: productWithStatusUpdated)
        }()
        let remoteActionUseCase = ProductFormRemoteActionUseCase()
        switch formType {
        case .add:
            remoteActionUseCase.addProduct(product: productModelToSave, password: password) { [weak self] result in
                switch result {
                case .failure(let error):
                    onCompletion(.failure(error))
                case .success(let data):
                    guard let self = self else {
                        return
                    }
                    self.resetProduct(data.product)
                    self.resetPassword(data.password)
                    onCompletion(.success(data.product))
                }
            }
        case .edit:
            remoteActionUseCase.editProduct(product: productModelToSave,
                                              originalProduct: originalProduct,
                                              password: password,
                                              originalPassword: originalPassword) { [weak self] result in
                                                guard let self = self else {
                                                    return
                                                }
                                                switch result {
                                                case .success(let data):
                                                    self.resetProduct(data.product)
                                                    self.resetPassword(data.password)
                                                    onCompletion(.success(data.product))
                                                case .failure(let error):
                                                    onCompletion(.failure(error))
                                                }
            }
        case .readonly:
            assertionFailure("Trying to save a product remotely in readonly mode")
        }
    }

    func deleteProductRemotely(onCompletion: @escaping (Result<Void, ProductUpdateError>) -> Void) {
        let remoteActionUseCase = ProductFormRemoteActionUseCase()
        remoteActionUseCase.deleteProduct(product: product) { result in
            switch result {
            case .success:
                onCompletion(.success(()))
            case .failure(let error):
                onCompletion(.failure(error))
            }
        }
    }

    /// Updates the internal `formType` when a product changes from new to a saved status.
    /// Currently needed when a new product was just created as a draft to allow creating attributes and variations.
    ///
    func updateFormTypeIfNeeded(oldProduct: Product) {
        guard !oldProduct.existsRemotely, product.product.existsRemotely else {
            return
        }

        formType = .edit
    }
}

// MARK: Reset actions
//
extension ProductFormViewModel {
    private func resetProduct(_ product: EditableProductModel) {
        originalProduct = product
    }

    func resetPassword(_ password: String?) {
        originalPassword = password
        isUpdateEnabledSubject.send(hasUnsavedChanges())
    }
}

private extension ProductFormViewModel {
    func isNameTheOnlyChange(oldProduct: EditableProductModel, newProduct: EditableProductModel) -> Bool {
        let oldProductWithNewName = EditableProductModel(product: oldProduct.product.copy(name: newProduct.name))
        return oldProductWithNewName == newProduct && newProduct.name != oldProduct.name
    }
}
