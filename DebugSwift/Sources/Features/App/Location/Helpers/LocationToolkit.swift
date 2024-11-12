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
    
    private var routeSimulatedLocation: CLLocation?
    private var routeSimulationTimer: Timer?
    private let locationUpdateTimeInterval: TimeInterval = 1
    
    var simulatedLocation: CLLocation? {
        get {
            if routeSimulation.isSimulating {
                return self.routeSimulatedLocation
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
    
    private var targetRouteLocationIndex: Int = -1
    private var targetRouteLocation: CLLocation? {
        if targetRouteLocationIndex >= 0 && targetRouteLocationIndex < routeSimulation.locations.count {
            return routeSimulation.locations[targetRouteLocationIndex]
        } else {
            return nil
        }
    }
    
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

        // ... (rest of presetLocations remain unchanged)
        return presetLocations
    }()
    
    private func startRouteSimulation() {
        guard routeSimulation.locations.count >= 2 else { return }
        
        stopRouteSimulation()
        
        routeSimulatedLocation = routeSimulation.locations[0]
        targetRouteLocationIndex = 1
        
        // Update more frequently for smoother animation
        routeSimulationTimer = Timer.scheduledTimer(withTimeInterval: locationUpdateTimeInterval, repeats: true) { [weak self] _ in
            self?.updateRouteLocation()
        }
    }
    
    private func stopRouteSimulation() {
        routeSimulationTimer?.invalidate()
        routeSimulationTimer = nil
        targetRouteLocationIndex = -1
    }

    private func updateRouteLocation() {
        guard let targetRouteLocation else { return }
        
        let speed = routeSimulation.effectiveSpeedMS
        
        if let routeSimulatedLocation {
            let distance = routeSimulatedLocation.distance(from: targetRouteLocation)
            let stepDistance = speed * locationUpdateTimeInterval
            if distance < stepDistance {
                self.routeSimulatedLocation = targetRouteLocation
                targetRouteLocationIndex += 1
                
                if targetRouteLocationIndex >= routeSimulation.locations.count {
                    stopRouteSimulation()
                    return
                }
                
                let remainingDistance = stepDistance - distance
                let course = routeSimulatedLocation.bearing(to: self.targetRouteLocation!)
                self.routeSimulatedLocation = routeSimulatedLocation.nextLocation(withCourse: course, distance: remainingDistance)
            } else {
                let course = routeSimulatedLocation.bearing(to: targetRouteLocation)
                self.routeSimulatedLocation = routeSimulatedLocation.nextLocation(withCourse: course, distance: stepDistance)
            }
        } else {
            routeSimulatedLocation = targetRouteLocation
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

extension CLLocation {
    func nextLocation(withCourse course: CLLocationDirection, distance: CLLocationDistance) -> CLLocation {
        let courseRadians = course.degreesToRadians
        let distRadians = distance / (6372797.6) // earth radius in meters
        
        let lat1 = self.coordinate.latitude.degreesToRadians
        let lon1 = self.coordinate.longitude.degreesToRadians
        
        let lat2 = asin(sin(lat1) * cos(distRadians) + cos(lat1) * sin(distRadians) * cos(courseRadians))
        let lon2 = lon1 + atan2(sin(courseRadians) * sin(distRadians) * cos(lat1), cos(distRadians) - sin(lat1) * sin(lat2))
        
        return CLLocation(latitude: lat2.radiansToDegrees, longitude: lon2.radiansToDegrees)
    }
    
    func bearing(to destination: CLLocation) -> CLLocationDirection {
        let lat1 = self.coordinate.latitude.degreesToRadians
        let lon1 = self.coordinate.longitude.degreesToRadians
        
        let lat2 = destination.coordinate.latitude.degreesToRadians
        let lon2 = destination.coordinate.longitude.degreesToRadians
        
        let dLon = lon2 - lon1
        
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1)*sin(lat2) - sin(lat1)*cos(lat2)*cos(dLon)
        
        var bearing = atan2(y, x)
        
        bearing = bearing.radiansToDegrees
        if bearing < 0 {
            bearing += 360
        }
        
        return CLLocationDirection(bearing)
    }
}

extension CLLocationDegrees {
    var degreesToRadians: Double { return self * .pi / 180 }
    var radiansToDegrees: Double { return self * 180 / .pi }
    var normalizedDegrees: Double { return (self + 360).truncatingRemainder(dividingBy: 360) }
    var normalizedRadians: Double { (self + (2 * Double.pi))
        .truncatingRemainder(dividingBy: 2 * Double.pi) }
}
