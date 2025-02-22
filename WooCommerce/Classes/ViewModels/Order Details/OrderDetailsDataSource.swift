import Foundation
import UIKit
import Yosemite
import protocol Storage.StorageManagerType


/// The main file for Order Details data.
///
final class OrderDetailsDataSource: NSObject {

    /// This is only used to pass as a dependency to `OrderDetailsResultsControllers`.
    private let storageManager: StorageManagerType

    private(set) var order: Order
    private let couponLines: [OrderCouponLine]?

    /// Haptic Feedback!
    ///
    private let hapticGenerator = UINotificationFeedbackGenerator()

    /// Sections to be rendered
    ///
    private(set) var sections = [Section]()

    /// Is this order processing?
    ///
    private var isProcessingPayment: Bool {
        return order.status == OrderStatusEnum.processing
    }

    /// Is this order fully refunded?
    ///
    private var isRefundedStatus: Bool {
        return order.status == OrderStatusEnum.refunded
    }

    /// Is the shipment tracking plugin available?
    ///
    var trackingIsReachable: Bool = false

    /// Whether the order is eligible for shipping label creation.
    ///
    var isEligibleForShippingLabelCreation: Bool = false

    /// Closure to be executed when the cell was tapped.
    ///
    var onCellAction: ((CellActionType, IndexPath?) -> Void)?

    /// Closure to be executed when the shipping label more menu is tapped.
    ///
    var onShippingLabelMoreMenuTapped: ((_ shippingLabel: ShippingLabel, _ sourceView: UIView) -> Void)?

    /// Closure to be executed when the UI needs to be reloaded.
    ///
    var onUIReloadRequired: (() -> Void)?

    /// Indicates if the product cell will be configured with add on information or not.
    /// Property provided while "view add-ons" feature is in development.
    ///
    var showAddOns = false

    /// Order shipment tracking list
    ///
    var orderTracking: [ShipmentTracking] {
        return resultsControllers.orderTracking
    }

    /// Order statuses list
    ///
    var currentSiteStatuses: [OrderStatus] {
        return resultsControllers.currentSiteStatuses
    }

    /// Products from an Order
    ///
    var products: [Product] {
        return resultsControllers.products
    }

    /// OrderItemsRefund Count
    ///
    var refundedProductsCount: Decimal {
        return AggregateDataHelper.refundedProductsCount(from: refunds)
    }

    /// Refunds on an Order
    ///
    var refunds: [Refund] {
        return resultsControllers.refunds
    }

    var addOnGroups: [AddOnGroup] {
        resultsControllers.addOnGroups
    }

    /// Shipping Labels for an Order
    ///
    private(set) var shippingLabels: [ShippingLabel] = []

    private var shippingLabelOrderItemsAggregator: AggregatedShippingLabelOrderItems = AggregatedShippingLabelOrderItems.empty

    /// Shipping Lines from an Order
    ///
    private var shippingLines: [ShippingLine] {
        return order.shippingLines
    }

    /// First Shipping method from an order
    ///
    private var shippingMethod: String {
        return shippingLines.first?.methodTitle ?? String()
    }

    /// Yosemite.OrderItem
    /// The original list of order items a user purchased
    ///
    var items: [OrderItem] {
        return order.items
    }

    /// Combine refunded order items to show refunded products
    ///
    var refundedProducts: [AggregateOrderItem]? {
        return AggregateDataHelper.combineRefundedProducts(from: refunds)
    }

    /// Calculate the new order item quantities and totals after refunded products have altered the fields
    ///
    var aggregateOrderItems: [AggregateOrderItem] {
        let orderItemsAfterCombiningWithRefunds = AggregateDataHelper.combineOrderItems(items, with: refunds)
        let orderItemsAfterCombiningWithRefundsAndShippingLabels = AggregateDataHelper
            .combineAggregatedOrderItems(orderItemsAfterCombiningWithRefunds,
                                         with: shippingLabelOrderItemsAggregator.orderItemsOfNonRefundedShippingLabels(shippingLabels))
        return orderItemsAfterCombiningWithRefundsAndShippingLabels
    }

    /// All the condensed refunds in an order
    ///
    var condensedRefunds: [OrderRefundCondensed] {
        return order.refunds.sorted(by: { $0.refundID > $1.refundID })
    }

    /// Notes of an Order
    ///
    var orderNotes: [OrderNote] = [] {
        didSet {
            orderNotesSections = computeOrderNotesSections()
        }
    }

    /// Note from the customer about the order
    ///
    private var customerNote: String {
        return order.customerNote ?? String()
    }

    /// Computed Notes of an Order with note sections
    ///
    private var orderNotesSections: [NoteSection] = []

    private lazy var resultsControllers: OrderDetailsResultsControllers = {
        return OrderDetailsResultsControllers(order: self.order, storageManager: self.storageManager)
    }()

    private lazy var orderNoteAsyncDictionary: AsyncDictionary<Int64, String> = {
        return AsyncDictionary()
    }()

    private lazy var currencyFormatter = CurrencyFormatter(currencySettings: ServiceLocator.currencySettings)

    private let imageService: ImageService = ServiceLocator.imageService

    init(order: Order,
         storageManager: StorageManagerType = ServiceLocator.storageManager) {
        self.storageManager = storageManager
        self.order = order
        self.couponLines = order.coupons

        super.init()
    }

    func update(order: Order) {
        self.order = order
    }

    func configureResultsControllers(onReload: @escaping () -> Void) {
        resultsControllers.configureResultsControllers(onReload: onReload)
    }

    func shippingLabel(at indexPath: IndexPath) -> ShippingLabel? {
        guard let firstShippingLabelSectionIndex = sections.firstIndex(where: { $0.category == .shippingLabel }) else {
            return nil
        }
        let shippingLabelIndex = indexPath.section - firstShippingLabelSectionIndex
        return shippingLabels[shippingLabelIndex]
    }

    func shippingLabelOrderItem(at indexPath: IndexPath) -> AggregateOrderItem? {
        guard let shippingLabel = shippingLabel(at: indexPath) else {
            return nil
        }
        return shippingLabelOrderItemsAggregator.orderItem(of: shippingLabel, at: indexPath.row)
    }
}


// MARK: - Conformance to UITableViewDataSource
extension OrderDetailsDataSource: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = sections[indexPath.section].rows[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: row.reuseIdentifier, for: indexPath)
        configure(cell, for: row, at: indexPath)
        return cell
    }
}


