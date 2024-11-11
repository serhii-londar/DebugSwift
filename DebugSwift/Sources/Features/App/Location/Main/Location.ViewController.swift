//
//  Location.ViewController.swift
//  DebugSwift
//
//  Created by Matheus Gois on 19/12/23.
//

import CoreLocation
import Foundation
import UIKit

final class LocationViewController: BaseController {
    private let tableView: UITableView = {
        let tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = Theme.shared.backgroundColor
        tableView.separatorColor = .darkGray
        return tableView
    }()

    private var resetButton: UIBarButtonItem? {
        navigationItem.rightBarButtonItem
    }

    private let viewModel = LocationViewModel()

    override init() {
        super.init()
        setup()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTable()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
        updateResetButton()
    }

    func resetLocation() {
        viewModel.resetLocation()
        resetButton?.isEnabled = false
        tableView.reloadData()
    }

    func setupTable() {
        tableView.delegate = self
        tableView.dataSource = self

        tableView.register(
            UITableViewCell.self,
            forCellReuseIdentifier: .cell
        )

        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        addRightBarButton(
            image: .named("clear", default: "clean".localized()),
            tintColor: .red
        ) { [weak self] in
            self?.resetLocation()
        }
    }

    func setup() {
        title = "location-title".localized()
    }
    
    private func updateResetButton() {
        resetButton?.isEnabled = viewModel.customSelected || 
                               viewModel.selectedIndex != -1 || 
                               viewModel.routeSimulation.isSimulating
    }
}

extension LocationViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.numberOfRows
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        1
    }

    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: .cell,
            for: indexPath
        )
        let image = UIImage.named("checkmark.circle")
        
        switch indexPath.row {
        case 0: // Custom Location
            cell.setup(
                title: "custom".localized(),
                subtitle: viewModel.customDescription,
                image: viewModel.customSelected ? image : nil
            )
            
        case 1: // Route Simulation
            cell.setup(
                title: "Route Simulation",
                subtitle: viewModel.routeSimulation.isSimulating ? "Active" : nil,
                image: viewModel.routeSimulation.isSimulating ? image : nil
            )
            
        default: // Preset Locations
            let location = viewModel.locations[indexPath.row - 2]
            cell.setup(
                title: location.title,
                image: indexPath.row == viewModel.selectedIndex ? image : nil
            )
        }
        
        return cell
    }

    func tableView(_: UITableView, heightForRowAt _: IndexPath) -> CGFloat {
        80.0
    }

    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.row {
        case 0: // Custom Location
            let controller = MapSelectionViewController(
                selectedLocation: LocationToolkit.shared.simulatedLocation,
                delegate: self
            )
            navigationController?.pushViewController(controller, animated: true)
            
        case 1: // Route Simulation
            let controller = RouteSimulationViewController(
                simulation: viewModel.routeSimulation,
                delegate: self
            )
            navigationController?.pushViewController(controller, animated: true)
            
        default: // Preset Locations
            viewModel.selectedIndex = indexPath.row
            let location = viewModel.locations[indexPath.row - 2]
            LocationToolkit.shared.simulatedLocation = CLLocation(
                latitude: location.latitude,
                longitude: location.longitude
            )
            resetButton?.isEnabled = true
            tableView.reloadData()
        }
    }
}

extension LocationViewController: LocationSelectionDelegate {
    func didSelectLocation(_ location: CLLocation) {
        LocationToolkit.shared.simulatedLocation = location
        resetButton?.isEnabled = true
        viewModel.selectedIndex = .zero
        tableView.reloadData()
    }
}

extension LocationViewController: RouteSimulationDelegate {
    func didUpdateRouteSimulation(_ simulation: RouteSimulation) {
        viewModel.routeSimulation = simulation
        updateResetButton()
        tableView.reloadData()
    }
}
