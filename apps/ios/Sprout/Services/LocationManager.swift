import Foundation
import CoreLocation
import Combine

@MainActor
class LocationManager: NSObject, ObservableObject {
    static let shared = LocationManager()
    
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentLocation: CLLocation?
    @Published var locationError: String?
    
    private let locationManager = CLLocationManager()
    private var hasRequestedPermission = false
    private var cancellables = Set<AnyCancellable>()
    
    private override init() {
        super.init()
        setupLocationManager()
        observeAuthenticationStatus()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = locationManager.authorizationStatus
    }
    
    private func observeAuthenticationStatus() {
        // Listen for authentication status changes
        AuthService.shared.$isAuthenticated
            .sink { [weak self] isAuthenticated in
                if isAuthenticated && !self!.hasRequestedPermission {
                    // User just signed in successfully, request location permission
                    self?.requestLocationPermissionOnce()
                }
            }
            .store(in: &cancellables)
    }
    
    private func requestLocationPermissionOnce() {
        // Only request permission once per app session after login
        guard !hasRequestedPermission else { return }
        
        hasRequestedPermission = true
        
        // Check current authorization status
        switch locationManager.authorizationStatus {
        case .notDetermined:
            // Request permission for the first time
            locationManager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            // User has previously denied permission
            locationError = "Location access is required for full app functionality. Please enable it in Settings."
        case .authorizedWhenInUse, .authorizedAlways:
            // Already have permission, start location updates if needed
            startLocationUpdates()
        @unknown default:
            break
        }
    }
    
    func startLocationUpdates() {
        guard locationManager.authorizationStatus == .authorizedWhenInUse ||
              locationManager.authorizationStatus == .authorizedAlways else {
            return
        }
        
        locationManager.startUpdatingLocation()
    }
    
    func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
    }
    
    func requestSingleLocation() {
        guard locationManager.authorizationStatus == .authorizedWhenInUse ||
              locationManager.authorizationStatus == .authorizedAlways else {
            return
        }
        
        locationManager.requestLocation()
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
            
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                self.locationError = nil
                // Start location updates if needed
                self.startLocationUpdates()
            case .denied, .restricted:
                self.locationError = "Location access denied. Some features may be limited."
            case .notDetermined:
                break
            @unknown default:
                break
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        Task { @MainActor in
            self.currentLocation = location
            self.locationError = nil
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.locationError = error.localizedDescription
        }
    }
}