import UIKit

public final class SuggestionViewController: UITableViewController {
    
    private let suggestionGenerator = SuggestionGenerator.shared
    private let approvalManager = SuggestionApprovalManager.shared
    private let logger = Logger.shared
    
    private var suggestions: [Suggestion] = []
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadSuggestions()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadSuggestions()
    }
    
    private func setupUI() {
        title = "Suggestions"
        view.backgroundColor = .systemBackground
        
        tableView.register(SuggestionCell.self, forCellReuseIdentifier: SuggestionCell.reuseIdentifier)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 100
    }
    
    private func loadSuggestions() {
        suggestions = suggestionGenerator.generateAllSuggestions()
        tableView.reloadData()
        logger.info("Loaded \(suggestions.count) pending suggestions")
    }
    
    public override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return suggestions.count
    }
    
    public override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: SuggestionCell.reuseIdentifier, for: indexPath) as? SuggestionCell else {
            return UITableViewCell()
        }
        
        let suggestion = suggestions[indexPath.row]
        cell.configure(with: suggestion)
        
        return cell
    }
    
    public override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    public override func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let approveAction = UIContextualAction(style: .normal, title: "Approve") { [weak self] _, _, completion in
            self?.approveSuggestion(at: indexPath, completion: completion)
        }
        approveAction.backgroundColor = .systemGreen
        approveAction.image = UIImage(systemName: "checkmark.circle.fill")
        
        return UISwipeActionsConfiguration(actions: [approveAction])
    }
    
    public override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let declineAction = UIContextualAction(style: .destructive, title: "Decline") { [weak self] _, _, completion in
            self?.declineSuggestion(at: indexPath, completion: completion)
        }
        declineAction.backgroundColor = .systemRed
        declineAction.image = UIImage(systemName: "xmark.circle.fill")
        
        return UISwipeActionsConfiguration(actions: [declineAction])
    }
    
    private func approveSuggestion(at indexPath: IndexPath, completion: @escaping (Bool) -> Void) {
        guard indexPath.row < suggestions.count else {
            completion(false)
            return
        }
        
        let suggestion = suggestions[indexPath.row]
        let result = approvalManager.approveSuggestion(suggestion)
        
        if result.isSuccess {
            logger.info("Approved suggestion: \(suggestion.id)")
            suggestions.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .automatic)
            completion(true)
        } else {
            logger.error("Failed to approve suggestion: \(result.message)")
            showError("Failed to approve: \(result.message)")
            completion(false)
        }
    }
    
    private func declineSuggestion(at indexPath: IndexPath, completion: @escaping (Bool) -> Void) {
        guard indexPath.row < suggestions.count else {
            completion(false)
            return
        }
        
        let suggestion = suggestions[indexPath.row]
        let result = approvalManager.declineSuggestion(suggestion)
        
        if result.isSuccess {
            logger.info("Declined suggestion: \(suggestion.id)")
            suggestions.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .automatic)
            completion(true)
        } else {
            logger.error("Failed to decline suggestion: \(result.message)")
            showError("Failed to decline: \(result.message)")
            completion(false)
        }
    }
    
    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

final class SuggestionCell: UITableViewCell {
    
    static let reuseIdentifier = "SuggestionCell"
    
    private lazy var typeLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .secondaryLabel
        return label
    }()
    
    private lazy var messageLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.textColor = .label
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var zoneNameLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .tertiaryLabel
        return label
    }()
    
    private lazy var iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .systemBlue
        return imageView
    }()
    
    private lazy var containerStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.spacing = 12
        stack.alignment = .top
        return stack
    }()
    
    private lazy var textStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 4
        return stack
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.addSubview(containerStack)
        
        containerStack.addArrangedSubview(iconImageView)
        containerStack.addArrangedSubview(textStack)
        
        textStack.addArrangedSubview(typeLabel)
        textStack.addArrangedSubview(messageLabel)
        textStack.addArrangedSubview(zoneNameLabel)
        
        NSLayoutConstraint.activate([
            containerStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            containerStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            containerStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            
            iconImageView.widthAnchor.constraint(equalToConstant: 32),
            iconImageView.heightAnchor.constraint(equalToConstant: 32)
        ])
    }
    
    func configure(with suggestion: Suggestion) {
        typeLabel.text = suggestion.type.rawValue.capitalized
        messageLabel.text = suggestion.message
        
        switch suggestion {
        case .profileChange(let profileSuggestion):
            zoneNameLabel.text = "Zone: \(profileSuggestion.zoneName)"
            iconImageView.image = UIImage(systemName: "person.crop.circle.badge.clock")
            iconImageView.tintColor = .systemBlue
        case .zoneCreation(let zoneSuggestion):
            zoneNameLabel.text = "Suggested: \(zoneSuggestion.suggestedName)"
            iconImageView.image = UIImage(systemName: "plus.circle.fill")
            iconImageView.tintColor = .systemGreen
        case .zoneDeletion(let zoneSuggestion):
            zoneNameLabel.text = "Zone: \(zoneSuggestion.zoneName)"
            iconImageView.image = UIImage(systemName: "minus.circle.fill")
            iconImageView.tintColor = .systemRed
        }
    }
}
