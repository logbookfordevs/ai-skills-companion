import AppKit

@MainActor
final class PopoverViewController: NSViewController {
    private let officialViewController: OfficialTabViewController
    private let installedViewController: InstalledTabViewController
    private let customViewController: CustomTabViewController
    private let segmentedControl = NSSegmentedControl(labels: ["Hub", "Per Agent", "Global"], trackingMode: .selectOne, target: nil, action: nil)
    private let contentContainer = NSView()
    private var currentViewController: NSViewController?

    init(
        cliService: SkillsCLIService,
        installedCatalog: InstalledSkillsCatalogService,
        customCatalog: CustomSkillsCatalogService
    ) {
        officialViewController = OfficialTabViewController(cliService: cliService)
        installedViewController = InstalledTabViewController(cliService: cliService, catalogService: installedCatalog)
        customViewController = CustomTabViewController(catalogService: customCatalog)
        super.init(nibName: nil, bundle: nil)

        officialViewController.onInstallComplete = { [weak installedViewController] in
            installedViewController?.reloadContent()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        preferredContentSize = NSSize(width: 940, height: 720)

        view = NSView()

        let titleLabel = NSTextField(labelWithString: "AI Skills Companion")
        titleLabel.font = .systemFont(ofSize: 18, weight: .bold)

        let subtitleLabel = makeBodyLabel("Switch between official CLI search, skills organized per agent, and the skills stored in `~/.agents/skills`.")
        subtitleLabel.textColor = .secondaryLabelColor

        segmentedControl.segmentStyle = .capsule
        segmentedControl.selectedSegment = 0
        segmentedControl.target = self
        segmentedControl.action = #selector(tabChanged)

        contentContainer.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [titleLabel, subtitleLabel, segmentedControl, contentContainer])
        stack.orientation = .vertical
        stack.spacing = 12
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),
            contentContainer.widthAnchor.constraint(equalTo: stack.widthAnchor),
            contentContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 620)
        ])

        display(viewController: officialViewController)
    }

    @objc private func tabChanged() {
        switch segmentedControl.selectedSegment {
        case 1:
            display(viewController: installedViewController)
        case 2:
            display(viewController: customViewController)
        default:
            display(viewController: officialViewController)
        }
    }

    private func display(viewController: NSViewController) {
        currentViewController?.view.removeFromSuperview()
        currentViewController?.removeFromParent()

        addChild(viewController)
        viewController.view.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(viewController.view)
        NSLayoutConstraint.activate([
            viewController.view.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            viewController.view.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            viewController.view.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            viewController.view.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor)
        ])
        currentViewController = viewController
    }
}
