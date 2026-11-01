import Combine
import Foundation
import StoreKit

@MainActor
final class PurchaseManager: ObservableObject {
    static let productID = "com.erlendthune.fartlekaudiocoach.fullcoach"

    @Published private(set) var product: Product?
    @Published private(set) var isPremium = false
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private var transactionUpdatesTask: Task<Void, Never>?

    init() {
        transactionUpdatesTask = Task { [weak self] in
            await self?.observeTransactionUpdates()
        }
        Task {
            await refresh()
        }
    }

    deinit {
        transactionUpdatesTask?.cancel()
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            product = try await Product.products(for: [Self.productID]).first
            await updateEntitlement()
        } catch {
            errorMessage = "Unable to load the purchase details."
        }
    }

    func purchase() async {
        guard let product else {
            await refresh()
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(.verified(let transaction)):
                isPremium = true
                await transaction.finish()
            case .success(.unverified):
                errorMessage = "The purchase could not be verified."
            case .userCancelled:
                break
            case .pending:
                errorMessage = "The purchase is pending approval."
            @unknown default:
                break
            }
        } catch {
            errorMessage = "The purchase could not be completed."
        }
    }

    func restore() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await AppStore.sync()
            await updateEntitlement()
        } catch {
            errorMessage = "Unable to restore purchases."
        }
    }

    private func updateEntitlement() async {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == Self.productID {
                isPremium = true
                return
            }
        }
        isPremium = false
    }

    private func observeTransactionUpdates() async {
        for await result in Transaction.updates {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == Self.productID {
                isPremium = true
            }
            await transaction.finish()
        }
    }
}
