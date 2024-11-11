//
//  LocationToolkit.swift
//  DebugSwift
//
//  Created by Matheus Gois on 19/12/23.
//

import CoreLocation
import Foundation

final class LocationToolkit {
    static let shared = LocationToolkit()
    private var routeSimulationTimer: Timer?
    
    var simulatedLocation: CLLocation? {
        get {
            if routeSimulation.isSimulating {
                return currentRouteLocation
            }
            
            let latitude = UserDefaults.standard.double(forKey: Constants.simulatedLatitude)
            let longitude = UserDefaults.standard.double(forKey: Constants.simulatedLongitude)
            guard !latitude.isZero, !longitude.isZero else { return nil }

            return .init(latitude: latitude, longitude: longitude)
        }
        set {
            if let location = newValue {
                UserDefaults.standard.set(
                    location.coordinate.latitude,
                    forKey: Constants.simulatedLatitude
                )
                UserDefaults.standard.set(
                    location.coordinate.longitude,
                    forKey: Constants.simulatedLongitude
                )
            } else {
                UserDefaults.standard.removeObject(
                    forKey: Constants.simulatedLatitude
                )
                UserDefaults.standard.removeObject(
                    forKey: Constants.simulatedLongitude
                )
            }
            UserDefaults.standard.synchronize()

            CLLocationManagerTracker.triggerUpdateForAllLocations()
        }
    }
    
    var routeSimulation: RouteSimulation {
        get {
            var simulation = RouteSimulation()
            
            if let data = UserDefaults.standard.data(forKey: RouteSimulation.Constants.simulatedRouteKey),
               let locations = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? [CLLocation] {
                simulation.locations = locations
            }
            
            if let speedRawValue = UserDefaults.standard.string(forKey: RouteSimulation.Constants.simulatedSpeedKey),
               let speed = RouteSimulation.Speed(rawValue: speedRawValue) {
                simulation.speed = speed
            }
            
            simulation.customSpeed = UserDefaults.standard.double(forKey: RouteSimulation.Constants.simulatedCustomSpeedKey)
            simulation.isSimulating = UserDefaults.standard.bool(forKey: RouteSimulation.Constants.simulatedIsActiveKey)
            
            return simulation
        }
        set {
            if let data = try? NSKeyedArchiver.archivedData(withRootObject: newValue.locations, requiringSecureCoding: false) {
                UserDefaults.standard.set(data, forKey: RouteSimulation.Constants.simulatedRouteKey)
            }
            
            UserDefaults.standard.set(newValue.speed.rawValue, forKey: RouteSimulation.Constants.simulatedSpeedKey)
            UserDefaults.standard.set(newValue.customSpeed, forKey: RouteSimulation.Constants.simulatedCustomSpeedKey)
            UserDefaults.standard.set(newValue.isSimulating, forKey: RouteSimulation.Constants.simulatedIsActiveKey)
            UserDefaults.standard.synchronize()
            
            if newValue.isSimulating {
                startRouteSimulation()
            } else {
                stopRouteSimulation()
            }
        }
    }
    
    private var currentRouteLocation: CLLocation?
    private var currentSegment: (start: CLLocation, end: CLLocation)?
    private var segmentProgress: Double = 0
    
    var indexSaved: Int {
        guard let simulatedLocation else { return -1 }
        if let index = presetLocations.firstIndex(
            where: {
                $0.latitude == simulatedLocation.coordinate.latitude &&
                    $0.longitude == simulatedLocation.coordinate.longitude
            }
        ) {
            return index + 1
        }

        return -1
    }

