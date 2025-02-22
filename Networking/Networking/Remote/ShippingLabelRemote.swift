import Foundation

/// Protocol for `ShippingLabelRemote` mainly used for mocking.
public protocol ShippingLabelRemoteProtocol {
    func loadShippingLabels(siteID: Int64, orderID: Int64, completion: @escaping (Result<OrderShippingLabelListResponse, Error>) -> Void)
    func printShippingLabel(siteID: Int64,
                            shippingLabelID: Int64,
                            paperSize: ShippingLabelPaperSize,
                            completion: @escaping (Result<ShippingLabelPrintData, Error>) -> Void)
    func refundShippingLabel(siteID: Int64,
                             orderID: Int64,
                             shippingLabelID: Int64,
                             completion: @escaping (Result<ShippingLabelRefund, Error>) -> Void)
    func addressValidation(siteID: Int64,
                           address: ShippingLabelAddressVerification,
                           completion: @escaping (Result<ShippingLabelAddressValidationSuccess, Error>) -> Void)
    func packagesDetails(siteID: Int64,
                         completion: @escaping (Result<ShippingLabelPackagesResponse, Error>) -> Void)
    func createPackage(siteID: Int64,
                       customPackage: ShippingLabelCustomPackage,
                       completion: @escaping (Result<Bool, Error>) -> Void)
    func loadShippingLabelAccountSettings(siteID: Int64,
                                          completion: @escaping (Result<ShippingLabelAccountSettings, Error>) -> Void)
    func checkCreationEligibility(siteID: Int64,
                                  orderID: Int64,
                                  canCreatePaymentMethod: Bool,
                                  canCreateCustomsForm: Bool,
                                  canCreatePackage: Bool,
                                  completion: @escaping (Result<ShippingLabelCreationEligibilityResponse, Error>) -> Void)
}

/// Shipping Labels Remote Endpoints.
public final class ShippingLabelRemote: Remote, ShippingLabelRemoteProtocol {
    /// Loads shipping labels and settings for an order.
    /// - Parameters:
    ///   - siteID: Remote ID of the site that owns the order.
    ///   - orderID: Remote ID of the order that owns the shipping labels.
    ///   - completion: Closure to be executed upon completion.
    public func loadShippingLabels(siteID: Int64, orderID: Int64, completion: @escaping (Result<OrderShippingLabelListResponse, Error>) -> Void) {
        let path = "\(Path.shippingLabels)/\(orderID)"
        let request = JetpackRequest(wooApiVersion: .wcConnectV1, method: .get, siteID: siteID, path: path)
        let mapper = OrderShippingLabelListMapper(siteID: siteID, orderID: orderID)
        enqueue(request, mapper: mapper, completion: completion)
    }

    /// Generates shipping label data for printing.
    /// - Parameters:
    ///   - siteID: Remote ID of the site that owns the shipping label.
    ///   - shippingLabelID: Remote ID of the shipping label.
    ///   - paperSize: Paper size option (current options are "label", "legal", and "letter").
    ///   - completion: Closure to be executed upon completion.
    public func printShippingLabel(siteID: Int64,
                                   shippingLabelID: Int64,
                                   paperSize: ShippingLabelPaperSize,
                                   completion: @escaping (Result<ShippingLabelPrintData, Error>) -> Void) {
        let parameters = [
            ParameterKey.paperSize: paperSize.rawValue,
            ParameterKey.labelIDCSV: String(shippingLabelID),
            ParameterKey.captionCSV: "",
            ParameterKey.json: "true" // `json=true` is necessary, otherwise it results in 500 error "no_response_body".
        ]
        let path = "\(Path.shippingLabels)/print"
        let request = JetpackRequest(wooApiVersion: .wcConnectV1, method: .get, siteID: siteID, path: path, parameters: parameters)
        let mapper = ShippingLabelPrintDataMapper()

        enqueue(request, mapper: mapper, completion: completion)
    }

    /// Requests a refund for a shipping label.
    /// - Parameters:
    ///   - siteID: Remote ID of the site that owns the shipping label.
    ///   - orderID: Remote ID of the order that owns the shipping labels.
    ///   - shippingLabelID: Remote ID of the shipping label.
    ///   - completion: Closure to be executed upon completion.
    public func refundShippingLabel(siteID: Int64, orderID: Int64, shippingLabelID: Int64, completion: @escaping (Result<ShippingLabelRefund, Error>) -> Void) {
        let path = "\(Path.shippingLabels)/\(orderID)/\(shippingLabelID)/refund"
        let request = JetpackRequest(wooApiVersion: .wcConnectV1, method: .post, siteID: siteID, path: path)
        let mapper = ShippingLabelRefundMapper()
        enqueue(request, mapper: mapper, completion: completion)
    }

