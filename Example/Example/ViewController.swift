//
//  ViewController.swift
//  Example
//
//  Created by Matheus Gois on 16/12/23.
//

import UIKit
import MapKit
import CoreLocation

class ViewController: UIViewController {

    @IBOutlet var text: UILabel!
    @IBOutlet var mapView: MKMapView!
    
    private let locationAnnotation = MKPointAnnotation()
    private var hasInitialLocation = false

    override func viewDidLoad() {
        super.viewDidLoad()
        setupMapView()
        setupLocationManager()
        testConsole()
    }
    
    private func setupMapView() {
        mapView.delegate = self
        mapView.showsUserLocation = true
    }
    
    private func setupLocationManager() {
        LocationManager.shared.didUpdate = { [weak self] value in
            self?.text.text = value
        }
        
        LocationManager.shared.didUpdateLocation = { [weak self] location in
            self?.updateMap(with: location)
        }
    }
    
    private func updateMap(with location: CLLocation) {
        // Update annotation position
        locationAnnotation.coordinate = location.coordinate
        locationAnnotation.title = "Current Location"
        
        if !hasInitialLocation {
            mapView.addAnnotation(locationAnnotation)
            hasInitialLocation = true
        }
    }

    func testConsole() {
        NSLog("NSLog \(#function)")
        print("print \(#function)")
    }

    @IBAction func successMocked() {
        let random: Int = .random(in: 1...5)
        let url = "https://reqres.in/api/users?page=\(random)"
        RequestManager.mockRequest(url: url)
    }

    @IBAction func failureRequest() {
        let url = "https://reqres.in/api/users/23"
        RequestManager.mockRequest(url: url)
    }

    @IBAction func seeLocation() {
        LocationManager.shared.requestLocation()
    }

    @IBAction func crash() {
        // Signal
//        var index: Int?
//        print(index!)

        // Exception
        let array = NSArray()
        let element = array.object(at: 4)

        DispatchQueue.global().async {
            // Exception
//            let array = NSArray()
//            let element = array.object(at: 4)
        }
    }

    @IBAction func createLeak() {
        present(LeakViewController(), animated: true)
    }
}

// MARK: - MKMapViewDelegate
extension ViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation {
            return nil
        }
        
        let identifier = "LocationPin"
        var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
        
        if annotationView == nil {
            annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            annotationView?.canShowCallout = true
            annotationView?.markerTintColor = .systemBlue
        } else {
            annotationView?.annotation = annotation
        }
        
        return annotationView
    }
}

extension Thread {
    var threadName: String {
        if isMainThread {
            return "main"
        } else if let threadName = Thread.current.name, !threadName.isEmpty {
            return threadName
        } else {
            return description
        }
    }

    var queueName: String {
        if let queueName = String(validatingUTF8: __dispatch_queue_get_label(nil)) {
            return queueName
        } else if let operationQueueName = OperationQueue.current?.name, !operationQueueName.isEmpty {
            return operationQueueName
        } else if let dispatchQueueName = OperationQueue.current?.underlyingQueue?.label, !dispatchQueueName.isEmpty {
            return dispatchQueueName
        } else {
            return "n/a"
        }
    }
}