// MARK: - Support for UITableViewDelegate
extension OrderDetailsDataSource {
    func viewForHeaderInSection(_ section: Int, tableView: UITableView) -> UIView? {
        guard let section = sections[safe: section] else {
            return nil
        }

        let reuseIdentifier = section.headerStyle.viewType.reuseIdentifier
        guard let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: reuseIdentifier) else {
            assertionFailure("Could not find section header view for reuseIdentifier \(reuseIdentifier)")
            return nil
        }

        switch headerView {
        case let headerView as PrimarySectionHeaderView:
            switch section.headerStyle {
            case .actionablePrimary(let actionConfig):
                headerView.configure(title: section.title, action: actionConfig)
            default:
                headerView.configure(title: section.title)
            }
        case let headerView as TwoColumnSectionHeaderView:
            headerView.leftText = section.title
            headerView.rightText = section.rightTitle
        default:
            assertionFailure("Unexpected headerView type \(headerView.self)")
            return nil
        }

        return headerView
    }
}

// MARK: - Support for UITableViewDataSource

private extension OrderDetailsDataSource {
    func configure(_ cell: UITableViewCell, for row: Row, at indexPath: IndexPath) {
        switch cell {
        case let cell as WooBasicTableViewCell where row == .details:
            configureDetails(cell: cell)
        case let cell as CustomerInfoTableViewCell where row == .shippingAddress:
            configureShippingAddress(cell: cell)
        case let cell as CustomerNoteTableViewCell where row == .customerNote:
            configureCustomerNote(cell: cell)
        case let cell as CustomerNoteTableViewCell where row == .shippingMethod:
            configureShippingMethod(cell: cell)
        case let cell as WooBasicTableViewCell where row == .billingDetail:
            configureBillingDetail(cell: cell)
        case let cell as WooBasicTableViewCell where row == .shippingLabelDetail:
            configureShippingLabelDetail(cell: cell)
        case let cell as ImageAndTitleAndTextTableViewCell where row == .shippingNotice:
            configureShippingNotice(cell: cell)
        case let cell as ImageAndTitleAndTextTableViewCell where row == .shippingLabelCreationInfo(showsSeparator: true),
             let cell as ImageAndTitleAndTextTableViewCell where row == .shippingLabelCreationInfo(showsSeparator: false):
            if case .shippingLabelCreationInfo(let showsSeparator) = row {
                configureShippingLabelCreationInfo(cell: cell, showsSeparator: showsSeparator)
            }
        case let cell as ImageAndTitleAndTextTableViewCell where row == .shippingLabelPrintingInfo:
            configureShippingLabelPrintingInfo(cell: cell)
        case let cell as LeftImageTableViewCell where row == .addOrderNote:
            configureNewNote(cell: cell)
        case let cell as OrderNoteHeaderTableViewCell:
            configureOrderNoteHeader(cell: cell, at: indexPath)
        case let cell as OrderNoteTableViewCell:
            configureOrderNote(cell: cell, at: indexPath)
        case let cell as LedgerTableViewCell:
            configurePayment(cell: cell)
        case let cell as TwoColumnHeadlineFootnoteTableViewCell where row == .customerPaid:
            configureCustomerPaid(cell: cell)
        case let cell as TwoColumnHeadlineFootnoteTableViewCell where row == .refund:
            configureRefund(cell: cell, at: indexPath)
        case let cell as TwoColumnHeadlineFootnoteTableViewCell where row == .netAmount:
            configureNetAmount(cell: cell)
        case let cell as ProductDetailsTableViewCell where row == .shippingLabelProduct:
            configureShippingLabelProduct(cell: cell, at: indexPath)
        case let cell as ProductDetailsTableViewCell where row == .aggregateOrderItem:
            configureAggregateOrderItem(cell: cell, at: indexPath)
        case let cell as ButtonTableViewCell where row == .shippingLabelCreateButton:
            configureCreateShippingLabelButton(cell: cell, at: indexPath)
        case let cell as ButtonTableViewCell where row == .markCompleteButton(style: .primary, showsBottomSpacing: true),
             let cell as ButtonTableViewCell where row == .markCompleteButton(style: .primary, showsBottomSpacing: false),
             let cell as ButtonTableViewCell where row == .markCompleteButton(style: .secondary, showsBottomSpacing: true),
             let cell as ButtonTableViewCell where row == .markCompleteButton(style: .secondary, showsBottomSpacing: false):
            if case .markCompleteButton(let style, let showsBottomSpacing) = row {
                configureMarkCompleteButton(cell: cell, buttonStyle: style, showsBottomSpacing: showsBottomSpacing)
            }
        case let cell as ButtonTableViewCell where row == .shippingLabelReprintButton:
            configureReprintShippingLabelButton(cell: cell, at: indexPath)
        case let cell as OrderTrackingTableViewCell where row == .tracking:
            configureTracking(cell: cell, at: indexPath)
        case let cell as ImageAndTitleAndTextTableViewCell where row == .shippingLabelTrackingNumber:
            configureShippingLabelTrackingNumber(cell: cell, at: indexPath)
        case let cell as ImageAndTitleAndTextTableViewCell where row == .shippingLabelRefunded:
            configureShippingLabelRefunded(cell: cell, at: indexPath)
        case let cell as LeftImageTableViewCell where row == .trackingAdd:
            configureNewTracking(cell: cell)
        case let cell as SummaryTableViewCell:
            configureSummary(cell: cell)
        case let cell as WooBasicTableViewCell where row == .refundedProducts:
            configureRefundedProducts(cell)
        case let cell as IssueRefundTableViewCell:
            configureIssueRefundButton(cell: cell)
        default:
            fatalError("Unidentified customer info row type")
        }
    }

    private func configureCustomerNote(cell: CustomerNoteTableViewCell) {
        cell.headline = Title.customerNote
        let localizedBody = String.localizedStringWithFormat(
            NSLocalizedString("“%@”",
                              comment: "Customer note, wrapped in quotes"),
            customerNote)
        cell.body = localizedBody
        cell.selectionStyle = .none
    }

    private func configureBillingDetail(cell: WooBasicTableViewCell) {
        cell.bodyLabel?.text = Footer.showBilling
        cell.applyPlainTextStyle()
        cell.accessoryType = .disclosureIndicator
        cell.selectionStyle = .default

        cell.accessibilityTraits = .button
        cell.accessibilityLabel = NSLocalizedString(
            "View Billing Information",
            comment: "Accessibility label for the 'View Billing Information' button"
        )

        cell.accessibilityHint = NSLocalizedString(
            "Show the billing details for this order.",
            comment: "VoiceOver accessibility hint, informing the user that the button can be used to view billing information."
        )
    }

