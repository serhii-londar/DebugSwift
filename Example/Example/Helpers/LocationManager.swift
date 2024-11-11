//
//  LocationManager.swift
//  DebugSwift
//
//  Created by Matheus Gois on 19/12/23.
//

import CoreLocation
import MapKit
import DebugSwift

class LocationManager: NSObject, CLLocationManagerDelegate {

    static var shared = LocationManager()
    private var locationManager = CLLocationManager()
    private var locationUpdateTimer: Timer?

    var didUpdate: ((String) -> Void)?
    var didUpdateLocation: ((CLLocation) -> Void)?

    override init() {
        super.init()
        setupLocationManager()
        startLocationUpdateTimer()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
    }
    
    private func startLocationUpdateTimer() {
        // Check for location updates every second to catch simulated location changes
        locationUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            if let location = self?.locationManager.location {
                self?.handleLocationUpdate(location)
            }
        }
    }
    
    private func handleLocationUpdate(_ location: CLLocation) {
        didUpdateLocation?(location)
        
        CLGeocoder().reverseGeocodeLocation(location) { [weak self] placemarks, error in
            if let error = error {
                print("Error: " + error.localizedDescription)
                return
            }

            if let placemark = placemarks?.first {
                self?.displayLocationInfo(placemark)
            }
        }
    }

    func requestLocation() {
        locationManager.requestLocation()
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        handleLocationUpdate(location)
    }

    func displayLocationInfo(_ placemark: CLPlacemark) {
        let value = """
        \(placemark.locality ?? "")
        \(placemark.postalCode ?? "")
        \(placemark.administrativeArea ?? "")
        \(placemark.country ?? "")
        """

        didUpdate?(value)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Error: " + error.localizedDescription)
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
        case .denied, .restricted:
            print("Location access denied")
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        @unknown default:
            break
        }
    }
    
    deinit {
        locationUpdateTimer?.invalidate()
        locationUpdateTimer = nil
    }
}
