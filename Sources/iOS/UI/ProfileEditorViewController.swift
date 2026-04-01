// iOS/UI/ProfileEditorViewController.swift
import UIKit

/// UIKit view controller for editing profiles with grouped table view
final class ProfileEditorViewController: UITableViewController {

    // MARK: - Properties

    private var profile: Profile

    // MARK: - Section/Row Configuration

    private enum Section: Int, CaseIterable {
        case name
        case settings

        var title: String? {
            switch self {
            case .name:
                return "Profile Name"
            case .settings:
                return "Settings"
            }
        }
    }

    private enum SettingsRow: Int, CaseIterable {
        case ringtone
        case vibrate
        case unmute
        case dnd
        case alarms
        case timers

        var title: String {
            switch self {
            case .ringtone:
                return "Ringtone"
            case .vibrate:
                return "Vibrate"
            case .unmute:
                return "Unmute"
            case .dnd:
                return "Do Not Disturb"
            case .alarms:
                return "Alarms"
            case .timers:
                return "Timers"
            }
        }

        var keyPathWritable: WritableKeyPath<Profile, ProfileSetting> {
            switch self {
            case .ringtone:
                return \Profile.ringtone
            case .vibrate:
                return \Profile.vibrate
            case .unmute:
                return \Profile.unmute
            case .dnd:
                return \Profile.dnd
            case .alarms:
                return \Profile.alarms
            case .timers:
                return \Profile.timers
            }
        }
    }

    // MARK: - Initialization

    init(profile: Profile) {
        self.profile = profile
        super.init(style: .grouped)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    // MARK: - UI Setup

    private func setupUI() {
        title = "Edit Profile"
        navigationItem.largeTitleDisplayMode = .never

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelTapped)
        )

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .save,
            target: self,
            action: #selector(saveTapped)
        )

        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
    }

    // MARK: - Actions

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    @objc private func saveTapped() {
        do {
            try profile.validate()
            try DatabaseManager.shared.updateProfile(profile)
            dismiss(animated: true)
        } catch {
            let alert = UIAlertController(
                title: "Error",
                message: error.localizedDescription,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }

    // MARK: - UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sectionType = Section(rawValue: section) else { return 0 }
        switch sectionType {
        case .name:
            return 1
        case .settings:
            return SettingsRow.allCases.count
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return Section(rawValue: section)?.title
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let section = Section(rawValue: indexPath.section) else {
            return UITableViewCell()
        }

        switch section {
        case .name:
            return configureNameCell(at: indexPath)
        case .settings:
            return configureSettingCell(at: indexPath)
        }
    }

    private func configureNameCell(at indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        var config = cell.defaultContentConfiguration()
        config.text = profile.name
        config.textProperties.adjustsFontSizeToFitWidth = true
        cell.contentConfiguration = config
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    private func configureSettingCell(at indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        guard let settingRow = SettingsRow(rawValue: indexPath.row) else {
            return cell
        }

        var config = cell.defaultContentConfiguration()
        config.text = settingRow.title
        cell.contentConfiguration = config

        let toggle = UISwitch()
        toggle.isOn = profile[keyPath: settingRow.keyPathWritable] == .on
        toggle.tag = indexPath.row
        toggle.addTarget(self, action: #selector(settingToggled(_:)), for: .valueChanged)
        cell.accessoryView = toggle
        cell.selectionStyle = .none

        return cell
    }

    @objc private func settingToggled(_ sender: UISwitch) {
        guard let settingRow = SettingsRow(rawValue: sender.tag) else { return }
        let newValue: ProfileSetting = sender.isOn ? .on : .off
        profile[keyPath: settingRow.keyPathWritable] = newValue
    }

    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard let section = Section(rawValue: indexPath.section) else { return }

        if section == .name {
            presentNameEditor()
        }
    }

    private func presentNameEditor() {
        let alert = UIAlertController(
            title: "Edit Profile Name",
            message: nil,
            preferredStyle: .alert
        )

        alert.addTextField { [weak self] textField in
            textField.text = self?.profile.name
            textField.placeholder = "Profile name"
            textField.autocapitalizationType = .words
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let name = alert.textFields?.first?.text, !name.isEmpty else { return }
            self?.profile.name = name
            self?.tableView.reloadRows(at: [IndexPath(row: 0, section: Section.name.rawValue)], with: .automatic)
        })

        present(alert, animated: true)
    }
}
