//
//  SafariView.swift
//  Sprout
//
//  Created by Michael Dadi on 8/20/25.
//

import SafariServices
import SwiftUI

// Safari WebKit Initializer - singleton that ensures WebKit is ready
class SafariInitializer {
    static let shared = SafariInitializer()
    private var hasInitialized = false
    
    private init() {}
    
    func ensureInitialized() {
        guard !hasInitialized else { return }
        
        // Create a hidden Safari controller to initialize WebKit
        if let url = URL(string: "https://www.apple.com") {
            let controller = SFSafariViewController(url: url)
            _ = controller.view
            controller.view.layoutIfNeeded()
            hasInitialized = true
            print("Safari WebKit initialized")
        }
    }
}

// Safari View Controller Wrapper
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let configuration = SFSafariViewController.Configuration()
        configuration.entersReaderIfAvailable = false
        configuration.barCollapsingEnabled = true
        
        let safariViewController = SFSafariViewController(url: url, configuration: configuration)
        
        // Set delegate
        safariViewController.delegate = context.coordinator
        
        // Appearance configuration
        safariViewController.preferredBarTintColor = UIColor.systemBackground
        safariViewController.preferredControlTintColor = UIColor.systemBlue
        safariViewController.dismissButtonStyle = .close
        
        // Force view initialization
        _ = safariViewController.view
        safariViewController.view.layoutIfNeeded()
        
        print("SafariView: Loading URL: \(url.absoluteString)")
        
        return safariViewController
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }
    
    class Coordinator: NSObject, SFSafariViewControllerDelegate {
        let url: URL
        
        init(url: URL) {
            self.url = url
        }
        
        func safariViewController(_ controller: SFSafariViewController, didCompleteInitialLoad didLoadSuccessfully: Bool) {
            print("SafariView: Initial load completed. Success: \(didLoadSuccessfully)")
            if !didLoadSuccessfully {
                print("SafariView: Failed to load URL: \(url.absoluteString)")
            }
        }
        
        func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
            print("SafariView: User dismissed Safari view")
        }
    }
}
