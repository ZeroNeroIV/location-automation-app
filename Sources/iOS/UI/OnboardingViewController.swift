import UIKit

public final class OnboardingViewController: UIViewController {
    
    private let pageViewController: UIPageViewController
    private let pages: [OnboardingPageViewController]
    private var pageControl: UIPageControl!
    private var skipButton: UIButton!
    
    private let locationService = iOSLocationService.shared
    private let notificationService = iOSNotificationService.shared
    private let logger = Logger.shared
    
    private var currentPageIndex = 0
    
    public init() {
        self.pageViewController = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal,
            options: nil
        )
        
        let locationPage = OnboardingPageViewController(
            pageIndex: 0,
            title: "Enable Location Access",
            description: "Allow location access to automatically detect when you arrive at or leave your zones.",
            buttonTitle: "Continue",
            showSkip: true,
            systemImageName: "location.fill"
        )
        
        let notificationPage = OnboardingPageViewController(
            pageIndex: 1,
            title: "Enable Notifications",
            description: "Get notified when you enter or exit zones, and receive automation suggestions.",
            buttonTitle: "Continue",
            showSkip: true,
            systemImageName: "bell.fill"
        )
        
        let createZonePage = OnboardingPageViewController(
            pageIndex: 2,
            title: "Create Your First Zone",
            description: "Set up a zone to start automating your phone settings based on your location.",
            buttonTitle: "Get Started",
            showSkip: false,
            systemImageName: "mappin.circle.fill"
        )
        
        self.pages = [locationPage, notificationPage, createZonePage]
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupPageViewController()
        logger.info("OnboardingViewController loaded")
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        pageControl = UIPageControl()
        pageControl.translatesAutoresizingMaskIntoConstraints = false
        pageControl.numberOfPages = pages.count
        pageControl.currentPage = 0
        pageControl.currentPageIndicatorTintColor = .systemBlue
        pageControl.pageIndicatorTintColor = .systemBlue.withAlphaComponent(0.3)
        pageControl.addTarget(self, action: #selector(pageControlChanged(_:)), for: .valueChanged)
        
        skipButton = UIButton(type: .system)
        skipButton.translatesAutoresizingMaskIntoConstraints = false
        skipButton.setTitle("Skip", for: .normal)
        skipButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        skipButton.addTarget(self, action: #selector(skipTapped), for: .touchUpInside)
        
        addChild(pageViewController)
        view.addSubview(pageViewController.view)
        view.addSubview(pageControl)
        view.addSubview(skipButton)
        pageViewController.didMove(toParent: self)
        
        NSLayoutConstraint.activate([
            pageViewController.view.topAnchor.constraint(equalTo: view.topAnchor),
            pageViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pageViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pageViewController.view.bottomAnchor.constraint(equalTo: pageControl.topAnchor, constant: -16),
            
            pageControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pageControl.bottomAnchor.constraint(equalTo: skipButton.topAnchor, constant: -24),
            
            skipButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            skipButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
    }
    
    private func setupPageViewController() {
        pageViewController.dataSource = self
        pageViewController.delegate = self
        
        if let firstPage = pages.first {
            pageViewController.setViewControllers(
                [firstPage],
                direction: .forward,
                animated: false
            )
        }
        
        for page in pages {
            page.delegate = self
        }
    }
    
    @objc private func pageControlChanged(_ sender: UIPageControl) {
        let targetIndex = sender.currentPage
        guard targetIndex != currentPageIndex else { return }
        
        let direction: UIPageViewController.NavigationDirection = targetIndex > currentPageIndex ? .forward : .reverse
        let targetPage = pages[targetIndex]
        
        pageViewController.setViewControllers([targetPage], direction: direction, animated: true)
        currentPageIndex = targetIndex
        updateSkipButtonVisibility()
    }
    
    @objc private func skipTapped() {
        logger.info("User skipped onboarding")
        transitionToMainApp()
    }
    
    private func updateSkipButtonVisibility() {
        let showSkip = pages[currentPageIndex].showSkip
        UIView.animate(withDuration: 0.25) {
            self.skipButton.alpha = showSkip ? 1 : 0
        }
        skipButton.isHidden = !showSkip
    }
    
    private func transitionToMainApp() {
        let mapVC = MapViewController()
        let navController = UINavigationController(rootViewController: mapVC)
        navController.modalPresentationStyle = .fullScreen
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve) {
                window.rootViewController = navController
            }
        }
    }
    
    private func goToNextPage() {
        guard currentPageIndex < pages.count - 1 else { return }
        
        let nextIndex = currentPageIndex + 1
        let nextPage = pages[nextIndex]
        
        pageViewController.setViewControllers([nextPage], direction: .forward, animated: true)
        currentPageIndex = nextIndex
        pageControl.currentPage = nextIndex
        updateSkipButtonVisibility()
    }
    
    private func showPermissionDeniedAlert(for permission: String) {
        let alert = UIAlertController(
            title: "\(permission) Permission Required",
            message: "Please enable \(permission.lowercased()) access in Settings to use this app's features.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Go to Settings", style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Continue Anyway", style: .cancel) { [weak self] _ in
            self?.goToNextPage()
        })
        
        present(alert, animated: true)
    }
}

