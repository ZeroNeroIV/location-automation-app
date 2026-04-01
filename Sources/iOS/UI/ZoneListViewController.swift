// iOS/UI/ZoneListViewController.swift
import UIKit

/// ZoneListViewController displays a list of all zones with name, profile name, and active indicator.
/// Supports swipe-to-delete and tap-to-edit interactions.
public final class ZoneListViewController: UITableViewController {
    
    // MARK: - UI Components
    
    private lazy var emptyStateView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 16
        
        let imageView = UIImageView(image: UIImage(systemName: "map.fill"))
        imageView.tintColor = .systemGray3
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: 60),
            imageView.heightAnchor.constraint(equalToConstant: 60)
        ])
        
        let titleLabel = UILabel()
        titleLabel.text = "No Zones"
        titleLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        titleLabel.textColor = .label
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = "Tap + to create your first zone"
        subtitleLabel.font = .systemFont(ofSize: 15)
        subtitleLabel.textColor = .secondaryLabel
        
        stackView.addArrangedSubview(imageView)
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(subtitleLabel)
        
        view.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        return view
    }()
    
    // MARK: - Properties
    
    private let database = DatabaseManager.shared
    private let logger = Logger.shared
    private let detectionManager = DetectionPriorityManager.shared
    
    private var zones: [Zone] = []
    private var profileCache: [UUID: Profile] = [:]
    
    // MARK: - Reuse Identifiers
    
    private let zoneCellIdentifier = "ZoneCell"
    
    // MARK: - Lifecycle
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupTableView()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadData()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        title = "Zones"
        view.backgroundColor = .systemBackground
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(addZoneTapped)
        )
    }
    
    private func setupTableView() {
        tableView.register(ZoneTableViewCell.self, forCellReuseIdentifier: zoneCellIdentifier)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 72
    }
    
    // MARK: - Data Loading
    
    private func loadData() {
        do {
            zones = try database.getAllZones()
            loadProfiles()
            updateEmptyState()
            tableView.reloadData()
            logger.info("Loaded \(zones.count) zones")
        } catch {
            logger.error("Failed to load zones: \(error.localizedDescription)")
            showError(error.localizedDescription)
        }
    }
    
    private func loadProfiles() {
        profileCache.removeAll()
        do {
            let profiles = try database.getAllProfiles()
            for profile in profiles {
                profileCache[profile.id] = profile
            }
        } catch {
            logger.warning("Failed to load profiles: \(error.localizedDescription)")
        }
    }
    
    private func updateEmptyState() {
        if zones.isEmpty {
            tableView.backgroundView = emptyStateView
            tableView.separatorStyle = .none
        } else {
            tableView.backgroundView = nil
            tableView.separatorStyle = .singleLine
        }
    }
    
    // MARK: - Actions
    
    @objc private func addZoneTapped() {
        if let mapVC = navigationController?.viewControllers.first(where: { $0 is MapViewController }) {
            navigationController?.popToViewController(mapVC, animated: true)
        } else {
            let mapVC = MapViewController()
            navigationController?.pushViewController(mapVC, animated: true)
        }
    }
    
    private func editZone(_ zone: Zone) {
        let alert = UIAlertController(title: "Edit Zone", message: "Enter new name for zone", preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.text = zone.name
            textField.placeholder = "Zone name"
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let newName = alert.textFields?.first?.text, !newName.isEmpty else { return }
            self?.updateZone(zone, withName: newName)
        })
        
        present(alert, animated: true)
    }
    
    private func updateZone(_ zone: Zone, withName name: String) {
        var updatedZone = zone
        updatedZone.name = name
        
        do {
            try database.updateZone(updatedZone)
            logger.info("Updated zone: \(name)")
            loadData()
        } catch {
            logger.error("Failed to update zone: \(error.localizedDescription)")
            showError(error.localizedDescription)
        }
    }
    
    private func deleteZone(_ zone: Zone) {
        do {
            try database.deleteZone(id: zone.id)
            logger.info("Deleted zone: \(zone.name)")
            loadData()
        } catch {
            logger.error("Failed to delete zone: \(error.localizedDescription)")
            showError(error.localizedDescription)
        }
    }
    
    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Helpers
    
    private func profileName(for zone: Zone) -> String {
        if let profile = profileCache[zone.profileId] {
            return profile.name
        }
        return "Unknown"
    }
    
    private func isZoneActive(_ zone: Zone) -> Bool {
        return detectionManager.activeZone?.zone.id == zone.id
    }
}

// MARK: - UITableViewDataSource

extension ZoneListViewController {
    
    public override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return zones.count
    }
    
    public override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: zoneCellIdentifier, for: indexPath) as? ZoneTableViewCell else {
            return UITableViewCell()
        }
        
        let zone = zones[indexPath.row]
        let profileName = self.profileName(for: zone)
        let isActive = isZoneActive(zone)
        
        cell.configure(name: zone.name, profileName: profileName, isActive: isActive)
        
        return cell
    }
}

// MARK: - UITableViewDelegate

extension ZoneListViewController {
    
    public override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let zone = zones[indexPath.row]
        editZone(zone)
    }
    
    public override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let zone = zones[indexPath.row]
        
        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, completion in
            self?.confirmDelete(zone)
            completion(true)
        }
        deleteAction.image = UIImage(systemName: "trash")
        
        return UISwipeActionsConfiguration(actions: [deleteAction])
    }
    
    private func confirmDelete(_ zone: Zone) {
        let alert = UIAlertController(
            title: "Delete Zone",
            message: "Are you sure you want to delete \"\(zone.name)\"?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.deleteZone(zone)
        })
        
        present(alert, animated: true)
    }
}

// MARK: - ZoneTableViewCell

final class ZoneTableViewCell: UITableViewCell {
    
    // MARK: - UI Components
    
    private let containerStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 4
        return stack
    }()
    
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 17, weight: .medium)
        label.textColor = .label
        return label
    }()
    
    private let profileLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        return label
    }()
    
    private let activeIndicator: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .systemGreen
        view.layer.cornerRadius = 5
        return view
    }()
    
    private let activeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .systemGreen
        label.text = "ACTIVE"
        return label
    }()
    
    // MARK: - Initialization
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        accessoryType = .disclosureIndicator
        
        contentView.addSubview(activeIndicator)
        contentView.addSubview(containerStack)
        contentView.addSubview(activeLabel)
        
        containerStack.addArrangedSubview(nameLabel)
        containerStack.addArrangedSubview(profileLabel)
        
        NSLayoutConstraint.activate([
            activeIndicator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            activeIndicator.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            activeIndicator.widthAnchor.constraint(equalToConstant: 10),
            activeIndicator.heightAnchor.constraint(equalToConstant: 10),
            
            containerStack.leadingAnchor.constraint(equalTo: activeIndicator.trailingAnchor, constant: 12),
            containerStack.trailingAnchor.constraint(equalTo: activeLabel.leadingAnchor, constant: -8),
            containerStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            containerStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            
            activeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            activeLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }
    
    // MARK: - Configuration
    
    func configure(name: String, profileName: String, isActive: Bool) {
        nameLabel.text = name
        profileLabel.text = "Profile: \(profileName)"
        
        activeIndicator.isHidden = !isActive
        activeLabel.isHidden = !isActive
        
        if isActive {
            activeIndicator.backgroundColor = .systemGreen
            activeLabel.textColor = .systemGreen
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        nameLabel.text = nil
        profileLabel.text = nil
        activeIndicator.isHidden = true
        activeLabel.isHidden = true
    }
}
