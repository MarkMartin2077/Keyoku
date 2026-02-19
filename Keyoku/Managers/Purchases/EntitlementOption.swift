//
//  EntitlementOption.swift
//  
//
//  
//

enum EntitlementOption: Codable, CaseIterable {
    case yearly
    case monthly

    var productId: String {
        switch self {
        case .yearly:
            return "markmartin89.Keyoku.yearly"
        case .monthly:
            return "markmartin89.Keyoku.monthly"
        }
    }

    static var allProductIds: [String] {
        EntitlementOption.allCases.map({ $0.productId })
    }
}