extension OnboardingViewController: UIPageViewControllerDataSource {
    
    public func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerBefore viewController: UIViewController
    ) -> UIViewController? {
        guard let page = viewController as? OnboardingPageViewController,
              page.pageIndex > 0 else {
            return nil
        }
        return pages[page.pageIndex - 1]
    }
    
    public func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerAfter viewController: UIViewController
    ) -> UIViewController? {
        guard let page = viewController as? OnboardingPageViewController,
              page.pageIndex < pages.count - 1 else {
            return nil
        }
        return pages[page.pageIndex + 1]
    }
}

extension OnboardingViewController: UIPageViewControllerDelegate {
    
    public func pageViewController(
        _ pageViewController: UIPageViewController,
        didFinishAnimating finished: Bool,
        previousViewControllers: [UIViewController],
        transitionCompleted completed: Bool
    ) {
        guard completed,
              let currentVC = pageViewController.viewControllers?.first as? OnboardingPageViewController else {
            return
        }
        
        currentPageIndex = currentVC.pageIndex
        pageControl.currentPage = currentPageIndex
        updateSkipButtonVisibility()
    }
}

protocol OnboardingPageViewControllerDelegate: AnyObject {
    func didTapContinue(on page: OnboardingPageViewController)
}

extension OnboardingViewController: OnboardingPageViewControllerDelegate {
    
    func didTapContinue(on page: OnboardingPageViewController) {
        switch page.pageIndex {
        case 0:
            requestLocationPermission()
        case 1:
            requestNotificationPermission()
        case 2:
            transitionToMainApp()
        default:
            break
        }
    }
    
    private func requestLocationPermission() {
        Task {
            do {
                let granted = try await locationService.requestPermission()
                logger.info("Location permission result: \(granted)")
                
                if granted {
                    goToNextPage()
                } else {
                    showPermissionDeniedAlert(for: "Location")
                }
            } catch {
                logger.error("Location permission error: \(error.localizedDescription)")
                showPermissionDeniedAlert(for: "Location")
            }
        }
    }
    
    private func requestNotificationPermission() {
        Task {
            do {
                let granted = try await notificationService.requestPermission()
                logger.info("Notification permission result: \(granted)")
                
                if granted {
                    goToNextPage()
                } else {
                    showPermissionDeniedAlert(for: "Notifications")
                }
            } catch {
                logger.error("Notification permission error: \(error.localizedDescription)")
                showPermissionDeniedAlert(for: "Notifications")
            }
        }
    }
}

final class OnboardingPageViewController: UIViewController {
    
    let pageIndex: Int
    let showSkip: Bool
    
    weak var delegate: OnboardingPageViewControllerDelegate?
    
    private let titleText: String
    private let descriptionText: String
    private let buttonTitle: String
    private let systemImageName: String
    
    private var illustrationImageView: UIImageView!
    private var titleLabel: UILabel!
    private var descriptionLabel: UILabel!
    private var actionButton: UIButton!
    
    init(
        pageIndex: Int,
        title: String,
        description: String,
        buttonTitle: String,
        showSkip: Bool,
        systemImageName: String
    ) {
        self.pageIndex = pageIndex
        self.titleText = title
        self.descriptionText = description
        self.buttonTitle = buttonTitle
        self.showSkip = showSkip
        self.systemImageName = systemImageName
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        illustrationImageView = UIImageView()
        illustrationImageView.translatesAutoresizingMaskIntoConstraints = false
        illustrationImageView.contentMode = .scaleAspectFit
        illustrationImageView.tintColor = .systemBlue
        
        let config = UIImage.SymbolConfiguration(pointSize: 100, weight: .light)
        illustrationImageView.image = UIImage(systemName: systemImageName, withConfiguration: config)
        
        titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = titleText
        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        
        descriptionLabel = UILabel()
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.text = descriptionText
        descriptionLabel.font = .systemFont(ofSize: 17, weight: .regular)
        descriptionLabel.textAlignment = .center
        descriptionLabel.textColor = .secondaryLabel
        descriptionLabel.numberOfLines = 0
        
        actionButton = UIButton(type: .system)
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        actionButton.setTitle(buttonTitle, for: .normal)
        actionButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        actionButton.backgroundColor = .systemBlue
        actionButton.setTitleColor(.white, for: .normal)
        actionButton.layer.cornerRadius = 12
        actionButton.addTarget(self, action: #selector(actionButtonTapped), for: .touchUpInside)
        
        view.addSubview(illustrationImageView)
        view.addSubview(titleLabel)
        view.addSubview(descriptionLabel)
        view.addSubview(actionButton)
        
        NSLayoutConstraint.activate([
            illustrationImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            illustrationImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -120),
            illustrationImageView.widthAnchor.constraint(equalToConstant: 150),
            illustrationImageView.heightAnchor.constraint(equalToConstant: 150),
            
            titleLabel.topAnchor.constraint(equalTo: illustrationImageView.bottomAnchor, constant: 40),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            descriptionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            descriptionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            
            actionButton.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 40),
            actionButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            actionButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            actionButton.heightAnchor.constraint(equalToConstant: 56)
        ])
    }
    
    @objc private func actionButtonTapped() {
        delegate?.didTapContinue(on: self)
    }
}
