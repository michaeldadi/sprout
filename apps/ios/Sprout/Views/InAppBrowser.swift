import SwiftUI
import SafariServices

struct InAppBrowser: View {
    let url: URL
    @Binding var isPresented: Bool
    
    var body: some View {
        SafariViewControllerWrapper(url: url, isPresented: $isPresented)
            .ignoresSafeArea()
    }
}

struct SafariViewControllerWrapper: UIViewControllerRepresentable {
    let url: URL
    @Binding var isPresented: Bool
    
    func makeUIViewController(context: Context) -> UIViewController {
        let container = UIViewController()
        container.view.backgroundColor = .systemBackground
        
        // Create Safari configuration
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        config.barCollapsingEnabled = true
        
        // Create Safari view controller
        let safari = SFSafariViewController(url: url, configuration: config)
        safari.preferredBarTintColor = .systemBackground
        safari.preferredControlTintColor = .label
        safari.dismissButtonStyle = .done
        safari.delegate = context.coordinator
        
        // Present Safari immediately after the container appears
        DispatchQueue.main.async {
            container.present(safari, animated: true) {
                print("Safari presented successfully for URL: \(url.absoluteString)")
            }
        }
        
        return container
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented)
    }
    
    class Coordinator: NSObject, SFSafariViewControllerDelegate {
        @Binding var isPresented: Bool
        
        init(isPresented: Binding<Bool>) {
            self._isPresented = isPresented
        }
        
        func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
            isPresented = false
        }
        
        func safariViewController(_ controller: SFSafariViewController, didCompleteInitialLoad didLoadSuccessfully: Bool) {
            print("Safari loaded: \(didLoadSuccessfully)")
        }
    }
}