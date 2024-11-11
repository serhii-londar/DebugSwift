//
//  MapSelectionViewController.swift
//  DebugSwift
//
//  Created by Matheus Gois on 19/12/23.
//

import MapKit
import UIKit

protocol LocationSelectionDelegate: AnyObject {
    func didSelectLocation(_ location: CLLocation)
}

final class MapSelectionViewController: BaseController {

    private var mapView: MKMapView?
    private var selectedLocationAnnotation: MKPointAnnotation?
    private var selectedLocation: CLLocation?
    private var existingLocations: [CLLocation]?
    private var routeOverlay: MKPolyline?

    weak var delegate: LocationSelectionDelegate?

    init(
        selectedLocation: CLLocation? = nil,
        existingLocations: [CLLocation]? = nil,
        delegate: LocationSelectionDelegate? = nil
    ) {
        self.selectedLocation = selectedLocation
        self.existingLocations = existingLocations
        self.delegate = delegate
        super.init()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setup()
    }

    private func setup() {
        setupMapView()
        setupUI()
        setupNavigationBar()
        setupGestureRecognizer()
        if let existingLocations = existingLocations {
            displayExistingLocations(existingLocations)
        }
    }

    private func setupMapView() {
        mapView = MKMapView()
        mapView?.delegate = self

        if let initialLocation = selectedLocation {
            let initialCoordinate = initialLocation.coordinate
            let annotation = MKPointAnnotation()
            annotation.coordinate = initialCoordinate
            mapView?.addAnnotation(annotation)
            selectedLocationAnnotation = annotation

            centerMap(on: initialCoordinate)
        } else if let firstLocation = existingLocations?.first {
            centerMap(on: firstLocation.coordinate)
        }
    }
    
    private func centerMap(on coordinate: CLLocationCoordinate2D) {
        let region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
        mapView?.setRegion(region, animated: true)
    }

    private func setupUI() {
        title = "mapselection-title".localized()
        view.backgroundColor = Theme.shared.backgroundColor

        guard let mapView else { return }
        mapView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mapView)

        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: view.topAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mapView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupNavigationBar() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Done",
            style: .done,
            target: self,
            action: #selector(doneButtonTapped)
        )
    }

    private func setupGestureRecognizer() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleMapTap(_:)))
        mapView?.addGestureRecognizer(tapGesture)
    }
    
    private func displayExistingLocations(_ locations: [CLLocation]) {
        guard let mapView = mapView else { return }
        
        // Add annotations for existing locations
        for (index, location) in locations.enumerated() {
            let annotation = MKPointAnnotation()
            annotation.coordinate = location.coordinate
            annotation.title = "Location \(index + 1)"
            mapView.addAnnotation(annotation)
        }
        
        // Draw route line
        if locations.count >= 2 {
            let coordinates = locations.map { $0.coordinate }
            routeOverlay = MKPolyline(coordinates: coordinates, count: coordinates.count)
            mapView.addOverlay(routeOverlay!)
            
            // Zoom to show all locations
            let region = MKCoordinateRegion(
                coordinates: coordinates,
                latitudinalMeters: 1000,
                longitudinalMeters: 1000
            )
            mapView.setRegion(region, animated: true)
        }
    }

    @objc private func handleMapTap(_ gestureRecognizer: UITapGestureRecognizer) {
        guard let mapView else { return }
        let locationInView = gestureRecognizer.location(in: mapView)
        let coordinate = mapView.convert(locationInView, toCoordinateFrom: mapView)

        if let selectedLocationAnnotation {
            selectedLocationAnnotation.coordinate = coordinate
        } else {
            selectedLocationAnnotation = MKPointAnnotation()
            selectedLocationAnnotation?.coordinate = coordinate
            selectedLocationAnnotation?.title = "New Location"
            mapView.addAnnotation(selectedLocationAnnotation!)
        }
    }

    @objc private func doneButtonTapped() {
        if let selectedLocationCoordinate = selectedLocationAnnotation?.coordinate {
            let selectedLocation = CLLocation(latitude: selectedLocationCoordinate.latitude, longitude: selectedLocationCoordinate.longitude)
            delegate?.didSelectLocation(selectedLocation)
        }
        navigationController?.popViewController(animated: true)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent {
            selectedLocationAnnotation.map { mapView?.removeAnnotation($0) }
        }
    }
}

// MARK: - MKMapViewDelegate
extension MapSelectionViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        let identifier = "LocationPin"
        
        var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
        if annotationView == nil {
            annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
        }
        
        if annotation === selectedLocationAnnotation {
            // New location being added
            (annotationView as? MKMarkerAnnotationView)?.markerTintColor = .systemRed
        } else {
            // Existing route locations
            (annotationView as? MKMarkerAnnotationView)?.markerTintColor = .systemBlue
        }
        
        annotationView?.canShowCallout = true
        return annotationView
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let polyline = overlay as? MKPolyline {
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = .systemBlue
            renderer.lineWidth = 3
            return renderer
        }
        return MKOverlayRenderer()
    }
}

// MARK: - MKCoordinateRegion Extension
private extension MKCoordinateRegion {
    init(coordinates: [CLLocationCoordinate2D], latitudinalMeters: CLLocationDistance, longitudinalMeters: CLLocationDistance) {
        guard !coordinates.isEmpty else {
            self = MKCoordinateRegion()
            return
        }
        
        let minLat = coordinates.map { $0.latitude }.min() ?? 0
        let maxLat = coordinates.map { $0.latitude }.max() ?? 0
        let minLon = coordinates.map { $0.longitude }.min() ?? 0
        let maxLon = coordinates.map { $0.longitude }.max() ?? 0
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.5,
            longitudeDelta: (maxLon - minLon) * 1.5
        )
        
        self.init(center: center, span: span)
    }
}
