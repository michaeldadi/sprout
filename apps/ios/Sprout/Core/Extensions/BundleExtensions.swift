//
//  BundleExtensions.swift
//  Sprout
//
//  Created by Michael Dadi on 8/22/25.
//

import Foundation

extension Bundle {
    var appVersion: String {
        return infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    var buildNumber: String {
        return infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var appVersionWithBuild: String {
        return "\(appVersion) (\(buildNumber))"
    }

    var appBundleIdentifier: String {
        return Bundle.main.bundleIdentifier ?? "unknown"
    }
}
