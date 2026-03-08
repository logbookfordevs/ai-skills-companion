import AppKit

@MainActor
final class CustomTabViewController: NSViewController, NSSearchFieldDelegate {
    private struct CategoryFilterOption {
        let id: String?
        let title: String
    }

    private let catalogService: CustomSkillsCatalogService
    private let searchField = NSSearchField()
    private let bannerContainer = NSView()
    private let categoryFiltersContainer = NSView()
    private let categoryFiltersStack = NSStackView()
    private let rowsScrollView = NSScrollView()
    private let rowsStack = NSStackView()
    private let statusLabel = makeSecondaryLabel("")
    private var catalogSnapshot = CustomSkillsCatalogSnapshot(skills: [], categorizationState: .missing)
    private var allSkills: [CustomSkillRecord] = []
    private var filteredSkills: [CustomSkillRecord] = []
    private var currentCategoryFilterOptions: [CategoryFilterOption] = []
    private var selectedCategoryID: String?
    private var categorizationHelpWindowController: CategorizationHelpWindowController?
    private var transientStatusMessage: String?

    init(catalogService: CustomSkillsCatalogService) {
        self.catalogService = catalogService
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false

        let descriptionLabel = makeBodyLabel("Browse every skill under `~/.agents/skills`, and search by name plus description so you can find the right skill faster.")
        descriptionLabel.textColor = .secondaryLabelColor
        descriptionLabel.alignment = .center

        searchField.placeholderString = "Search local skills by name or description"
        searchField.delegate = self

        let refreshButton = makeActionButton("Refresh", target: self, action: #selector(refresh))

        let controls = NSStackView(views: [searchField, refreshButton])
        controls.orientation = .horizontal
        controls.spacing = 8
        controls.alignment = .centerY

        bannerContainer.translatesAutoresizingMaskIntoConstraints = false
        categoryFiltersContainer.translatesAutoresizingMaskIntoConstraints = false

        let categoryFiltersScrollView = NSScrollView()
        categoryFiltersScrollView.borderType = .noBorder
        categoryFiltersScrollView.hasHorizontalScroller = false
        categoryFiltersScrollView.hasVerticalScroller = false
        categoryFiltersScrollView.horizontalScrollElasticity = .allowed
        categoryFiltersScrollView.scrollerStyle = .overlay
        categoryFiltersScrollView.drawsBackground = false
        categoryFiltersScrollView.translatesAutoresizingMaskIntoConstraints = false

        let categoryFiltersContentView = FlippedContentView()
        categoryFiltersContentView.translatesAutoresizingMaskIntoConstraints = false
        categoryFiltersScrollView.documentView = categoryFiltersContentView

        categoryFiltersStack.orientation = .horizontal
        categoryFiltersStack.spacing = 8
        categoryFiltersStack.alignment = .centerY
        categoryFiltersStack.translatesAutoresizingMaskIntoConstraints = false
        categoryFiltersContentView.addSubview(categoryFiltersStack)

        categoryFiltersContainer.addSubview(categoryFiltersScrollView)
        NSLayoutConstraint.activate([
            categoryFiltersScrollView.leadingAnchor.constraint(equalTo: categoryFiltersContainer.leadingAnchor),
            categoryFiltersScrollView.trailingAnchor.constraint(equalTo: categoryFiltersContainer.trailingAnchor),
            categoryFiltersScrollView.topAnchor.constraint(equalTo: categoryFiltersContainer.topAnchor),
            categoryFiltersScrollView.bottomAnchor.constraint(equalTo: categoryFiltersContainer.bottomAnchor),
            categoryFiltersScrollView.heightAnchor.constraint(equalToConstant: 36),

            categoryFiltersStack.leadingAnchor.constraint(equalTo: categoryFiltersContentView.leadingAnchor, constant: 4),
            categoryFiltersStack.topAnchor.constraint(equalTo: categoryFiltersContentView.topAnchor),
            categoryFiltersStack.bottomAnchor.constraint(equalTo: categoryFiltersContentView.bottomAnchor),
            categoryFiltersStack.trailingAnchor.constraint(equalTo: categoryFiltersContentView.trailingAnchor, constant: -4),
            categoryFiltersContentView.heightAnchor.constraint(equalTo: categoryFiltersScrollView.contentView.heightAnchor)
        ])

        let rowsColumn = makeScrollableColumn(minHeight: 420, scrollView: rowsScrollView)
        let scrollView = rowsColumn.scrollView
        rowsStack.orientation = .vertical
        rowsStack.spacing = 20
        rowsStack.alignment = .width
        rowsColumn.contentView.addSubview(rowsStack)
        rowsStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            rowsStack.leadingAnchor.constraint(equalTo: rowsColumn.contentView.leadingAnchor, constant: 12),
            rowsStack.trailingAnchor.constraint(equalTo: rowsColumn.contentView.trailingAnchor, constant: -12),
            rowsStack.topAnchor.constraint(equalTo: rowsColumn.contentView.topAnchor, constant: 12),
            rowsStack.bottomAnchor.constraint(equalTo: rowsColumn.contentView.bottomAnchor, constant: -12)
        ])

