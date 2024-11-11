//
//  RouteSimulationViewController.swift
//  DebugSwift
//
//  Created by Cline on 14/02/24.
//

import UIKit
import CoreLocation
import MapKit

protocol RouteSimulationDelegate: AnyObject {
    func didUpdateRouteSimulation(_ simulation: RouteSimulation)
}

final class RouteSimulationViewController: BaseController {
    private let tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = Theme.shared.backgroundColor
        return tableView
    }()
    
    private let mapView: MKMapView = {
        let mapView = MKMapView()
        mapView.translatesAutoresizingMaskIntoConstraints = false
        return mapView
    }()
    
    private var simulation: RouteSimulation
    private weak var delegate: RouteSimulationDelegate?
    
    init(simulation: RouteSimulation, delegate: RouteSimulationDelegate?) {
        self.simulation = simulation
        self.delegate = delegate
        super.init()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
        setupConstraints()
        setupTableView()
        setupMapView()
        setupNavigationBar()
    }
    
    private func setup() {
        title = "Route Simulation"
        view.backgroundColor = Theme.shared.backgroundColor
        view.addSubview(mapView)
        view.addSubview(tableView)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mapView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.4),
            
            tableView.topAnchor.constraint(equalTo: mapView.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
    }
    
    private func setupMapView() {
        mapView.delegate = self
        mapView.showsUserLocation = true
        updateMapAnnotations()
    }
    
    private func setupNavigationBar() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: simulation.isSimulating ? "Stop" : "Start",
            style: .plain,
            target: self,
            action: #selector(toggleSimulation)
        )
    }
    
    private func updateMapAnnotations() {
        mapView.removeAnnotations(mapView.annotations)
        mapView.removeOverlays(mapView.overlays)
        
        for (index, location) in simulation.locations.enumerated() {
            let annotation = MKPointAnnotation()
            annotation.coordinate = location.coordinate
            annotation.title = "Location \(index + 1)"
            mapView.addAnnotation(annotation)
        }
        
        if simulation.locations.count >= 2 {
            let coordinates = simulation.locations.map { $0.coordinate }
            let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            mapView.addOverlay(polyline)
            
            let region = MKCoordinateRegion(
                coordinates: coordinates,
                latitudinalMeters: 1000,
                longitudinalMeters: 1000
            )
            mapView.setRegion(region, animated: true)
        }
    }
    
    @objc private func toggleSimulation() {
        simulation.isSimulating.toggle()
        setupNavigationBar()
        delegate?.didUpdateRouteSimulation(simulation)
    }
}

// MARK: - UITableViewDelegate & UITableViewDataSource
extension RouteSimulationViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return RouteSimulation.Speed.allCases.count
        case 1: return simulation.locations.count + 1
        default: return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        
        switch indexPath.section {
        case 0:
            let speed = RouteSimulation.Speed.allCases[indexPath.row]
            cell.textLabel?.text = speed.rawValue
            cell.accessoryType = simulation.speed == speed ? .checkmark : .none
            if speed == .custom {
                cell.detailTextLabel?.text = "\(simulation.customSpeed) m/s"
            }
            
        case 1:
            if indexPath.row < simulation.locations.count {
                let location = simulation.locations[indexPath.row]
                cell.textLabel?.text = "Location \(indexPath.row + 1)"
                cell.detailTextLabel?.text = "\(location.coordinate.latitude), \(location.coordinate.longitude)"
            } else {
                cell.textLabel?.text = "Add Location"
                cell.accessoryType = .disclosureIndicator
            }
            
        default:
            break
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return "Speed"
        case 1: return "Locations"
        default: return nil
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        switch indexPath.section {
        case 0:
            let speed = RouteSimulation.Speed.allCases[indexPath.row]
            simulation.speed = speed
            if speed == .custom {
                showCustomSpeedAlert()
            }
            tableView.reloadSections(IndexSet(integer: 0), with: .automatic)
            delegate?.didUpdateRouteSimulation(simulation)
            
        case 1:
            if indexPath.row == simulation.locations.count {
                let controller = MapSelectionViewController(
                    selectedLocation: nil,
                    existingLocations: simulation.locations,
                    delegate: self
                )
                navigationController?.pushViewController(controller, animated: true)
            }
            
        default:
            break
        }
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return indexPath.section == 1 && indexPath.row < simulation.locations.count
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            simulation.locations.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .automatic)
            updateMapAnnotations()
            delegate?.didUpdateRouteSimulation(simulation)
        }
    }
    
    private func showCustomSpeedAlert() {
        let alert = UIAlertController(
            title: "Custom Speed",
            message: "Enter speed in meters per second",
            preferredStyle: .alert
        )
        
        alert.addTextField { textField in
            textField.keyboardType = .decimalPad
            textField.placeholder = "Speed (m/s)"
            textField.text = "\(self.simulation.customSpeed)"
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            guard let text = alert.textFields?.first?.text,
                  let speed = Double(text) else { return }
            self?.simulation.customSpeed = speed
            self?.tableView.reloadSections(IndexSet(integer: 0), with: .automatic)
            self?.delegate?.didUpdateRouteSimulation(self?.simulation ?? RouteSimulation())
        })
        
        present(alert, animated: true)
    }
}

// MARK: - MKMapViewDelegate
extension RouteSimulationViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let polyline = overlay as? MKPolyline {
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = .systemBlue
            renderer.lineWidth = 3
            return renderer
        }
        return MKOverlayRenderer()
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        let identifier = "LocationPin"
        
        var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
        if annotationView == nil {
            annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
        }
        
        annotationView?.canShowCallout = true
        return annotationView
    }
}

// MARK: - LocationSelectionDelegate
extension RouteSimulationViewController: LocationSelectionDelegate {
    func didSelectLocation(_ location: CLLocation) {
        simulation.locations.append(location)
        tableView.reloadSections(IndexSet(integer: 1), with: .automatic)
        updateMapAnnotations()
        delegate?.didUpdateRouteSimulation(simulation)
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
