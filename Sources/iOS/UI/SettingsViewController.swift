import UIKit

final class SettingsViewController: UITableViewController {

    // MARK: - Settings Keys
    private enum SettingsKey {
        static let notificationsEnabled = "notificationsEnabled"
        static let soundEnabled = "soundEnabled"
        static let detectionPriority = "detectionPriority"
        static let debounceTime = "debounceTime"
        static let learningEnabled = "learningEnabled"
    }

    // MARK: - Detection Priority
    enum DetectionPriority: Int, CaseIterable {
        case manual = 0
        case gps = 1
        case wifi = 2
        case bluetooth = 3

        var title: String {
            switch self {
            case .manual: return "Manual"
            case .gps: return "GPS"
            case .wifi: return "WiFi"
            case .bluetooth: return "Bluetooth"
            }
        }
    }

    // MARK: - Section Definitions
    private enum Section: Int, CaseIterable {
        case general = 0
        case detection = 1
        case learning = 2
        case about = 3

        var title: String {
            switch self {
            case .general: return "General"
            case .detection: return "Detection"
            case .learning: return "Learning"
            case .about: return "About"
            }
        }

        var rowCount: Int {
            switch self {
            case .general: return 2
            case .detection: return 2
            case .learning: return 2
            case .about: return 2
            }
        }
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        registerDefaults()
    }

    // MARK: - Setup