    let presetLocations: [PresetLocation] = {
        var presetLocations = [PresetLocation]()
        presetLocations.append(
            PresetLocation(
                title: "London, England",
                latitude: 51.509980,
                longitude: -0.133700
            )
        )
        presetLocations.append(
            PresetLocation(
                title: "Johannesburg, South Africa",
                latitude: -26.204103,
                longitude: 28.047305
            )
        )
        presetLocations.append(
            PresetLocation(
                title: "Moscow, Russia",
                latitude: 55.755786,
                longitude: 37.617633
            )
        )
        presetLocations.append(
            PresetLocation(
                title: "Mumbai, India",
                latitude: 19.017615,
                longitude: 72.856164
            )
        )
        presetLocations.append(
            PresetLocation(
                title: "Tokyo, Japan",
                latitude: 35.702069,
                longitude: 139.775327
            )
        )
        presetLocations.append(
            PresetLocation(
                title: "Sydney, Australia",
                latitude: -33.863400,
                longitude: 151.211000
            )
        )
        presetLocations.append(
            PresetLocation(
                title: "Hong Kong, China",
                latitude: 22.284681,
                longitude: 114.158177
            )
        )
        presetLocations.append(
            PresetLocation(
                title: "Honolulu, HI, USA",
                latitude: 21.282778,
                longitude: -157.829444
            )
        )
        presetLocations.append(
            PresetLocation(
                title: "San Francisco, CA, USA",
                latitude: 37.787359,
                longitude: -122.408227
            )
        )
        presetLocations.append(
            PresetLocation(
                title: "Mexico City, Mexico",
                latitude: 19.435478,
                longitude: -99.136479
            )
        )
        presetLocations.append(
            PresetLocation(
                title: "New York, NY, USA",
                latitude: 40.759211,
                longitude: -73.984638
            )
        )
        presetLocations.append(
            PresetLocation(
                title: "Rio de Janeiro, Brazil",
                latitude: -22.903539,
                longitude: -43.209587
            )
        )

        return presetLocations
    }()
    
    private func startRouteSimulation() {
        guard routeSimulation.locations.count >= 2 else { return }
        
        stopRouteSimulation()
        
        currentRouteLocation = routeSimulation.locations[0]
        setupNextSegment()
        
        routeSimulationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateRouteLocation()
        }
    }
    
    private func stopRouteSimulation() {
        routeSimulationTimer?.invalidate()
        routeSimulationTimer = nil
        currentRouteLocation = nil
        currentSegment = nil
        segmentProgress = 0
    }
    
    private func setupNextSegment() {
        guard routeSimulation.locations.count >= 2 else {
            stopRouteSimulation()
            return
        }
        
        let currentIndex = routeSimulation.currentLocationIndex
        let nextIndex = (currentIndex + 1) % routeSimulation.locations.count
        
        currentSegment = (
            start: routeSimulation.locations[currentIndex],
            end: routeSimulation.locations[nextIndex]
        )
        segmentProgress = 0
    }
    
    private func updateRouteLocation() {
        guard let segment = currentSegment else { return }
        
        let speed = routeSimulation.effectiveSpeed
        let totalDistance = segment.start.distance(from: segment.end)
        segmentProgress += speed
        
        if segmentProgress >= totalDistance {
            routeSimulation.currentLocationIndex = (routeSimulation.currentLocationIndex + 1) % routeSimulation.locations.count
            currentRouteLocation = routeSimulation.locations[routeSimulation.currentLocationIndex]
            setupNextSegment()
        } else {
            let fraction = segmentProgress / totalDistance
            let newLat = segment.start.coordinate.latitude + (segment.end.coordinate.latitude - segment.start.coordinate.latitude) * fraction
            let newLon = segment.start.coordinate.longitude + (segment.end.coordinate.longitude - segment.start.coordinate.longitude) * fraction
            currentRouteLocation = CLLocation(latitude: newLat, longitude: newLon)
        }
        
        CLLocationManagerTracker.triggerUpdateForAllLocations()
    }
}

final class PresetLocation {
    var title: String
    var latitude: Double
    var longitude: Double

    init(title: String, latitude: Double, longitude: Double) {
        self.title = title
        self.latitude = latitude
        self.longitude = longitude
    }
}

extension LocationToolkit {
    enum Constants {
        static let simulatedLatitude = "_simulatedLocationLatitude"
        static let simulatedLongitude = "_simulatedLocationLongitude"
    }
}
