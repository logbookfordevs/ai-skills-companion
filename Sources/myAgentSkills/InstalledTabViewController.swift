import AppKit

@MainActor
final class InstalledTabViewController: NSViewController, NSSearchFieldDelegate {
    private let cliService: SkillsCLIService
    private let catalogService: InstalledSkillsCatalogService
    private let searchField = NSSearchField()
    private let sourceFilterPopUp = NSPopUpButton()
    private let rowsStack = NSStackView()
    private let statusLabel = makeSecondaryLabel("")
    private let outputComponents = makeCommandOutputView()
    private var allRecords: [InstalledSkillRecord] = []
    private var filteredRecords: [InstalledSkillRecord] = []
    private var committedQuery = ""
    private let sourceFilterTitles = [
        "All Sources",
        "Global",
        "Claude",
        "Codex",
        "Anti-Gravity"
    ]

    init(cliService: SkillsCLIService, catalogService: InstalledSkillsCatalogService) {
        self.cliService = cliService
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

        let descriptionLabel = makeBodyLabel("Browse the skill folders you care about most, organized by agent source: `~/.agents/skills`, Codex, Claude, and Gemini / Antigravity.")
        descriptionLabel.textColor = .secondaryLabelColor
        descriptionLabel.alignment = .left

        searchField.placeholderString = "Filter skills by agent"
        searchField.delegate = self
        sourceFilterTitles.forEach { sourceFilterPopUp.addItem(withTitle: $0) }
        sourceFilterPopUp.selectItem(at: 0)
        sourceFilterPopUp.target = self
        sourceFilterPopUp.action = #selector(sourceFilterChanged)

        let searchButton = makeActionButton("Search", target: self, action: #selector(runSearch))
        let refreshButton = makeActionButton("Refresh", target: self, action: #selector(refresh))
        let checkButton = makeActionButton("Check Updates", target: self, action: #selector(checkUpdates))
        let updateButton = makeActionButton("Update All", target: self, action: #selector(updateAll))

        let controls = NSStackView(views: [searchField, searchButton, sourceFilterPopUp, refreshButton, checkButton, updateButton])
        controls.orientation = .horizontal
        controls.spacing = 8
        controls.alignment = .centerY
        controls.distribution = .fill

        let rowsColumn = makeScrollableColumn(minHeight: 320)
        let scrollView = rowsColumn.scrollView
        let commandOutputSection = CollapsibleSectionView(
            title: "Command Output",
            contentView: outputComponents.container,
            startsExpanded: false
        )
        rowsStack.orientation = .vertical
        rowsStack.spacing = 12
        rowsStack.alignment = .width
        rowsColumn.contentView.addSubview(rowsStack)
        rowsStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            rowsStack.leadingAnchor.constraint(equalTo: rowsColumn.contentView.leadingAnchor, constant: 12),
            rowsStack.trailingAnchor.constraint(equalTo: rowsColumn.contentView.trailingAnchor, constant: -12),
            rowsStack.topAnchor.constraint(equalTo: rowsColumn.contentView.topAnchor, constant: 12),
            rowsStack.bottomAnchor.constraint(equalTo: rowsColumn.contentView.bottomAnchor, constant: -12)
        ])

        statusLabel.alignment = .left

        let content = NSStackView()
        content.orientation = .vertical
        content.spacing = 12
        content.alignment = .width
        content.translatesAutoresizingMaskIntoConstraints = false

        addFullWidthArrangedSubview(descriptionLabel, to: content)
        addFullWidthArrangedSubview(controls, to: content)
        addFullWidthArrangedSubview(statusLabel, to: content)
        addFullWidthArrangedSubview(scrollView, to: content)
        addFullWidthArrangedSubview(commandOutputSection, to: content)

        view.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            content.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            content.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            content.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
            searchField.widthAnchor.constraint(greaterThanOrEqualToConstant: 240)
        ])

        reloadContent()
    }

