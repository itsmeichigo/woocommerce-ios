import Foundation
import Storage

public protocol MockObjectGraph {
    var userCredentials: Credentials { get }
    var defaultAccount: Account { get }
    var defaultSite: Site { get }
    var defaultSiteAPI: SiteAPI { get }

    var sites: [Site] { get }
    var orders: [Order] { get }
    var products: [Product] { get }
    var reviews: [ProductReview] { get }

    func accountWithId(id: Int64) -> Account
    func accountSettingsWithUserId(userId: Int64) -> AccountSettings

    func siteWithId(id: Int64) -> Site

    var currentNotificationCount: Int { get }
    var statsVersion: StatsVersion { get }

    func statsV4ShouldBeAvailable(forSiteId: Int64) -> Bool
}

let mockResourceUrlHost = "http://localhost:9285/"

// MARK: Product Accessors
extension MockObjectGraph {

    func product(forSiteId siteId: Int64, productId: Int64) -> Product {
        return products(forSiteId: siteId).first { $0.productID == productId }!
    }

    func products(forSiteId siteId: Int64) -> [Product] {
        return products.filter { $0.siteID == siteId }
    }

    func products(forSiteId siteId: Int64, productIds: [Int64]) -> [Product] {
        return products(forSiteId: siteId).filter { productIds.contains($0.productID) }
    }

    func products(forSiteId siteId: Int64, without productIDs: [Int64]) -> [Product] {
        return products(forSiteId: siteId).filter { !productIDs.contains($0.productID) }
    }
}

// MARK: Order Accessors
extension MockObjectGraph {

    func order(forSiteId siteId: Int64, orderId: Int64) -> Order? {
        return orders(forSiteId: siteId).first { $0.orderID == orderId }
    }

    func orders(forSiteId siteId: Int64) -> [Order] {
        return orders.filter { $0.siteID == siteId }
    }

    func orders(withStatus status: OrderStatusEnum, forSiteId siteId: Int64) -> [Order] {
        return orders(forSiteId: siteId).filter { $0.status == status }
    }
}

// MARK: ProductReview Accessors
extension MockObjectGraph {

    func review(forSiteId siteId: Int64, reviewId: Int64) -> ProductReview? {
        reviews(forSiteId: siteId).first { $0.reviewID == reviewId }
    }

    func reviews(forSiteId siteId: Int64) -> [ProductReview] {
        reviews.filter { $0.siteID == siteId }
    }
}

// MARK: Product => OrderItem Transformer
let priceFormatter = NumberFormatter()

extension MockObjectGraph {

    static func createOrderItem(from product: Product, count: Decimal) -> OrderItem {

        let price = priceFormatter.number(from: product.price)!.decimalValue as NSDecimalNumber
        let total = priceFormatter.number(from: product.price)!.decimalValue * count

        return OrderItem(
            itemID: 0,
            name: product.name,
            productID: product.productID,
            variationID: 0,
            quantity: count,
            price: price,
            sku: nil,
            subtotal: "\(total)",
            subtotalTax: "",
            taxClass: "",
            taxes: [],
            total: "\(total)",
            totalTax: "0",
            attributes: []
        )
    }
}

// MARK: Product Creation Helper
extension MockObjectGraph {
    static func createProduct(
        name: String,
        price: Decimal,
        salePrice: Decimal? = nil,
        quantity: Int64,
        siteId: Int64 = 1,
        image: ProductImage? = nil
    ) -> Product {

        let productId = ProductId.next

        let defaultImage = ProductImage(
            imageID: productId,
            dateCreated: Date(),
            dateModified: nil,
            src: mockResourceUrlHost + name.slugified!,
            name: name,
            alt: name
        )

        let images = image != nil ? [image!] : [defaultImage]

        return Product(
            siteID: siteId,
            productID: productId,
            name: name,
            slug: name.slugified!,
            permalink: "",
            date: Date(),
            dateCreated: Date(),
            dateModified: nil,
            dateOnSaleStart: nil,
            dateOnSaleEnd: nil,
            productTypeKey: "",
            statusKey: "",
            featured: true,
            catalogVisibilityKey: "",
            fullDescription: nil,
            shortDescription: nil,
            sku: nil,
            price: priceFormatter.string(from: price as NSNumber)!,
            regularPrice: nil,
            salePrice: salePrice == nil ? nil : priceFormatter.string(from: salePrice! as NSNumber)!,
            onSale: salePrice != nil,
            purchasable: true,
            totalSales: 99,
            virtual: false,
            downloadable: false,
            downloads: [],
            downloadLimit: 0,
            downloadExpiry: 0,
            buttonText: "Buy",
            externalURL: nil,
            taxStatusKey: "foo",
            taxClass: nil,
            manageStock: true,
            stockQuantity: quantity,
            stockStatusKey: ProductStockStatus.from(quantity: quantity).rawValue,
            backordersKey: "",
            backordersAllowed: true,
            backordered: quantity < 0,
            soldIndividually: true,
            weight: "20 grams",
            dimensions: .init(length: "10", width: "10", height: "10"),
            shippingRequired: true,
            shippingTaxable: true,
            shippingClass: "",
            shippingClassID: 0,
            productShippingClass: .none,
            reviewsAllowed: true,
            averageRating: "5",
            ratingCount: 64,
            relatedIDs: [],
            upsellIDs: [],
            crossSellIDs: [],
            parentID: 0,
            purchaseNote: nil,
            categories: [],
            tags: [],
            images: images,
            attributes: [],
            defaultAttributes: [],
            variations: [],
            groupedProducts: [],
            menuOrder: 0
        )
    }
}

// MARK: Order Creation Helper
extension MockObjectGraph {
    static func createOrder(
        number: Int64,
        customer: MockCustomer,
        status: OrderStatusEnum,
        daysOld: Int = 0,
        total: Decimal,
        items: [OrderItem] = []
    ) -> Order {

        Order(
            siteID: 1,
            orderID: number,
            parentID: 0,
            customerID: 1,
            number: "\(number)",
            status: status,
            currency: "USD",
            customerNote: nil,
            dateCreated: Calendar.current.date(byAdding: .day, value: daysOld * -1, to: Date()) ?? Date(),
            dateModified: Date(),
            datePaid: nil,
            discountTotal: "0",
            discountTax: "0",
            shippingTotal: "0",
            shippingTax: "0",
            total: priceFormatter.string(from: total as NSNumber)!,
            totalTax: "0",
            paymentMethodID: "0",
            paymentMethodTitle: "MasterCard",
            items: items,
            billingAddress: customer.billingAddress,
            shippingAddress: customer.billingAddress,
            shippingLines: [],
            coupons: [],
            refunds: []
        )
    }
}

// MARK: ProductReview Creation Helper
extension MockObjectGraph {
    static func createProductReview(
        product: Product,
        customer: MockCustomer,
        daysOld: Int = 0,
        status: ProductReviewStatus,
        text: String,
        rating: Int,
        verified: Bool
    ) -> ProductReview {
        ProductReview(
            siteID: 1,
            reviewID: -1,
            productID: product.productID,
            dateCreated: Date(),
            statusKey: status.rawValue,
            reviewer: customer.fullName,
            reviewerEmail: customer.email ?? customer.defaultEmail,
            reviewerAvatarURL: customer.defaultGravatar,
            review: text,
            rating: rating,
            verified: verified
        )
    }
}