    private func configureShippingNotice(cell: ImageAndTitleAndTextTableViewCell) {
        let cellTextContent = NSLocalizedString(
            "This order is using extensions to calculate shipping. The shipping methods shown might be incomplete.",
            comment: "Shipping notice row label when there is more than one shipping method")

        cell.update(with: .imageAndTitleOnly(fontStyle: .body),
                    data: .init(title: cellTextContent,
                                textTintColor: .text,
                                image: Icons.shippingNoticeIcon,
                                imageTintColor: .listIcon,
                                numberOfLinesForTitle: 0,
                                isActionable: false))

        cell.selectionStyle = .none

        cell.accessibilityTraits = .staticText
        cell.accessibilityLabel = NSLocalizedString(
            "This order is using extensions to calculate shipping. The shipping methods shown might be incomplete.",
            comment: "Accessibility label for the Shipping notice")
        cell.accessibilityHint = NSLocalizedString("Shipping notice about the order",
                                                    comment: "VoiceOver accessibility label for the shipping notice about the order")
    }

    private func configureNewNote(cell: LeftImageTableViewCell) {
        cell.leftImage = Icons.addNoteIcon
        cell.imageView?.tintColor = .accent
        cell.labelText = Titles.addNoteText

        cell.accessibilityTraits = .button
        cell.accessibilityLabel = NSLocalizedString(
            "Add a note",
            comment: "Accessibility label for the 'Add a note' button"
        )

        cell.accessibilityHint = NSLocalizedString(
            "Composes a new order note.",
            comment: "VoiceOver accessibility hint, informing the user that the button can be used to create a new order note."
        )
    }

    private func configureOrderNoteHeader(cell: OrderNoteHeaderTableViewCell, at indexPath: IndexPath) {
        guard let noteHeader = noteHeader(at: indexPath) else {
            return
        }

        cell.dateCreated = noteHeader.toString(dateStyle: .medium, timeStyle: .none)
    }

    private func configureOrderNote(cell: OrderNoteTableViewCell, at indexPath: IndexPath) {
        guard let note = note(at: indexPath) else {
            return
        }

        cell.isSystemAuthor = note.isSystemAuthor
        cell.isCustomerNote = note.isCustomerNote
        cell.author = note.author
        cell.dateCreated = note.dateCreated.toString(dateStyle: .none, timeStyle: .short)
        cell.contents = orderNoteAsyncDictionary.value(forKey: note.noteID)
    }

    private func configurePayment(cell: LedgerTableViewCell) {
        let paymentViewModel = OrderPaymentDetailsViewModel(order: order)
        cell.configure(with: paymentViewModel)
    }

    private func configureCustomerPaid(cell: TwoColumnHeadlineFootnoteTableViewCell) {
        let paymentViewModel = OrderPaymentDetailsViewModel(order: order)
        cell.leftText = Titles.paidByCustomer
        cell.rightText = paymentViewModel.paymentTotal
        cell.updateFootnoteText(paymentViewModel.paymentSummary)
    }

    private func configureDetails(cell: WooBasicTableViewCell) {
        cell.bodyLabel?.text = Titles.productDetails
        cell.applyPlainTextStyle()
        cell.accessoryImage = nil
        cell.accessoryType = .disclosureIndicator
        cell.selectionStyle = .default
    }

    private func configureRefund(cell: TwoColumnHeadlineFootnoteTableViewCell, at indexPath: IndexPath) {
        let index = indexPath.row - Constants.paymentCell - Constants.paidByCustomerCell
        let condensedRefund = condensedRefunds[index]
        let refund = lookUpRefund(by: condensedRefund.refundID)
        let paymentViewModel = OrderPaymentDetailsViewModel(order: order, refund: refund)

        cell.leftText = Titles.refunded
        cell.setLeftTitleToLinkStyle(true)
        cell.rightText = paymentViewModel.refundAmount
        cell.setRightTitleToLinkStyle(true)
        cell.updateFootnoteText(paymentViewModel.refundSummary)

        cell.accessibilityTraits = .button
        cell.accessibilityLabel = NSLocalizedString(
            "View refund details",
            comment: "Accessibility label for the 'View details' refund button"
        )
        cell.accessibilityHint = NSLocalizedString(
            "Show refund details for this order.",
            comment: "VoiceOver accessibility hint, informing the user that the button can be used to view refund detail information."
        )
    }

    private func configureNetAmount(cell: TwoColumnHeadlineFootnoteTableViewCell) {
        let paymentViewModel = OrderPaymentDetailsViewModel(order: order)

        cell.leftText = Titles.netAmount
        cell.rightText = paymentViewModel.netAmount
        cell.hideFootnote()
    }

    private func configureCreateShippingLabelButton(cell: ButtonTableViewCell, at indexPath: IndexPath) {
        cell.configure(style: .primary,
                       title: Titles.createShippingLabel,
                       bottomSpacing: 0) {
            self.onCellAction?(.createShippingLabel, nil)
        }
        cell.hideSeparator()
    }

    private func configureShippingLabelCreationInfo(cell: ImageAndTitleAndTextTableViewCell, showsSeparator: Bool) {
        cell.update(with: .imageAndTitleOnly(fontStyle: .footnote),
                    data: .init(title: Title.shippingLabelCreationInfoAction,
                                image: .infoOutlineFootnoteImage,
                                imageTintColor: .systemColor(.secondaryLabel),
                                numberOfLinesForTitle: 0,
                                isActionable: false,
                                showsSeparator: showsSeparator))

        cell.selectionStyle = .default

        cell.accessibilityTraits = .button
        cell.accessibilityLabel = Title.shippingLabelCreationInfoAction
        cell.accessibilityHint =
            NSLocalizedString("Tap to show information about creating a shipping label",
                              comment: "VoiceOver accessibility hint for the row that shows information about creating a shipping label")
    }

    private func configureShippingLabelDetail(cell: WooBasicTableViewCell) {
        cell.bodyLabel?.text = Footer.showShippingLabelDetails
        cell.applyPlainTextStyle()
        cell.accessoryType = .disclosureIndicator
        cell.selectionStyle = .default

        cell.accessibilityTraits = .button
        cell.accessibilityLabel = NSLocalizedString(
            "View Shipment Details",
            comment: "Accessibility label for the 'View Shipment Details' button"
        )

        cell.accessibilityHint = NSLocalizedString(
            "Show the shipment details for this shipping label.",
            comment: "VoiceOver accessibility hint, informing the user that the button can be used to view shipping label shipment details."
        )
    }