    func controlTextDidChange(_ obj: Notification) {
        let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.isEmpty, !committedQuery.isEmpty else { return }
        committedQuery = ""
        applyFilter()
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            runSearch()
            return true
        }
        return false
    }

    func reloadContent() {
        allRecords = catalogService.loadSkills()
        applyFilter()
    }

    @objc private func refresh() {
        reloadContent()
    }

    @objc private func runSearch() {
        committedQuery = searchField.stringValue
        applyFilter()
    }

    @objc private func checkUpdates() {
        statusLabel.stringValue = "Running skills check…"
        cliService.check { [weak self] result in
            guard let self else { return }
            self.outputComponents.textView.string = result.combinedOutput
            self.allRecords = InstalledCheckParser.parseStatuses(result.stdout + "\n" + result.stderr, records: self.allRecords)
            self.applyFilter()
            self.statusLabel.stringValue = result.succeeded ? "Update check completed." : "Update check failed."
        }
    }

    @objc private func updateAll() {
        statusLabel.stringValue = "Running skills update…"
        cliService.updateAll { [weak self] result in
            guard let self else { return }
            self.outputComponents.textView.string = result.combinedOutput
            self.statusLabel.stringValue = result.succeeded ? "Update completed." : "Update failed."
            self.reloadContent()
        }
    }

    @objc private func copySkillName(_ sender: NSButton) {
        guard sender.tag >= 0, sender.tag < filteredRecords.count else { return }
        copyToPasteboard(filteredRecords[sender.tag].name)
    }

    @objc private func openSkillFile(_ sender: NSButton) {
        guard sender.tag >= 0, sender.tag < filteredRecords.count else { return }
        if let url = filteredRecords[sender.tag].skillFileURL {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func openSkillFolder(_ sender: NSButton) {
        guard sender.tag >= 0, sender.tag < filteredRecords.count else { return }
        if let url = filteredRecords[sender.tag].folderURL {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    @objc private func sourceFilterChanged() {
        applyFilter()
    }

    private func applyFilter() {
        let sourceFilteredRecords = recordsMatchingSelectedSource(allRecords)
        filteredRecords = catalogService.filter(skills: sourceFilteredRecords, query: committedQuery)
        updateStatusLabel()
        renderRows()
    }

    private func updateStatusLabel() {
        let selectedSource = selectedSourceTitle()
        let searchQuery = committedQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        if allRecords.isEmpty {
            statusLabel.stringValue = "No skills were found in the configured agent folders."
            return
        }

        if filteredRecords.isEmpty {
            if selectedSource == "All Sources" && searchQuery.isEmpty {
                statusLabel.stringValue = "No agent skills were found."
            } else if searchQuery.isEmpty {
                statusLabel.stringValue = "No skills were found for \(selectedSource)."
            } else {
                statusLabel.stringValue = "No skills matched `\(searchQuery)` in \(selectedSource)."
            }
            return
        }

        if selectedSource == "All Sources" {
            statusLabel.stringValue = "Showing \(filteredRecords.count) skill(s) across your agent folders."
        } else {
            statusLabel.stringValue = "Showing \(filteredRecords.count) skill(s) in \(selectedSource)."
        }
    }

    private func recordsMatchingSelectedSource(_ records: [InstalledSkillRecord]) -> [InstalledSkillRecord] {
        guard let selectedTitle = sourceFilterPopUp.selectedItem?.title else {
            return records
        }

        switch selectedTitle {
        case "Global":
            return records.filter { $0.bucket.title == "Global Library" }
        case "Claude":
            return records.filter { $0.bucket.title == "Claude" }
        case "Codex":
            return records.filter { $0.bucket.title == "Codex" }
        case "Anti-Gravity":
            return records.filter { $0.bucket.title == "Gemini / Antigravity" }
        default:
            return records
        }
    }

    private func selectedSourceTitle() -> String {
        sourceFilterPopUp.selectedItem?.title ?? "All Sources"
    }

    private func renderRows() {
        rowsStack.arrangedSubviews.forEach {
            rowsStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        guard !filteredRecords.isEmpty else {
            let selectedSource = selectedSourceTitle()
            let searchQuery = committedQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            let emptyTitle: String
            let emptyMessage: String

            if searchQuery.isEmpty {
                if selectedSource == "All Sources" {
                    emptyTitle = "No skills found"
                    emptyMessage = "Nothing was found in `~/.agents/skills`, `~/.codex/skills`, `~/.claude/skills`, or `~/.gemini/antigravity/skills`."
                } else {
                    emptyTitle = "No \(selectedSource) skills"
                    emptyMessage = "Nothing was found for the \(selectedSource) source with the current filter."
                }
            } else {
                emptyTitle = "No matching skills"
                emptyMessage = "No skills matched `\(searchQuery)` inside \(selectedSource)."
            }

            addFullWidthArrangedSubview(
                EmptyStateView(
                    title: emptyTitle,
                    message: emptyMessage
                ),
                to: rowsStack
            )
            return
        }

        let grouped = Dictionary(grouping: Array(filteredRecords.enumerated()), by: { $0.element.bucket })
        let orderedBuckets = grouped.keys.sorted {
            if $0.order != $1.order {
                return $0.order < $1.order
            }
            return $0.title < $1.title
        }

        for bucket in orderedBuckets {
            let section = makeSectionContainer(title: bucket.title, subtitle: bucket.locationLabel)
            addFullWidthArrangedSubview(section.container, to: rowsStack)
            var cards: [NSView] = []

            for (index, record) in grouped[bucket, default: []] {
                let copyButton = makeActionButton("Copy Name", target: self, action: #selector(copySkillName(_:)))
                copyButton.tag = index
                let fileButton = makeActionButton("Open SKILL.md", target: self, action: #selector(openSkillFile(_:)))
                fileButton.tag = index
                fileButton.isEnabled = record.skillFileURL != nil
                let folderButton = makeActionButton("Open Folder", target: self, action: #selector(openSkillFolder(_:)))
                folderButton.tag = index
                folderButton.isEnabled = record.folderURL != nil

                cards.append(
                    SkillRowBox(
                        title: record.name,
                        subtitle: "",
                        body: record.description,
                        actionButtons: [copyButton, fileButton, folderButton]
                    )
                )
            }

            addCardGridRows(cards, to: section.contentStack)
        }
    }
}
