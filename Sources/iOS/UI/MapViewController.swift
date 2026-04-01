// iOS/UI/MapViewController.swift
import UIKit
import MapKit

/// MapViewController displays a map with zone pins and allows zone creation/editing.
/// Uses MapKit for iOS map display.
public final class MapViewController: UIViewController {
    
    // MARK: - UI Components
    
    private lazy var mapView: MKMapView = {
        let map = MKMapView()
        map.translatesAutoresizingMaskIntoConstraints = false
        map.delegate = self
        map.showsUserLocation = true
        map.showsCompass = true
        map.showsScale = true
        return map
    }()
    
    private lazy var addZoneButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "plus.circle.fill"), for: .normal)
        button.tintColor = .systemBlue
        button.addTarget(self, action: #selector(addZoneTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var radiusSlider: UISlider = {
        let slider = UISlider()
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.minimumValue = 50
        slider.maximumValue = 500
        slider.value = 100
        slider.addTarget(self, action: #selector(radiusChanged), for: .valueChanged)
        slider.isHidden = true
        return slider
    }()
    
    private lazy var radiusLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Radius: 100m"
        label.textAlignment = .center
        label.isHidden = true
        return label
    }()
    
    // MARK: - Properties
    
    private let database = DatabaseManager.shared
    private let locationService = iOSLocationService.shared
    private let logger = Logger.shared
    
    private var zones: [Zone] = []
    private var selectedZone: Zone?
    private var tempAnnotation: MKPointAnnotation?
    private var tempCircleOverlay: MKCircle?
    private var isCreatingZone = false
    
    // Default radius in meters
    private var currentRadius: Double = 100
    
    // MARK: - Lifecycle
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupGestures()
        loadZones()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadZones()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        title = "Map"
        view.backgroundColor = .systemBackground
        
        view.addSubview(mapView)
        view.addSubview(addZoneButton)
        view.addSubview(radiusSlider)
        view.addSubview(radiusLabel)
        
        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: view.topAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mapView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            addZoneButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            addZoneButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            addZoneButton.widthAnchor.constraint(equalToConstant: 44),
            addZoneButton.heightAnchor.constraint(equalToConstant: 44),
            
            radiusSlider.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            radiusSlider.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            radiusSlider.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -60),
            
            radiusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            radiusLabel.bottomAnchor.constraint(equalTo: radiusSlider.topAnchor, constant: -8)
        ])
    }
    
    private func setupGestures() {
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 0.5
        mapView.addGestureRecognizer(longPress)
    }
    
    // MARK: - Data Loading
    
    private func loadZones() {
        do {
            zones = try database.getAllZones()
            updateMapAnnotations()
            logger.info("Loaded \(zones.count) zones")
        } catch {
            logger.error("Failed to load zones: \(error.localizedDescription)")
        }
    }
    
    private func updateMapAnnotations() {
        mapView.removeAnnotations(mapView.annotations.filter { !($0 is MKUserLocation) })
        mapView.removeOverlays(mapView.overlays)
        
        for zone in zones {
            let annotation = ZoneAnnotation(zone: zone)
            mapView.addAnnotation(annotation)
            
            // Add radius circle
            let circle = MKCircle(center: CLLocationCoordinate2D(latitude: zone.latitude, longitude: zone.longitude), radius: zone.radius)
            mapView.addOverlay(circle)
        }
    }
    
    // MARK: - Actions
    
    @objc private func addZoneTapped() {
        isCreatingZone = true
        showRadiusControls()
        
        let alert = UIAlertController(title: "New Zone", message: "Long press on the map to set zone location", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.cancelZoneCreation()
        })
        present(alert, animated: true)
    }
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard isCreatingZone, gesture.state == .began else { return }
        
        let point = gesture.location(in: mapView)
        let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
        
    // Remove existing temp
    if let temp = tempAnnotation {
            mapView.removeAnnotation(temp)
        }
        if let circle = tempCircleOverlay {
            mapView.removeOverlay(circle)
        }
        
        // Add temp annotation
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        annotation.title = "New Zone"
        mapView.addAnnotation(annotation)
        tempAnnotation = annotation
        
        // Add temp circle
        let circle = MKCircle(center: coordinate, radius: currentRadius)
        mapView.addOverlay(circle)
        tempCircleOverlay = circle
        
        // Show name input
        showNameInputAlert(at: coordinate)
    }
    
    @objc private func radiusChanged(_ slider: UISlider) {
        currentRadius = Double(slider.value)
        radiusLabel.text = "Radius: \(Int(currentRadius))m"
        
        // Update temp circle
        if let temp = tempAnnotation {
            if let circle = tempCircleOverlay {
                mapView.removeOverlay(circle)
            }
            let newCircle = MKCircle(center: temp.coordinate, radius: currentRadius)
            mapView.addOverlay(newCircle)
            tempCircleOverlay = newCircle
        }
    }
    
    private func showRadiusControls() {
        radiusSlider.isHidden = false
        radiusLabel.isHidden = false
        radiusSlider.value = Float(currentRadius)
    }
    
    private func hideRadiusControls() {
        radiusSlider.isHidden = true
        radiusLabel.isHidden = true
    }
    
    private func showNameInputAlert(at coordinate: CLLocationCoordinate2D) {
        let alert = UIAlertController(title: "Zone Name", message: "Enter a name for this zone", preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "Zone name"
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.cancelZoneCreation()
        })
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let name = alert.textFields?.first?.text, !name.isEmpty else { return }
            self?.saveNewZone(name: name, at: coordinate)
        })
        present(alert, animated: true)
    }
    
    private func saveNewZone(name: String, at coordinate: CLLocationCoordinate2D) {
        do {
            // Create default profile first
            let profile = Profile(
                id: UUID(),
                name: "\(name) Profile",
                ringtone: .on,
                vibrate: .off,
                unmute: .off,
                dnd: .off,
                alarms: .on,
                timers: .on
            )
            try database.createProfile(profile)
            
            // Create zone
            let zone = try Zone(
                name: name,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                radius: currentRadius,
                detectionMethods: [.gps],
                profileId: profile.id
            )
            try database.createZone(zone)
            
            logger.info("Created new zone: \(name) at \(coordinate.latitude),\(coordinate.longitude)")
            
            // Reset creation state
            cancelZoneCreation()
            loadZones()
            
        } catch {
            logger.error("Failed to save zone: \(error.localizedDescription)")
            showError(error.localizedDescription)
        }
    }
    
    private func cancelZoneCreation() {
        isCreatingZone = false
        hideRadiusControls()
        
        if let temp = tempAnnotation {
            mapView.removeAnnotation(temp)
            tempAnnotation = nil
        }
        if let circle = tempCircleOverlay {
            mapView.removeOverlay(circle)
            tempCircleOverlay = nil
        }
        
        currentRadius = 100
    }
    
    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - MKMapViewDelegate