    private func configureShippingLabelPrintingInfo(cell: ImageAndTitleAndTextTableViewCell) {
        cell.update(with: .imageAndTitleOnly(fontStyle: .footnote),
                    data: .init(title: Title.shippingLabelPrintingInfoAction,
                                image: .infoOutlineFootnoteImage,
                                imageTintColor: .systemColor(.secondaryLabel),
                                numberOfLinesForTitle: 0,
                                isActionable: false,
                                showsSeparator: false))

        cell.selectionStyle = .default

        cell.accessibilityTraits = .button
        cell.accessibilityLabel = Title.shippingLabelPrintingInfoAction
        cell.accessibilityHint =
            NSLocalizedString("Tap to show instructions on how to print a shipping label on the mobile device",
                              comment:
                                "VoiceOver accessibility hint for the row that shows instructions on how to print a shipping label on the mobile device")
    }

    private func configureShippingLabelProduct(cell: ProductDetailsTableViewCell, at indexPath: IndexPath) {
        cell.selectionStyle = .default

        guard let shippingLabel = shippingLabel(at: indexPath),
              let orderItem = shippingLabelOrderItemsAggregator.orderItem(of: shippingLabel, at: indexPath.row) else {
            assertionFailure("Cannot access shipping label and/or order item at \(indexPath)")
            return
        }

        let addOns = filterAddOns(of: orderItem)
        let itemViewModel = ProductDetailsCellViewModel(aggregateItem: orderItem,
                                                        currency: order.currency,
                                                        hasAddOns: addOns.isNotEmpty)
        cell.configure(item: itemViewModel, imageService: imageService)
        cell.onViewAddOnsTouchUp = { [weak self] in
            self?.onCellAction?(.viewAddOns(addOns: addOns), nil)
        }
    }

    private func configureShippingLabelTrackingNumber(cell: ImageAndTitleAndTextTableViewCell, at indexPath: IndexPath) {
        guard let shippingLabel = shippingLabel(at: indexPath) else {
            return
        }

        let viewModel = ImageAndTitleAndTextTableViewCell.ViewModel(title: Title.shippingLabelTrackingNumberTitle,
                                                                    text: shippingLabel.trackingNumber,
                                                                    textTintColor: nil,
                                                                    image: .locationImage,
                                                                    imageTintColor: .primary,
                                                                    numberOfLinesForTitle: 0,
                                                                    numberOfLinesForText: 0,
                                                                    isActionable: false)
        cell.updateUI(viewModel: viewModel)

        let actionButton = UIButton(type: .detailDisclosure)
        actionButton.applyIconButtonStyle(icon: .moreImage)
        actionButton.on(.touchUpInside) { [weak self] sender in
            self?.onCellAction?(.shippingLabelTrackingMenu(shippingLabel: shippingLabel, sourceView: sender), nil)
        }
        cell.accessoryView = actionButton
    }

    private func configureShippingLabelRefunded(cell: ImageAndTitleAndTextTableViewCell, at indexPath: IndexPath) {
        guard let shippingLabel = shippingLabel(at: indexPath), let refund = shippingLabel.refund else {
            return
        }

        let title = String.localizedStringWithFormat(Title.shippingLabelRefundedTitleFormat, shippingLabel.serviceName)
        let refundedAmount = currencyFormatter.formatAmount(Decimal(shippingLabel.refundableAmount), with: shippingLabel.currency) ?? ""
        let dateRequested = refund.dateRequested.toString(dateStyle: .medium, timeStyle: .short)
        let text = String.localizedStringWithFormat(Title.shippingLabelRefundedDetailsFormat, refundedAmount, dateRequested)
        let viewModel = ImageAndTitleAndTextTableViewCell.ViewModel(title: title,
                                                                    text: text,
                                                                    textTintColor: nil,
                                                                    image: .locationImage,
                                                                    imageTintColor: .primary,
                                                                    numberOfLinesForTitle: 0,
                                                                    numberOfLinesForText: 0,
                                                                    isActionable: false)
        cell.updateUI(viewModel: viewModel)
    }

    private func configureReprintShippingLabelButton(cell: ButtonTableViewCell, at indexPath: IndexPath) {
        cell.configure(style: .secondary,
                       title: Titles.reprintShippingLabel,
                       bottomSpacing: 8) { [weak self] in
            guard let self = self else { return }
            guard let shippingLabel = self.shippingLabel(at: indexPath) else {
                return
            }
            self.onCellAction?(.reprintShippingLabel(shippingLabel: shippingLabel), nil)
        }
        cell.hideSeparator()
    }

    private func configureAggregateOrderItem(cell: ProductDetailsTableViewCell, at indexPath: IndexPath) {
        cell.selectionStyle = .default

        let aggregateItem = aggregateOrderItems[indexPath.row]
        let imageURL: URL? = {
            guard let imageURLString = aggregateItem.variationID != 0 ?
                    lookUpProductVariation(productID: aggregateItem.productID, variationID: aggregateItem.variationID)?.image?.src:
                    lookUpProduct(by: aggregateItem.productID)?.images.first?.src,
                  let encodedImageURLString = imageURLString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                return nil
            }
            return URL(string: encodedImageURLString)
        }()

        let addOns = filterAddOns(of: aggregateItem)
        let itemViewModel = ProductDetailsCellViewModel(aggregateItem: aggregateItem.copy(imageURL: imageURL),
                                                        currency: order.currency,
                                                        hasAddOns: addOns.isNotEmpty)