    /// Address validation for a shipping address.
    /// - Parameters:
    ///   - siteID: Remote ID of the site that owns the shipping label.
    ///   - address: The address that should be verified.
    ///   - completion: Closure to be executed upon completion.
    public func addressValidation(siteID: Int64,
                                  address: ShippingLabelAddressVerification,
                                  completion: @escaping (Result<ShippingLabelAddressValidationSuccess, Error>) -> Void) {
        do {
            let parameters = try address.toDictionary()
            let path = "\(Path.normalizeAddress)"
            let request = JetpackRequest(wooApiVersion: .wcConnectV1, method: .post, siteID: siteID, path: path, parameters: parameters)
            let mapper = ShippingLabelAddressValidationSuccessMapper()
            enqueue(request, mapper: mapper, completion: completion)
        } catch {
            completion(.failure(error))
        }
    }

    /// Requests all the details for the packages (custom and predefined).
    /// - Parameters:
    ///   - siteID: Remote ID of the site that owns the shipping label.
    ///   - completion: Closure to be executed upon completion.
    public func packagesDetails(siteID: Int64,
                                completion: @escaping (Result<ShippingLabelPackagesResponse, Error>) -> Void) {
        let path = Path.packages
        let request = JetpackRequest(wooApiVersion: .wcConnectV1, method: .get, siteID: siteID, path: path, parameters: nil)
        let mapper = ShippingLabelPackagesMapper()
        enqueue(request, mapper: mapper, completion: completion)
    }

    /// Creates a new custom package.
    /// - Parameters:
    ///   - siteID: Remote ID of the site that owns the shipping label.
    ///   - customPackage: The custom package that should be created.
    ///   - completion: Closure to be executed upon completion.
    public func createPackage(siteID: Int64,
                              customPackage: ShippingLabelCustomPackage,
                              completion: @escaping (Result<Bool, Error>) -> Void) {
        do {
            let customPackageDictionary = try customPackage.toDictionary()
            let parameters = [
                ParameterKey.custom: [customPackageDictionary]
            ]
            let path = Path.packages
            let request = JetpackRequest(wooApiVersion: .wcConnectV1, method: .post, siteID: siteID, path: path, parameters: parameters)
            let mapper = SuccessDataResultMapper()
            enqueue(request, mapper: mapper, completion: completion)
        } catch {
            completion(.failure(error))
        }
    }

    /// Loads account-level shipping label settings for a store.
    /// - Parameters:
    ///   - siteID: Remote ID of the site.
    ///   - completion: Closure to be executed upon completion.
    public func loadShippingLabelAccountSettings(siteID: Int64, completion: @escaping (Result<ShippingLabelAccountSettings, Error>) -> Void) {
        let path = Path.accountSettings
        let request = JetpackRequest(wooApiVersion: .wcConnectV1, method: .get, siteID: siteID, path: path)
        let mapper = ShippingLabelAccountSettingsMapper(siteID: siteID)
        enqueue(request, mapper: mapper, completion: completion)
    }

    /// Checks eligibility for shipping label creation.
    /// - Parameters:
    ///     - siteID: Remote ID of the site.
    ///     - orderID: Remote ID of the order that owns the shipping labels.
    ///     - canCreatePaymentMethod: Whether the client supports creating new payment methods.
    ///     - canCreateCustomsForm: Whether the client supports creating customs forms.
    ///     - canCreatePackage: Whether the client supports creating packages.
    ///     - completion: Closure to be executed upon completion.
    public func checkCreationEligibility(siteID: Int64,
                                         orderID: Int64,
                                         canCreatePaymentMethod: Bool,
                                         canCreateCustomsForm: Bool,
                                         canCreatePackage: Bool,
                                         completion: @escaping (Result<ShippingLabelCreationEligibilityResponse, Error>) -> Void) {
        let parameters = [
            ParameterKey.canCreatePaymentMethod: canCreatePaymentMethod,
            ParameterKey.canCreateCustomsForm: canCreateCustomsForm,
            ParameterKey.canCreatePackage: canCreatePackage
        ]
        let path = "\(Path.shippingLabels)/\(orderID)/creation_eligibility"
        let request = JetpackRequest(wooApiVersion: .wcConnectV1, method: .get, siteID: siteID, path: path, parameters: parameters)
        let mapper = ShippingLabelCreationEligibilityMapper()
        enqueue(request, mapper: mapper, completion: completion)
    }
}

// MARK: Constant
private extension ShippingLabelRemote {
    enum Path {
        static let shippingLabels = "label"
        static let normalizeAddress = "normalize-address"
        static let packages = "packages"
        static let accountSettings = "account/settings"
    }

    enum ParameterKey {
        static let paperSize = "paper_size"
        static let labelIDCSV = "label_id_csv"
        static let captionCSV = "caption_csv"
        static let json = "json"
        static let custom = "custom"
        static let canCreatePaymentMethod = "can_create_payment_method"
        static let canCreateCustomsForm = "can_create_customs_form"
        static let canCreatePackage = "can_create_package"
    }
}