    private func setupUI() {
        title = "Settings"
        tableView = UITableView(frame: .zero, style: .grouped)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(doneTapped)
        )
        Logger.shared.log("Settings view loaded", category: .ui)
    }

    private func registerDefaults() {
        let defaults: [String: Any] = [
            SettingsKey.notificationsEnabled: true,
            SettingsKey.soundEnabled: true,
            SettingsKey.detectionPriority: DetectionPriority.manual.rawValue,
            SettingsKey.debounceTime: 5.0,
            SettingsKey.learningEnabled: true
        ]
        UserDefaults.standard.register(defaults: defaults)
    }

    @objc private func doneTapped() {
        dismiss(animated: true)
        Logger.shared.log("Settings dismissed", category: .ui)
    }

    // MARK: - UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sectionType = Section(rawValue: section) else { return 0 }
        return sectionType.rowCount
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let sectionType = Section(rawValue: section) else { return nil }
        return sectionType.title
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.accessoryView = nil
        cell.accessoryType = .none
        cell.textLabel?.text = nil
        cell.selectionStyle = .default

        guard let section = Section(rawValue: indexPath.section) else {
            return cell
        }

        switch section {
        case .general:
            configureGeneralCell(cell, row: indexPath.row)
        case .detection:
            configureDetectionCell(cell, row: indexPath.row)
        case .learning:
            configureLearningCell(cell, row: indexPath.row)
        case .about:
            configureAboutCell(cell, row: indexPath.row)
        }

        return cell
    }

    // MARK: - Cell Configuration

    private func configureGeneralCell(_ cell: UITableViewCell, row: Int) {
        let isEnabled = UserDefaults.standard.bool(forKey: SettingsKey.notificationsEnabled)
        let isSoundEnabled = UserDefaults.standard.bool(forKey: SettingsKey.soundEnabled)

        switch row {
        case 0:
            cell.textLabel?.text = "Notifications"
            let toggle = UISwitch()
            toggle.isOn = isEnabled
            toggle.addTarget(self, action: #selector(notificationsToggled(_:)), for: .valueChanged)
            cell.accessoryView = toggle
            cell.selectionStyle = .none
        case 1:
            cell.textLabel?.text = "Sound"
            let toggle = UISwitch()
            toggle.isOn = isSoundEnabled
            toggle.addTarget(self, action: #selector(soundToggled(_:)), for: .valueChanged)
            cell.accessoryView = toggle
            cell.selectionStyle = .none
        default:
            break
        }
    }

    private func configureDetectionCell(_ cell: UITableViewCell, row: Int) {
        switch row {
        case 0:
            cell.textLabel?.text = "Priority"
            let priority = DetectionPriority(rawValue: UserDefaults.standard.integer(forKey: SettingsKey.detectionPriority)) ?? .manual
            cell.detailTextLabel?.text = priority.title
            cell.accessoryType = .disclosureIndicator
        case 1:
            cell.textLabel?.text = "Debounce Time"
            let debounce = UserDefaults.standard.double(forKey: SettingsKey.debounceTime)
            cell.detailTextLabel?.text = "\(Int(debounce))s"
            cell.accessoryType = .disclosureIndicator
        default:
            break
        }
    }

    private func configureLearningCell(_ cell: UITableViewCell, row: Int) {
        let isLearningEnabled = UserDefaults.standard.bool(forKey: SettingsKey.learningEnabled)

        switch row {
        case 0:
            cell.textLabel?.text = "Enable Learning"
            let toggle = UISwitch()
            toggle.isOn = isLearningEnabled
            toggle.addTarget(self, action: #selector(learningToggled(_:)), for: .valueChanged)
            cell.accessoryView = toggle
            cell.selectionStyle = .none
        case 1:
            cell.textLabel?.text = "Clear Learning Data"
            cell.textLabel?.textColor = .systemRed
        default:
            break
        }
    }

    private func configureAboutCell(_ cell: UITableViewCell, row: Int) {
        switch row {
        case 0:
            cell.textLabel?.text = "Version"
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
            cell.detailTextLabel?.text = version
            cell.selectionStyle = .none
        case 1:
            cell.textLabel?.text = "Privacy Policy"
            cell.accessoryType = .disclosureIndicator
        default:
            break
        }
    }

    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard let section = Section(rawValue: indexPath.section) else { return }

        switch section {
        case .detection:
            handleDetectionSelection(row: indexPath.row)
        case .learning:
            if indexPath.row == 1 {
                clearLearningData()
            }
        case .about:
            if indexPath.row == 1 {
                openPrivacyPolicy()
            }
        default:
            break
        }
    }

    // MARK: - Actions

    @objc private func notificationsToggled(_ sender: UISwitch) {
        UserDefaults.standard.set(sender.isOn, forKey: SettingsKey.notificationsEnabled)
        Logger.shared.log("Notifications toggled: \(sender.isOn)", category: .settings)
    }

    @objc private func soundToggled(_ sender: UISwitch) {
        UserDefaults.standard.set(sender.isOn, forKey: SettingsKey.soundEnabled)
        Logger.shared.log("Sound toggled: \(sender.isOn)", category: .settings)
    }

    @objc private func learningToggled(_ sender: UISwitch) {
        UserDefaults.standard.set(sender.isOn, forKey: SettingsKey.learningEnabled)
        Logger.shared.log("Learning toggled: \(sender.isOn)", category: .settings)
    }

    private func handleDetectionSelection(row: Int) {
        switch row {
        case 0:
            showPriorityPicker()
        case 1:
            showDebounceTimePicker()
        default:
            break
        }
    }

    private func showPriorityPicker() {
        let alert = UIAlertController(title: "Detection Priority", message: nil, preferredStyle: .actionSheet)

        for priority in DetectionPriority.allCases {
            let action = UIAlertAction(title: priority.title, style: .default) { [weak self] _ in
                UserDefaults.standard.set(priority.rawValue, forKey: SettingsKey.detectionPriority)
                self?.tableView.reloadData()
                Logger.shared.log("Detection priority set: \(priority.title)", category: .settings)
            }
            alert.addAction(action)
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func showDebounceTimePicker() {
        let alert = UIAlertController(title: "Debounce Time", message: "Select debounce duration in seconds", preferredStyle: .actionSheet)

        let times: [Double] = [1, 3, 5, 10, 15, 30]
        for time in times {
            let action = UIAlertAction(title: "\(Int(time)) seconds", style: .default) { [weak self] _ in
                UserDefaults.standard.set(time, forKey: SettingsKey.debounceTime)
                self?.tableView.reloadData()
                Logger.shared.log("Debounce time set: \(Int(time))s", category: .settings)
            }
            alert.addAction(action)
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func clearLearningData() {
        let alert = UIAlertController(
            title: "Clear Learning Data",
            message: "This will delete all learned location patterns. This action cannot be undone.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Clear", style: .destructive) { [weak self] _ in
            // Clear learning data from UserDefaults
            let domain = Bundle.main.bundleIdentifier ?? "com.app.location-automation"
            UserDefaults.standard.removePersistentDomain(forName: domain)
            UserDefaults.standard.synchronize()
            self?.tableView.reloadData()
            Logger.shared.log("Learning data cleared", category: .settings)
        })

        present(alert, animated: true)
    }

    private func openPrivacyPolicy() {
        if let url = URL(string: "https://example.com/privacy") {
            UIApplication.shared.open(url)
            Logger.shared.log("Privacy policy opened", category: .ui)
        }
    }
}