        cell.configure(item: itemViewModel, imageService: imageService)
        cell.onViewAddOnsTouchUp = { [weak self] in
            self?.onCellAction?(.viewAddOns(addOns: addOns), nil)
        }
    }

    private func configureRefundedProducts(_ cell: WooBasicTableViewCell) {
        let singular = NSLocalizedString("%@ Item",
                                         comment: "1 Item")
        let plural = NSLocalizedString("%@ Items",
                                       comment: "For example, '5 Items'")
        let productText = String.pluralize(refundedProductsCount, singular: singular, plural: plural)

        cell.bodyLabel?.text = productText
        cell.applyPlainTextStyle()
        cell.accessoryType = .disclosureIndicator
        cell.selectionStyle = .default

        cell.accessibilityTraits = .button
        cell.accessibilityLabel = NSLocalizedString(
            "View refunded order items",
            comment: "Accessibility label for the '<number> Products' button"
        )

        cell.accessibilityHint = NSLocalizedString(
            "Show a list of refunded order items for this order.",
            comment: "VoiceOver accessibility hint, informing the user that the button can be used to view billing information."
        )
    }

    private func configureMarkCompleteButton(cell: ButtonTableViewCell,
                                             buttonStyle: ButtonTableViewCell.Style,
                                             showsBottomSpacing: Bool) {
        let bottomSpacing: CGFloat = showsBottomSpacing ? ButtonTableViewCell.Constants.defaultBottomSpacing : 0
        cell.configure(style: buttonStyle, title: Titles.markComplete, bottomSpacing: bottomSpacing) { [weak self] in
            self?.onCellAction?(.markComplete, nil)
        }
        cell.hideSeparator()
    }

    private func configureIssueRefundButton(cell: IssueRefundTableViewCell) {
        cell.onIssueRefundTouchUp = { [weak self] in
            self?.onCellAction?(.issueRefund, nil)
        }
    }

    private func configureTracking(cell: OrderTrackingTableViewCell, at indexPath: IndexPath) {
        guard let tracking = orderTracking(at: indexPath) else {
            return
        }

        cell.topText = tracking.trackingProvider
        cell.middleText = tracking.trackingNumber

        cell.onEllipsisTouchUp = { [weak self] in
            self?.onCellAction?(.tracking, indexPath)
        }

        if let dateShipped = tracking.dateShipped?.toString(dateStyle: .long, timeStyle: .none) {
            cell.bottomText = String.localizedStringWithFormat(
                NSLocalizedString("Shipped %@",
                                  comment: "Date an item was shipped"),
                dateShipped)
        } else {
            cell.bottomText = NSLocalizedString("Not shipped yet",
                                                comment: "Order details > tracking. " +
                " This is where the shipping date would normally display.")
        }
    }

    private func configureNewTracking(cell: LeftImageTableViewCell) {
        let cellTextContent = NSLocalizedString("Add Tracking", comment: "Add Tracking row label")
        cell.leftImage = .addOutlineImage
        cell.imageView?.tintColor = .accent
        cell.labelText = cellTextContent

        cell.accessibilityTraits = .button
        cell.accessibilityLabel = NSLocalizedString(
            "Add a tracking",
            comment: "Accessibility label for the 'Add a tracking' button"
        )

        cell.accessibilityHint = NSLocalizedString(
            "Adds tracking to an order.",
            comment: "VoiceOver accessibility hint, informing the user that the button can be used to add tracking to an order. Should end with a period."
        )
    }

    private func configureShippingAddress(cell: CustomerInfoTableViewCell) {
        let shippingAddress = order.shippingAddress

        cell.title = NSLocalizedString("Shipping details",
                                       comment: "Shipping title for customer info cell")
        cell.name = shippingAddress?.fullNameWithCompany
        cell.address = shippingAddress?.formattedPostalAddress ??
            NSLocalizedString(
                "No address specified.",
                comment: "Order details > customer info > shipping details. " +
                "This is where the address would normally display."
        )
    }

    private func configureShippingMethod(cell: CustomerNoteTableViewCell) {
        cell.headline = NSLocalizedString("Shipping Method",
                                          comment: "Shipping method title for customer info cell")
        cell.body = shippingMethod.strippedHTML
        cell.selectionStyle = .none
    }

    private func configureSummary(cell: SummaryTableViewCell) {
        let cellViewModel = SummaryTableViewCellViewModel(
            order: order,
            status: lookUpOrderStatus(for: order)
        )

        cell.configure(cellViewModel)

        cell.onEditTouchUp = { [weak self] in
            self?.onCellAction?(.summary, nil)
        }
    }

    /// Returns attributes that can be categorized as `Add-ons`.
    /// Returns an `empty` array if we can't find the product associated with order item or if the `addOns` feature is disabled.
    ///
    private func filterAddOns(of item: AggregateOrderItem) -> [OrderItemAttribute] {
        guard let product = products.first(where: { $0.productID == item.productID }), showAddOns else {
            return []
        }
        return AddOnCrossreferenceUseCase(orderItem: item, product: product, addOnGroups: addOnGroups).addOnsAttributes()
    }
}


// MARK: - Lookup orders and statuses
extension OrderDetailsDataSource {
    func lookUpOrderStatus(for order: Order) -> OrderStatus? {
        return currentSiteStatuses.filter({$0.status == order.status}).first
    }

    func lookUpProduct(by productID: Int64) -> Product? {
        return products.filter({ $0.productID == productID }).first
    }

    private func lookUpProductVariation(productID: Int64, variationID: Int64) -> ProductVariation? {
        return resultsControllers.productVariations.filter({ $0.productID == productID && $0.productVariationID == variationID }).first
    }

    func lookUpRefund(by refundID: Int64) -> Refund? {
        return refunds.filter({ $0.refundID == refundID }).first
    }

    func isMultiShippingLinesAvailable(for order: Order) -> Bool {
        return shippingLines.count > 1
    }
}


