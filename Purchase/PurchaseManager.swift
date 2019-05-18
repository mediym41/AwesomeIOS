
import StoreKit

public typealias ProductIdentifier = String
public typealias ProductsRequestCallback = (_ success: Bool, _ products: [SKProduct]?) -> Void
fileprivate typealias PurchaseRequestCallback = () -> Void

extension Notification.Name {
    static let purchaseStatus = Notification.Name("SuccessfulPurchaseNotification")
}

enum PurchaseStatus {
    case purchasing, purchased, accrued, deferred, restored, failed
}

open class PurchaseManager: NSObject  {
    
    public static let shared = PurchaseManager()
    
    private let productIdentifiers: Set<ProductIdentifier>
    private var products: [String: SKProduct] = [:]
    
    private var productsRequest: SKProductsRequest?
    private var productsRequestCallback: ProductsRequestCallback?
    private var purchaseRequestCallback: PurchaseRequestCallback?
    
    public override init() {
        productIdentifiers = Set(PurchaseManager.getProductIdentifiers())
        super.init()
    }
    
    func initialize() {
        SKPaymentQueue.default().add(self)
        requestProducts()
    }
    
    // MARK: - Hardcode
    static func getProductIdentifiers() -> [String] {
        return [
            "single.7", "single.30", "single.90", "single.180", "single.365", "single.730",
            "double.7", "double.30", "double.90", "double.180", "double.365", "double.730"
        ]
    }
}

// MARK: - StoreKit API

extension PurchaseManager {
    
    public func requestProducts(_ completionHandler: ProductsRequestCallback? = nil) {
        productsRequest?.cancel()
        productsRequestCallback = completionHandler
        
        productsRequest = SKProductsRequest(productIdentifiers: productIdentifiers)
        productsRequest!.delegate = self
        productsRequest!.start()
    }
    
    public func buyProduct(id: String) {
        guard let product = products[id] else { return }
        let payment = SKPayment(product: product)
        SKPaymentQueue.default().add(payment)
    }
    
    public func canMakePayments() -> Bool {
        return SKPaymentQueue.canMakePayments()
    }
    
    public func restorePurchases() {
        SKPaymentQueue.default().restoreCompletedTransactions()
    }
}

// MARK: - SKProductsRequestDelegate

extension PurchaseManager: SKProductsRequestDelegate {
    
    public func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        let result = response.products
        productsRequestCallback?(true, result)
        clearRequestAndHandler()
        
        for product in result {
            products[product.productIdentifier] = product
        }
    }
    
    public func request(_ request: SKRequest, didFailWithError error: Error) {
        print("Failed to load list of products.")
        print("Error: \(error.localizedDescription)")
        productsRequestCallback?(false, nil)
        clearRequestAndHandler()
    }
    
    private func clearRequestAndHandler() {
        productsRequest = nil
        productsRequestCallback = nil
    }
}

// MARK: - SKPaymentTransactionObserver

extension PurchaseManager: SKPaymentTransactionObserver {
    
    public func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            switch transaction.transactionState {
            case .purchased:
                complete(transaction: transaction)
            case .failed:
                fail(transaction: transaction)
            case .restored:
                restore(transaction: transaction)
            case .deferred:
                deferr(transaction: transaction)
            case .purchasing:
                purchase(transaction: transaction)
            }
        }
    }
    
    private func complete(transaction: SKPaymentTransaction) {
        postPurchaseNotification(for: transaction, with: .purchased)
        
        guard let receiptURL = Bundle.main.appStoreReceiptURL else {
            print("Can't get receipt url")
            return
        }
        
        let isSandBox = receiptURL.path.contains("sandboxReceipt")
        
        do {
            let receipt = try Data(contentsOf: receiptURL)
            let base64receipt = receipt.base64EncodedString()
            
//            ServerAPI.shared.payverify(data: base64receipt, isSandBox: isSandBox) { result in
//                self.handleValidationResult(transaction: transaction, result: result)
//            }
        } catch {
            print("Error occured")
        }
    }
    
    private func restore(transaction: SKPaymentTransaction) {
        postPurchaseNotification(for: transaction, with: .restored)
        SKPaymentQueue.default().finishTransaction(transaction)
    }
    
    private func fail(transaction: SKPaymentTransaction) {
        SKPaymentQueue.default().finishTransaction(transaction)
        
        var params: [String: Any] = [:]
        if let transactionError = transaction.error as NSError?,
            let localizedDescription = transaction.error?.localizedDescription,
            transactionError.code != SKError.paymentCancelled.rawValue {
            params["error"] = localizedDescription
        }
        
        postPurchaseNotification(for: transaction, with: .failed, params: params)
    }
    
    private func deferr(transaction: SKPaymentTransaction) {
        postPurchaseNotification(for: transaction, with: .deferred)
    }
    
    private func purchase(transaction: SKPaymentTransaction) {
        postPurchaseNotification(for: transaction, with: .purchasing)
    }
    
    private func postPurchaseNotification(for transaction: SKPaymentTransaction?, with state: PurchaseStatus, params: [String: Any] = [:]) {
        var userInfo: [String: Any] = [
            "identifier": transaction?.transactionIdentifier as Any,
            "status": state
        ]
        
        NotificationCenter.default.post(name: .purchaseStatus, object: nil, userInfo: userInfo)
    }
    
//    private func handleValidationResult(transaction: SKPaymentTransaction, result: APIResponse<[Subscription]>) {
//
//        switch result {
//        case .success:
//            SKPaymentQueue.default().finishTransaction(transaction)
//            postPurchaseNotification(for: transaction, with: .accrued)
//        case .error(let message, _):
//            let params = ["error": message]
//            postPurchaseNotification(for: transaction, with: .failed, params: params)
//        }
//    }
    
}
