//
//  SafariView.swift
//  Sprout
//
//  Created by Michael Dadi on 8/20/25.
//

import SafariServices
import SwiftUI

struct WebDestination: Identifiable, Equatable {
    let id = UUID()
    let url: URL
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let vc = SFSafariViewController(url: url)
        vc.modalPresentationStyle = .pageSheet
        vc.dismissButtonStyle = .close
        return vc
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