// MARK: - Sections
extension OrderDetailsDataSource {
    /// Setup: Sections
    ///
    /// CustomerInformation Behavior:
    /// When: Customer Note == nil          >>> Hide Customer Note
    /// When: Shipping == nil               >>> Display: Shipping = "No address specified"
    ///
    func reloadSections() {
        // Freezes any data that require lookup after the sections are reloaded, in case the data from a ResultsController changes before the next reload.
        shippingLabels = resultsControllers.shippingLabels
        shippingLabelOrderItemsAggregator = AggregatedShippingLabelOrderItems(shippingLabels: shippingLabels,
                                                                                   orderItems: items,
                                                                                   products: products,
                                                                                   productVariations: resultsControllers.productVariations)

        let summary = Section(category: .summary, row: .summary)

        let shippingNotice: Section? = {
            // Hide the shipping method warning if order contains only virtual products
            // or if the order contains only one shipping method
            if isMultiShippingLinesAvailable(for: order) == false {
                return nil
            }

            return Section(category: .shippingNotice, title: nil, rightTitle: nil, footer: nil, rows: [.shippingNotice])
        }()

        let products: Section? = {
            if items.isEmpty {
                return nil
            }

            let aggregateOrderItemCount = aggregateOrderItems.count
            guard aggregateOrderItemCount > 0 else {
                return nil
            }

            var rows: [Row] = Array(repeating: .aggregateOrderItem, count: aggregateOrderItemCount)

            if isEligibleForShippingLabelCreation {
                rows.append(.shippingLabelCreateButton)
            }

            if isProcessingPayment {
                if isEligibleForShippingLabelCreation {
                    rows.append(.markCompleteButton(style: .secondary, showsBottomSpacing: false))
                    rows.append(.shippingLabelCreationInfo(showsSeparator: false))
                } else {
                    rows.append(.markCompleteButton(style: .primary, showsBottomSpacing: true))
                }
            } else if isRefundedStatus == false {
                if isEligibleForShippingLabelCreation {
                    rows.append(.shippingLabelCreationInfo(showsSeparator: true))
                }

                rows.append(.details)
            }

            if rows.count == 0 {
                return nil
            }

            return Section(category: .products, title: Localization.pluralizedProducts(count: items.count), rightTitle: nil, rows: rows, headerStyle: .primary)
        }()

        let refundedProducts: Section? = {
            // Refunds on
            guard refundedProductsCount > 0 else {
                return nil
            }

            let row: Row = .refundedProducts

            return Section(category: .refundedProducts, title: Title.refundedProducts, row: row)
        }()

        let shippingLabelSections: [Section] = {
            guard shippingLabels.isNotEmpty else {
                return []
            }

            let sections = shippingLabels.enumerated().map { index, shippingLabel -> Section in
                let title = String.localizedStringWithFormat(Title.shippingLabelPackageFormat, index + 1)
                let isRefunded = shippingLabel.refund != nil
                let rows: [Row]
                let headerStyle: Section.HeaderStyle
                if isRefunded {
                    rows = [.shippingLabelRefunded, .shippingLabelDetail]
                    headerStyle = .primary
                } else {
                    // TODO-2167: show printing instructions
                    let orderItemsCount = shippingLabelOrderItemsAggregator.orderItems(of: shippingLabel).count
                    rows = Array(repeating: .shippingLabelProduct, count: orderItemsCount)
                        + [.shippingLabelReprintButton, .shippingLabelPrintingInfo, .shippingLabelTrackingNumber, .shippingLabelDetail]
                    let headerActionConfig = PrimarySectionHeaderView.ActionConfiguration(image: .moreImage) { [weak self] sourceView in
                        self?.onShippingLabelMoreMenuTapped?(shippingLabel, sourceView)
                    }
                    headerStyle = .actionablePrimary(actionConfig: headerActionConfig)
                }
                return Section(category: .shippingLabel, title: title, rows: rows, headerStyle: headerStyle)
            }
            return sections
        }()

        let customerInformation: Section = {
            var rows: [Row] = []

            if customerNote.isEmpty == false {
                rows.append(.customerNote)
            }

            let orderContainsOnlyVirtualProducts = self.products.filter { (product) -> Bool in
                return items.first(where: { $0.productID == product.productID}) != nil
            }.allSatisfy { $0.virtual == true }

            if order.shippingAddress != nil && orderContainsOnlyVirtualProducts == false {
                rows.append(.shippingAddress)
            }
            if shippingLines.count > 0 {
                rows.append(.shippingMethod)
            }
            rows.append(.billingDetail)

            return Section(category: .customerInformation, title: Title.information, rows: rows)
        }()

        let payment: Section = {
            var rows: [Row] = [.payment, .customerPaid]
            if condensedRefunds.isNotEmpty {
                let refunds = Array<Row>(repeating: .refund, count: condensedRefunds.count)
                rows.append(contentsOf: refunds)
                rows.append(.netAmount)
            }

            if !isRefundedStatus {
                rows.append(.issueRefundButton)
            }

            return Section(category: .payment, title: Title.payment, rows: rows)
        }()

        let tracking: Section? = {
            // Tracking section is hidden if there are non-empty non-refunded shipping labels.
            guard shippingLabels.nonRefunded.isEmpty else {
                return nil
            }

            guard orderTracking.count > 0 else {
                return nil
            }

            let rows: [Row] = Array(repeating: .tracking, count: orderTracking.count)
            return Section(category: .tracking, title: Title.tracking, rows: rows)
        }()

        let addTracking: Section? = {
            // Add tracking section is hidden if there are non-empty non-refunded shipping labels.
            guard shippingLabels.nonRefunded.isEmpty else {
                return nil
            }

            // Hide the section if the shipment
            // tracking plugin is not installed
            guard trackingIsReachable else {
                return nil
            }

            let title = orderTracking.count == 0 ? NSLocalizedString("Optional Tracking Information", comment: "") : nil
            let row = Row.trackingAdd

            return Section(category: .addTracking, title: title, rightTitle: nil, rows: [row])
        }()

        let notes: Section = {
            let rows = [.addOrderNote] + orderNotesSections.map {$0.row}
            return Section(category: .notes, title: Title.notes, rows: rows)
        }()

        sections = ([summary,
                    shippingNotice,
                    products] +
                    shippingLabelSections +
                    [refundedProducts,
                    payment,
                    customerInformation,
                    tracking,
                    addTracking,
                    notes]).compactMap { $0 }

        updateOrderNoteAsyncDictionary(orderNotes: orderNotes)
    }

    func refund(at indexPath: IndexPath) -> Refund? {
        let index = indexPath.row - Constants.paymentCell - Constants.paidByCustomerCell
        let condensedRefund = condensedRefunds[index]
        let refund = refunds.first { $0.refundID == condensedRefund.refundID }

        guard let refundFound = refund else {
            return nil
        }

        return refundFound
    }

    private func updateOrderNoteAsyncDictionary(orderNotes: [OrderNote]) {
        orderNoteAsyncDictionary.clear()
        for orderNote in orderNotes {
            let calculation = { () -> (String) in
                return orderNote.note.strippedHTML
            }
            let onSet = { [weak self] (note: String?) -> () in
                guard note != nil else {
                    return
                }
                self?.onUIReloadRequired?()
            }
            orderNoteAsyncDictionary.calculate(forKey: orderNote.noteID,
                                               operation: calculation,
                                               onCompletion: onSet)
        }
    }

    func rowAtIndexPath(_ indexPath: IndexPath) -> Row {
        return sections[indexPath.section].rows[indexPath.row]
    }

    func noteHeader(at indexPath: IndexPath) -> Date? {
        // We need to subtract by one because the first order note row is the "Add Order" cell
        let noteHeaderIndex = indexPath.row - Constants.addOrderCell
        guard orderNotesSections.indices.contains(noteHeaderIndex) else {
            return nil
        }

        return orderNotesSections[noteHeaderIndex].date
    }

