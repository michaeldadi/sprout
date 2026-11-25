//
//  Tab.swift
//  Sprout
//
//  Created by Michael Dadi on 8/23/25.
//

import Foundation

enum Tab: String, CaseIterable {
    case dashboard = "house.fill"
    case budget = "chart.pie.fill"
    case transactions = "list.bullet"
    case profile = "person.crop.circle.fill"

    var title: String {
        switch self {
        case .dashboard:
            return "Home"
        case .budget:
            return "Budget"
        case .transactions:
            return "Activity"
        case .profile:
            return "Profile"
        }
    }

    var index: Int {
        switch self {
        case .dashboard:
            return 0
        case .budget:
            return 1
        case .transactions:
            return 2
        case .profile:
            return 3
        }
    }

    static func fromIndex(_ index: Int) -> Tab? {
        switch index {
        case 0:
            return .dashboard
        case 1:
            return .budget
        case 2:
            return .transactions
        case 3:
            return .profile
        default:
            return nil
        }
    }
}