        statusLabel.alignment = .right

        let stack = NSStackView(views: [descriptionLabel, bannerContainer, controls, categoryFiltersContainer, statusLabel, scrollView])
        stack.orientation = .vertical
        stack.spacing = 12
        stack.alignment = .width
        stack.translatesAutoresizingMaskIntoConstraints = false

        stack.arrangedSubviews.forEach {
            stack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        addFullWidthArrangedSubview(descriptionLabel, to: stack)
        addFullWidthArrangedSubview(bannerContainer, to: stack)
        addFullWidthArrangedSubview(controls, to: stack)
        addFullWidthArrangedSubview(categoryFiltersContainer, to: stack)
        addFullWidthArrangedSubview(statusLabel, to: stack)
        addFullWidthArrangedSubview(scrollView, to: stack)

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
            searchField.widthAnchor.constraint(greaterThanOrEqualToConstant: 260)
        ])

        refresh()
    }

    func controlTextDidChange(_ obj: Notification) {
        transientStatusMessage = nil
        applyFilter()
    }

    @objc private func refresh() {
        reloadData()
    }

    private func reloadData(preserveTransientStatus: Bool = false) {
        if !preserveTransientStatus {
            transientStatusMessage = nil
        }
        catalogSnapshot = catalogService.loadSnapshot()
        allSkills = catalogSnapshot.skills
        ensureValidSelectedCategory()
        applyFilter()
    }

    @objc private func copySkillName(_ sender: NSButton) {
        guard sender.tag >= 0, sender.tag < filteredSkills.count else { return }
        copyToPasteboard(filteredSkills[sender.tag].name)
    }

    @objc private func openSkillFile(_ sender: NSButton) {
        guard sender.tag >= 0, sender.tag < filteredSkills.count else { return }
        NSWorkspace.shared.open(filteredSkills[sender.tag].skillFileURL)
    }

    @objc private func openSkillFolder(_ sender: NSButton) {
        guard sender.tag >= 0, sender.tag < filteredSkills.count else { return }
        NSWorkspace.shared.activateFileViewerSelecting([filteredSkills[sender.tag].folderURL])
    }

    @objc private func toggleSkillEnabled(_ sender: NSSwitch) {
        guard sender.tag >= 0, sender.tag < filteredSkills.count else { return }
        let skill = filteredSkills[sender.tag]
        let shouldEnable = sender.state == .on

        do {
            try catalogService.setSkill(skill, enabled: shouldEnable)
            transientStatusMessage = shouldEnable
                ? "Enabled `\(skill.name)` and moved it back into `~/.agents/skills`."
                : "Disabled `\(skill.name)` and moved it into `~/.agents/skills/.disabled`."
            reloadData(preserveTransientStatus: true)
        } catch {
            sender.state = shouldEnable ? .off : .on
            transientStatusMessage = error.localizedDescription
            applyFilter()
        }
    }

    @objc private func trashSkill(_ sender: NSButton) {
        guard sender.tag >= 0, sender.tag < filteredSkills.count else { return }
        let skill = filteredSkills[sender.tag]

        let alert = NSAlert()
        alert.messageText = "Move skill to Trash?"
        alert.informativeText = "This will move `\(skill.name)` to the macOS Trash. You can recover it from Trash later."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Move to Trash")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        do {
            try catalogService.trashSkill(skill)
            transientStatusMessage = "Moved `\(skill.name)` to the Trash."
            reloadData(preserveTransientStatus: true)
        } catch {
            transientStatusMessage = error.localizedDescription
            applyFilter()
        }
    }

    private func applyFilter() {
        let categoryFilteredSkills = skillsMatchingSelectedCategory(allSkills)
        filteredSkills = catalogService.filter(skills: categoryFilteredSkills, query: searchField.stringValue)
        renderBanner()
        renderCategoryFilters()
        updateStatusLabel()
        renderRows()
    }

    private func updateStatusLabel() {
        if let transientStatusMessage, !transientStatusMessage.isEmpty {
            statusLabel.stringValue = transientStatusMessage
            return
        }

        let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        if filteredSkills.isEmpty {
            if query.isEmpty {
                statusLabel.stringValue = "No local skills found in ~/.agents/skills."
            } else {
                statusLabel.stringValue = "No local skills matched `\(query)`."
            }
            return
        }

        switch catalogSnapshot.categorizationState {
        case .loaded:
            let visibleSections = catalogService.buildSections(
                skills: filteredSkills,
                categorizationState: catalogSnapshot.categorizationState
            )
            if let selectedCategoryID,
               let selectedOption = categoryFilterOptions().first(where: { $0.id == selectedCategoryID }) {
                statusLabel.stringValue = "Showing \(filteredSkills.count) local skill(s) in \(selectedOption.title)."
            } else {
                statusLabel.stringValue = "Showing \(filteredSkills.count) local skill(s) in \(visibleSections.count) categor\(visibleSections.count == 1 ? "y" : "ies")."
            }
        case .missing, .invalid:
            statusLabel.stringValue = "Loaded \(filteredSkills.count) local skill(s)."
        }
    }

    private func renderBanner() {
        bannerContainer.subviews.forEach { $0.removeFromSuperview() }

        let bannerView: NSView?
        switch catalogSnapshot.categorizationState {
        case .missing:
            bannerView = ActionBannerView(
                title: "Organize your skills by category",
                message: "Add `skills.json` to `~/.agents/skills` to group local skills into sections like Frontend, Docs, and Review.",
                buttonTitle: "Categorize",
                target: self,
                action: #selector(showCategorizationHelp),
                tone: .highlight
            )
        case .invalid(let message):
            bannerView = ActionBannerView(
                title: "skills.json couldn’t be read",
                message: "Showing the flat list for now. \(message)",
                buttonTitle: "Categorize",
                target: self,
                action: #selector(showCategorizationHelp),
                tone: .caution
            )
        case .loaded:
            bannerView = nil
        }

        guard let bannerView else {
            bannerContainer.isHidden = true
            return
        }

        bannerContainer.isHidden = false
        bannerContainer.addSubview(bannerView)
        NSLayoutConstraint.activate([
            bannerView.leadingAnchor.constraint(equalTo: bannerContainer.leadingAnchor),
            bannerView.trailingAnchor.constraint(equalTo: bannerContainer.trailingAnchor),
            bannerView.topAnchor.constraint(equalTo: bannerContainer.topAnchor),
            bannerView.bottomAnchor.constraint(equalTo: bannerContainer.bottomAnchor)
        ])
    }

    @objc private func selectCategoryFilter(_ sender: NSButton) {
        guard sender.tag >= 0, sender.tag < currentCategoryFilterOptions.count else { return }
        selectedCategoryID = currentCategoryFilterOptions[sender.tag].id
        transientStatusMessage = nil
        applyFilter()
        resetResultsScrollPosition()
    }

    @objc private func showCategorizationHelp() {
        let controller = CategorizationHelpWindowController(
            templateJSON: SkillCatalogDefinition.templateJSON
        ) { [weak self] in
            guard let self else { return }
            copyToPasteboard(SkillCatalogDefinition.templateJSON)
            self.statusLabel.stringValue = "Copied skills.json template to the clipboard."
        }
        categorizationHelpWindowController = controller
        controller.showWindow(nil)
        controller.window?.center()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func renderCategoryFilters() {
        categoryFiltersStack.arrangedSubviews.forEach {
            categoryFiltersStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        let options = categoryFilterOptions()
        currentCategoryFilterOptions = options
        guard options.count > 1 else {
            categoryFiltersContainer.isHidden = true
            return
        }

        categoryFiltersContainer.isHidden = false
        for (index, option) in options.enumerated() {
            let button = makeFilterChipButton(
                option.title,
                target: self,
                action: #selector(selectCategoryFilter(_:)),
                isSelected: selectedCategoryID == option.id
            )
            button.tag = index
            categoryFiltersStack.addArrangedSubview(button)
        }
    }

    private func renderRows() {
        rowsStack.arrangedSubviews.forEach {
            rowsStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        guard !filteredSkills.isEmpty else {
            addFullWidthArrangedSubview(
                EmptyStateView(
                    title: "Local skills",
                    message: "This tab is ready, but the app could not find any skills under `~/.agents/skills` yet."
                ),
                to: rowsStack
            )
            return
        }

        if case .loaded = catalogSnapshot.categorizationState {
            renderCategorizedRows()
            return
        }

        renderFlatRows(filteredSkills)
    }

    private func renderCategorizedRows() {
        let sections = catalogService.buildSections(
            skills: filteredSkills,
            categorizationState: catalogSnapshot.categorizationState
        )
        guard !sections.isEmpty else {
            renderFlatRows(filteredSkills)
            return
        }

        for sectionModel in sections {
            let section = makeCategorySectionContainer(
                title: sectionModel.title,
                subtitle: sectionModel.description,
                countText: "\(sectionModel.skills.count) skill\(sectionModel.skills.count == 1 ? "" : "s")"
            )
            addFullWidthArrangedSubview(section.container, to: rowsStack)
            let cards = sectionModel.skills.map { cardView(for: $0) }
            addCardGridRows(cards, to: section.contentStack)
        }
    }

    private func renderFlatRows(_ skills: [CustomSkillRecord]) {
        var cards: [NSView] = []

        for skill in skills {
            cards.append(cardView(for: skill))
        }

        addCardGridRows(cards, to: rowsStack)
    }

    private func cardView(for skill: CustomSkillRecord) -> NSView {
        let index = filteredSkills.firstIndex(of: skill) ?? 0
        let copyButton = makeActionButton("Copy Name", target: self, action: #selector(copySkillName(_:)))
        copyButton.tag = index
        let fileButton = makeActionButton("Open SKILL.md", target: self, action: #selector(openSkillFile(_:)))
        fileButton.tag = index
        let folderButton = makeActionButton("Open Folder", target: self, action: #selector(openSkillFolder(_:)))
        folderButton.tag = index
        let trashButton = makeIconActionButton(
            systemSymbolName: "trash",
            accessibilityLabel: "Move skill to Trash",
            target: self,
            action: #selector(trashSkill(_:))
        )
        trashButton.tag = index

        let enabledSwitch = NSSwitch()
        enabledSwitch.controlSize = .small
        enabledSwitch.state = skill.isDisabled ? .off : .on
        enabledSwitch.tag = index
        enabledSwitch.target = self
        enabledSwitch.action = #selector(toggleSkillEnabled(_:))
        enabledSwitch.toolTip = skill.isDisabled ? "Enable skill" : "Disable skill"

        return SkillRowBox(
            title: skill.name,
            subtitle: "",
            body: skill.description,
            actionButtons: [copyButton, fileButton, folderButton],
            headerAccessoryViews: [trashButton, enabledSwitch],
            statusText: skill.isDisabled ? "Disabled" : nil,
            isDimmed: skill.isDisabled
        )
    }

    private func skillsMatchingSelectedCategory(_ skills: [CustomSkillRecord]) -> [CustomSkillRecord] {
        guard let selectedCategoryID else { return skills }
        if selectedCategoryID == "uncategorized" {
            return skills.filter { $0.categoryScopeID == nil }
        }
        return skills.filter { $0.categoryScopeID == selectedCategoryID }
    }

    private func resetResultsScrollPosition() {
        view.layoutSubtreeIfNeeded()
        rowsScrollView.contentView.scroll(to: .zero)
        rowsScrollView.reflectScrolledClipView(rowsScrollView.contentView)
    }

    private func categoryFilterOptions() -> [CategoryFilterOption] {
        guard case .loaded(let definition) = catalogSnapshot.categorizationState else {
            return []
        }

        var options = [CategoryFilterOption(id: nil, title: "All Categories")]
        options.append(contentsOf: definition.scopes.map { scope in
            CategoryFilterOption(id: scope.id, title: scope.label)
        })

        if allSkills.contains(where: { $0.categoryScopeID == nil }) {
            options.append(CategoryFilterOption(id: "uncategorized", title: "Uncategorized"))
        }

        return options
    }

    private func ensureValidSelectedCategory() {
        let validCategoryIDs = Set(categoryFilterOptions().compactMap(\.id))
        guard let selectedCategoryID else { return }
        if !validCategoryIDs.contains(selectedCategoryID) {
            self.selectedCategoryID = nil
        }
    }
}

@MainActor
private final class CategorizationHelpWindowController: NSWindowController {
    private let onCopy: () -> Void

    init(templateJSON: String, onCopy: @escaping () -> Void) {
        self.onCopy = onCopy

        let contentViewController = NSViewController()
        let contentView = NSView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentViewController.view = contentView

        let titleLabel = NSTextField(labelWithString: "Categorize your skills")
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)

        let descriptionLabel = makeBodyLabel(
            "Create `~/.agents/skills/skills.json` and the app will group the Skills tab using the categories you define there."
        )
        descriptionLabel.textColor = .secondaryLabelColor

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.string = templateJSON

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        scrollView.documentView = textView
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.heightAnchor.constraint(equalToConstant: 260).isActive = true

        let copyButton = NSButton(title: "Copy JSON Template", target: nil, action: nil)
        copyButton.bezelStyle = .rounded
        copyButton.controlSize = .regular

        let closeButton = NSButton(title: "Close", target: nil, action: nil)
        closeButton.bezelStyle = .rounded
        closeButton.controlSize = .regular

        let buttonsRow = NSStackView(views: [copyButton, closeButton])
        buttonsRow.orientation = NSUserInterfaceLayoutOrientation.horizontal
        buttonsRow.spacing = 10
        buttonsRow.alignment = NSLayoutConstraint.Attribute.centerY
        buttonsRow.translatesAutoresizingMaskIntoConstraints = false

        let buttonSpacer = NSView()
        buttonSpacer.translatesAutoresizingMaskIntoConstraints = false
        buttonSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        buttonSpacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        buttonsRow.insertArrangedSubview(buttonSpacer, at: 0)

        let stack = NSStackView(views: [titleLabel, descriptionLabel, scrollView, buttonsRow])
        stack.orientation = NSUserInterfaceLayoutOrientation.vertical
        stack.spacing = 14
        stack.alignment = NSLayoutConstraint.Attribute.width
        stack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            contentView.widthAnchor.constraint(equalToConstant: 520),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Categorize your skills"
        window.contentViewController = contentViewController
        window.isReleasedWhenClosed = false

        super.init(window: window)

        copyButton.target = self
        copyButton.action = #selector(copyTemplate)
        closeButton.target = self
        closeButton.action = #selector(closeWindow)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func copyTemplate() {
        onCopy()
    }

    @objc private func closeWindow() {
        close()
    }
}