    func note(at indexPath: IndexPath) -> OrderNote? {
        // We need to subtract by one because the first order note row is the "Add Order" cell
        let noteIndex = indexPath.row - Constants.addOrderCell
        guard orderNotesSections.indices.contains(noteIndex) else {
            return nil
        }

        return orderNotesSections[noteIndex].orderNote
    }

    func orderTracking(at indexPath: IndexPath) -> ShipmentTracking? {
        let orderIndex = indexPath.row
        guard orderTracking.indices.contains(orderIndex) else {
            return nil
        }

        return orderTracking[orderIndex]
    }

    /// Sends the provided Row's text data to the pasteboard
    ///
    /// - Parameter indexPath: IndexPath to copy text data from
    ///
    func copyText(at indexPath: IndexPath) {
        let row = rowAtIndexPath(indexPath)

        switch row {
        case .shippingAddress:
            sendToPasteboard(order.shippingAddress?.fullNameWithCompanyAndAddress)
        case .tracking:
            sendToPasteboard(orderTracking(at: indexPath)?.trackingNumber, includeTrailingNewline: false)
        default:
            break // We only send text to the pasteboard from the address rows right meow
        }
    }

    /// Sends the provided text to the general pasteboard and triggers a success haptic. If the text param
    /// is nil, nothing is sent to the pasteboard.
    ///
    /// - Parameter
    ///   - text: string value to send to the pasteboard
    ///   - includeTrailingNewline: If true, insert a trailing newline; defaults to true
    ///
    func sendToPasteboard(_ text: String?, includeTrailingNewline: Bool = true) {
        guard var text = text, text.isEmpty == false else {
            return
        }

        if includeTrailingNewline {
            text += "\n"
        }

        UIPasteboard.general.string = text
        hapticGenerator.notificationOccurred(.success)
    }

    /// Checks if copying the row data at the provided indexPath is allowed
    ///
    /// - Parameter indexPath: index path of the row to check
    /// - Returns: true is copying is allowed, false otherwise
    ///
    func checkIfCopyingIsAllowed(for indexPath: IndexPath) -> Bool {
        let row = rowAtIndexPath(indexPath)
        switch row {
        case .shippingAddress:
            if let _ = order.shippingAddress {
                return true
            }
        case .tracking:
            if orderTracking(at: indexPath)?.trackingNumber.isEmpty == false {
                return true
            }
        default:
            break
        }

        return false
    }

    func computeOrderNotesSections() -> [NoteSection] {
        var sections: [NoteSection] = []

        for order in orderNotes {
            if sections.contains(where: { (section) -> Bool in
                return Calendar.current.isDate(section.date, inSameDayAs: order.dateCreated) && section.row == .orderNoteHeader
            }) {
                let orderToAppend = NoteSection(row: .orderNote, date: order.dateCreated, orderNote: order)
                sections.append(orderToAppend)
            }
            else {
                let sectionToAppend = NoteSection(row: .orderNoteHeader, date: order.dateCreated, orderNote: order)
                let orderToAppend = NoteSection(row: .orderNote, date: order.dateCreated, orderNote: order)
                sections.append(contentsOf: [sectionToAppend, orderToAppend])
            }
        }

        return sections
    }
}


// MARK: - Constants
extension OrderDetailsDataSource {
    enum Titles {
        static let productDetails = NSLocalizedString("Details",
                                                      comment: "The row label to tap for a detailed product list")
        static let markComplete = NSLocalizedString("Mark Order Complete", comment: "Fulfill Order Action Button")
        static let addNoteText = NSLocalizedString("Add a note",
                                                   comment: "Button text for adding a new order note")
        static let paidByCustomer = NSLocalizedString("Paid",
                                                      comment: "The title for the customer payment cell")
        static let refunded = NSLocalizedString("Refunded",
                                                comment: "The title for the refunded amount cell")
        static let netAmount = NSLocalizedString("Net Payment", comment: "The title for the net amount paid cell")
        static let createShippingLabel = NSLocalizedString("Create Shipping Label", comment: "Text on the button that starts shipping label creation")
        static let reprintShippingLabel = NSLocalizedString("Reprint Shipping Label", comment: "Text on the button that reprints a shipping label")
    }

    enum Icons {
        static let addNoteIcon = UIImage.addOutlineImage
        static let shippingNoticeIcon = UIImage.noticeImage
    }

    enum Title {
        static let products = NSLocalizedString("Products", comment: "Product section title if there is more than one product.")
        static let product = NSLocalizedString("Product", comment: "Product section title if there is only one product.")
        static let refundedProducts = NSLocalizedString("Refunded Products", comment: "Section title")
        static let tracking = NSLocalizedString("Tracking", comment: "Order tracking section title")
        static let customerNote = NSLocalizedString("Customer Provided Note", comment: "Customer note section title")
        static let information = NSLocalizedString("Customer", comment: "Customer info section title")
        static let payment = NSLocalizedString("Payment", comment: "Payment section title")
        static let notes = NSLocalizedString("Order Notes", comment: "Order notes section title")
        static let shippingLabelCreationInfoAction =
            NSLocalizedString("Learn more about creating labels with your phone",
                              comment: "Title of button in order details > info link for creating a shipping label on the mobile device.")
        static let shippingLabelPackageFormat =
            NSLocalizedString("Package %d",
                              comment: "Order shipping label package section title format. The number indicates the index of the shipping label package.")
        static let shippingLabelTrackingNumberTitle = NSLocalizedString("Tracking number", comment: "Order shipping label tracking number row title.")
        static let shippingLabelRefundedDetailsFormat =
            NSLocalizedString("%1$@ • %2$@",
                              comment: "Order refunded shipping label title. The first variable shows the refunded amount (e.g. $12.90). " +
                                "The second variable shows the requested date (e.g. Jan 12, 2020 12:34 PM).")
        static let shippingLabelRefundedTitleFormat =
            NSLocalizedString("%@ label refund requested",
                              comment: "Order refunded shipping label title. The string variable shows the shipping label service name (e.g. USPS).")
        static let shippingLabelPrintingInfoAction =
            NSLocalizedString("Don’t know how to print from your phone?",
                              comment: "Title of button in order details > shipping label that shows the instructions on how to print " +
                                "a shipping label on the mobile device.")
    }