extension MapViewController: MKMapViewDelegate {
    
    public func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard let zoneAnnotation = annotation as? ZoneAnnotation else { return nil }
        
        let identifier = "ZonePin"
        var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
        
        if view == nil {
            view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            view?.canShowCallout = true
            view?.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
        } else {
            view?.annotation = annotation
        }
        
        view?.markerTintColor = .systemBlue
        view?.glyphImage = UIImage(systemName: "mappin.circle.fill")
        
        return view
    }
    
    public func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let circle = overlay as? MKCircle {
            let renderer = MKCircleRenderer(circle: circle)
            renderer.fillColor = UIColor.systemBlue.withAlphaComponent(0.1)
            renderer.strokeColor = UIColor.systemBlue
            renderer.lineWidth = 2
            return renderer
        }
        return MKOverlayRenderer(overlay: overlay)
    }
    
    public func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        guard let zoneAnnotation = view.annotation as? ZoneAnnotation else { return }
        
        let zone = zoneAnnotation.zone
        showZoneDetail(zone)
    }
    
    private func showZoneDetail(_ zone: Zone) {
        let alert = UIAlertController(title: zone.name, message: "Radius: \(Int(zone.radius))m", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Edit", style: .default) { [weak self] _ in
            self?.editZone(zone)
        })
        
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.deleteZone(zone)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func editZone(_ zone: Zone) {
        // Show edit UI
        showRadiusControls()
        currentRadius = zone.radius
        radiusSlider.value = Float(zone.radius)
        radiusLabel.text = "Radius: \(Int(zone.radius))m"
        selectedZone = zone
    }
    
    private func deleteZone(_ zone: Zone) {
        let confirm = UIAlertController(title: "Delete Zone", message: "Are you sure you want to delete \(zone.name)?", preferredStyle: .alert)
        
        confirm.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        confirm.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            do {
                try self?.database.deleteZone(id: zone.id)
                self?.loadZones()
            } catch {
                self?.showError(error.localizedDescription)
            }
        })
        
        present(confirm, animated: true)
    }
}

// MARK: - Zone Annotation

final class ZoneAnnotation: NSObject, MKAnnotation {
    let zone: Zone
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: zone.latitude, longitude: zone.longitude)
    }
    
    var title: String? {
        zone.name
    }
    
    var subtitle: String? {
        "Radius: \(Int(zone.radius))m"
    }
    
    init(zone: Zone) {
        self.zone = zone
        super.init()
    }
}