    enum Footer {
        static let showBilling = NSLocalizedString("View Billing Information",
                                                   comment: "Button on bottom of Customer's information to show the billing details")
        static let showShippingLabelDetails = NSLocalizedString("View Shipment Details",
                                                                comment: "Button on bottom of shipping label package card to show shipping details")
    }

    struct Section {
        enum Category {
            case summary
            case shippingNotice
            case products
            case shippingLabel
            case refundedProducts
            case payment
            case customerInformation
            case tracking
            case addTracking
            case notes
        }

        /// The table header style of a `Section`.
        ///
        enum HeaderStyle {
            /// Uses the PrimarySectionHeaderView
            case primary
            /// Uses the PrimarySectionHeaderView with action configuration
            case actionablePrimary(actionConfig: PrimarySectionHeaderView.ActionConfiguration)
            /// Uses the TwoColumnSectionHeaderView
            case twoColumn

            /// The type of `UITableViewHeaderFooterView` to use for this style.
            ///
            var viewType: UITableViewHeaderFooterView.Type {
                switch self {
                case .primary, .actionablePrimary:
                    return PrimarySectionHeaderView.self
                case .twoColumn:
                    return TwoColumnSectionHeaderView.self
                }
            }
        }

        let category: Category
        let title: String?
        let rightTitle: String?
        let footer: String?
        let rows: [Row]
        let headerStyle: HeaderStyle

        init(category: Category,
             title: String? = nil,
             rightTitle: String? = nil,
             footer: String? = nil,
             rows: [Row],
             headerStyle: HeaderStyle = .twoColumn) {
            self.category = category
            self.title = title
            self.rightTitle = rightTitle
            self.footer = footer
            self.rows = rows
            self.headerStyle = headerStyle
        }

        init(category: Category,
             title: String? = nil,
             rightTitle: String? = nil,
             footer: String? = nil,
             row: Row,
             headerStyle: HeaderStyle = .twoColumn) {
            self.init(category: category, title: title, rightTitle: rightTitle, footer: footer, rows: [row], headerStyle: headerStyle)
        }
    }

    struct NoteSection {
        let row: Row
        let date: Date
        let orderNote: OrderNote

        init(row: Row, date: Date, orderNote: OrderNote) {
            self.row = row
            self.date = date
            self.orderNote = orderNote
        }
    }

    /// Rows listed in the order they appear on screen
    ///
    enum Row: Equatable {
        case summary
        case aggregateOrderItem
        case markCompleteButton(style: ButtonTableViewCell.Style, showsBottomSpacing: Bool)
        case details
        case refundedProducts
        case issueRefundButton
        case customerNote
        case shippingAddress
        case shippingMethod
        case billingDetail
        case payment
        case customerPaid
        case refund
        case netAmount
        case tracking
        case trackingAdd
        case shippingLabelCreateButton
        case shippingLabelCreationInfo(showsSeparator: Bool)
        case shippingLabelDetail
        case shippingLabelPrintingInfo
        case shippingLabelProduct
        case shippingLabelRefunded
        case shippingLabelReprintButton
        case shippingLabelTrackingNumber
        case shippingNotice
        case addOrderNote
        case orderNoteHeader
        case orderNote

        var reuseIdentifier: String {
            switch self {
            case .summary:
                return SummaryTableViewCell.reuseIdentifier
            case .aggregateOrderItem:
                return ProductDetailsTableViewCell.reuseIdentifier
            case .markCompleteButton:
                return ButtonTableViewCell.reuseIdentifier
            case .details:
                return WooBasicTableViewCell.reuseIdentifier
            case .refundedProducts:
                return WooBasicTableViewCell.reuseIdentifier
            case .issueRefundButton:
                return IssueRefundTableViewCell.reuseIdentifier
            case .customerNote:
                return CustomerNoteTableViewCell.reuseIdentifier
            case .shippingAddress:
                return CustomerInfoTableViewCell.reuseIdentifier
            case .shippingMethod:
                return CustomerNoteTableViewCell.reuseIdentifier
            case .billingDetail:
                return WooBasicTableViewCell.reuseIdentifier
            case .payment:
                return LedgerTableViewCell.reuseIdentifier
            case .customerPaid:
                return TwoColumnHeadlineFootnoteTableViewCell.reuseIdentifier
            case .refund:
                return TwoColumnHeadlineFootnoteTableViewCell.reuseIdentifier
            case .netAmount:
                return TwoColumnHeadlineFootnoteTableViewCell.reuseIdentifier
            case .tracking:
                return OrderTrackingTableViewCell.reuseIdentifier
            case .trackingAdd:
                return LeftImageTableViewCell.reuseIdentifier
            case .shippingLabelCreateButton:
                return ButtonTableViewCell.reuseIdentifier
            case .shippingLabelCreationInfo:
                return ImageAndTitleAndTextTableViewCell.reuseIdentifier
            case .shippingLabelDetail:
                return WooBasicTableViewCell.reuseIdentifier
            case .shippingLabelPrintingInfo:
                return ImageAndTitleAndTextTableViewCell.reuseIdentifier
            case .shippingLabelProduct:
                return ProductDetailsTableViewCell.reuseIdentifier
            case .shippingLabelTrackingNumber, .shippingLabelRefunded:
                return ImageAndTitleAndTextTableViewCell.reuseIdentifier
            case .shippingLabelReprintButton:
                return ButtonTableViewCell.reuseIdentifier
            case .shippingNotice:
                return ImageAndTitleAndTextTableViewCell.reuseIdentifier
            case .addOrderNote:
                return LeftImageTableViewCell.reuseIdentifier
            case .orderNoteHeader:
                return OrderNoteHeaderTableViewCell.reuseIdentifier
            case .orderNote:
                return OrderNoteTableViewCell.reuseIdentifier
            }
        }
    }

    enum CellActionType {
        case markComplete
        case tracking
        case summary
        case issueRefund
        case reprintShippingLabel(shippingLabel: ShippingLabel)
        case createShippingLabel
        case shippingLabelTrackingMenu(shippingLabel: ShippingLabel, sourceView: UIView)
        case viewAddOns(addOns: [OrderItemAttribute])
    }

    struct Constants {
        static let addOrderCell = 1
        static let paymentCell = 1
        static let paidByCustomerCell = 1
    }
}

// MARK: - Private Utils

private extension OrderDetailsDataSource {
    enum Localization {
        static func pluralizedProducts(count: Int) -> String {
            count > 1 ? Title.products : Title.product
        }
    }
}
