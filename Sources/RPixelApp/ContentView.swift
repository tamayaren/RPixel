import SwiftUI
import AppKit
import UniformTypeIdentifiers
import RPixelCore

struct ProcessedItem: Identifiable, Sendable {
    let id = UUID()
    let url: URL
    let result: FixResult
}

struct ContentView: View {
    @State private var isQuickActionInstalled = QuickActionManager.isInstalled
    @State private var isTargeted = false
    @State private var isProcessing = false
    @State private var debugMode = false
    @State private var playSound = true
    @State private var sendNotification = true
    @State private var statusMessage: String? = nil
    @State private var lastProcessedItems: [ProcessedItem] = []
    @State private var selectedPreviewItem: ProcessedItem? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 16)

            Divider()

            ScrollView {
                VStack(spacing: 20) {
                    // Quick Action Status Card
                    quickActionCard

                    // Drop Zone
                    dropZoneView

                    // Options
                    optionsSection

                    // Results & Preview
                    if !lastProcessedItems.isEmpty {
                        resultsSection
                    }
                }
                .padding(24)
            }
        }
        .frame(minWidth: 620, minHeight: 650)
        .onAppear {
            isQuickActionInstalled = QuickActionManager.isInstalled
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack(spacing: 16) {
            if let iconUrl = Bundle.main.url(forResource: "Icon", withExtension: "png"),
               let nsImg = NSImage(contentsOf: iconUrl) {
                Image(nsImage: nsImg)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
            } else if let fallbackImg = NSImage(contentsOfFile: "Icon.png") {
                Image(nsImage: fallbackImg)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
            } else {
                Image(systemName: "wand.and.stars.inverse")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("RPixel")
                    .font(.system(size: 22, weight: .bold))
                Text("Fix alpha bleeding & remove dark outlines on transparent sprites")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private var quickActionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Finder Right-Click Action", systemImage: "cursorarrow.click.2")
                    .font(.headline)

                Spacer()

                if isQuickActionInstalled {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Installed")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.green)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.12))
                    .clipShape(Capsule())
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.orange)
                        Text("Not Installed")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.orange)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.12))
                    .clipShape(Capsule())
                }
            }

            Text("Install the Finder Quick Action to fix any PNG directly from the macOS right-click menu without opening this window.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                if !isQuickActionInstalled {
                    Button(action: installQuickAction) {
                        Label("Install Finder Quick Action", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button(action: installQuickAction) {
                        Label("Reinstall Action", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)

                    Button(role: .destructive, action: uninstallQuickAction) {
                        Label("Uninstall", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private var dropZoneView: some View {
        VStack(spacing: 14) {
            Image(systemName: isProcessing ? "hourglass" : (isTargeted ? "arrow.down.circle.fill" : "photo.on.rectangle.angled"))
                .font(.system(size: 44))
                .foregroundStyle(isTargeted ? Color.accentColor : Color.secondary)
                .scaleEffect(isTargeted ? 1.1 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isTargeted)

            if isProcessing {
                ProgressView()
                    .progressViewStyle(.circular)
                Text("Fixing transparent alpha borders...")
                    .font(.headline)
            } else {
                Text(isTargeted ? "Drop PNG files or folders here" : "Drag & Drop PNGs or Folders Here")
                    .font(.headline)
                Text("or click to choose files from disk")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button("Choose Images...") {
                    showOpenPanel()
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 170)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isTargeted ? Color.accentColor.opacity(0.08) : Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isTargeted ? Color.accentColor : Color.primary.opacity(0.15),
                    style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                )
        )
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
        }
    }

    private var optionsSection: some View {
        HStack(spacing: 24) {
            Toggle(isOn: $debugMode) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Debug Mode")
                        .font(.body)
                    Text("Set alpha = 255 on fixed pixels to visualize dilated colors")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Toggle("Notification Banner", isOn: $sendNotification)
                .font(.subheadline)
        }
        .padding(.horizontal, 4)
    }

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Processed Images (\(lastProcessedItems.count))")
                    .font(.headline)
                Spacer()
                Button("Clear") {
                    lastProcessedItems.removeAll()
                }
                .font(.caption)
                .buttonStyle(.borderless)
            }

            ForEach(lastProcessedItems) { item in
                HStack(spacing: 12) {
                    Image(systemName: item.result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(item.result.success ? .green : .red)
                        .font(.system(size: 18))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.url.lastPathComponent)
                            .font(.body)
                            .lineLimit(1)
                        if item.result.success {
                            Text("\(item.result.width)×\(item.result.height) px • \(item.result.transparentCount) transparent pixels fixed in \(String(format: "%.3f", item.result.durationSeconds))s")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text(item.result.errorMessage ?? "Failed to fix")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }

                    Spacer()

                    Button("Show in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([item.url])
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
            }
        }
    }

    // MARK: - Actions

    private func installQuickAction() {
        do {
            try QuickActionManager.install()
            isQuickActionInstalled = true
            statusMessage = "Quick Action successfully installed!"
            NotificationHelper.sendNotification(
                title: "RPixel",
                subtitle: "Finder Action Ready",
                message: "You can now right-click any image in Finder to fix alpha bleeding."
            )
        } catch {
            statusMessage = "Install failed: \(error.localizedDescription)"
        }
    }

    private func uninstallQuickAction() {
        do {
            try QuickActionManager.uninstall()
            isQuickActionInstalled = false
            statusMessage = "Quick Action removed."
        } catch {
            statusMessage = "Uninstall failed: \(error.localizedDescription)"
        }
    }

    private func showOpenPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.png, .image]

        if panel.runModal() == .OK {
            processFiles(urls: panel.urls)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var droppedURLs: [URL] = []
        let group = DispatchGroup()

        for provider in providers {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url = url {
                    droppedURLs.append(url)
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            if !droppedURLs.isEmpty {
                self.processFiles(urls: droppedURLs)
            }
        }
        return true
    }

    func processFiles(urls: [URL]) {
        guard !urls.isEmpty else { return }
        isProcessing = true

        let paths = urls.map { $0.path }
        let resolved = FileResolver.resolve(paths: paths, recursive: true)
        let targets = resolved.pngURLs

        let currentDebug = self.debugMode
        let shouldNotify = self.sendNotification

        Task.detached(priority: .userInitiated) {
            let fixer = AlphaFixer.shared
            var results: [ProcessedItem] = []
            let start = CFAbsoluteTimeGetCurrent()
            var fixedCount = 0

            for targetURL in targets {
                let result = fixer.fixImage(at: targetURL, debug: currentDebug)
                results.append(ProcessedItem(url: targetURL, result: result))
                if result.success {
                    fixedCount += 1
                }
            }

            let elapsed = CFAbsoluteTimeGetCurrent() - start
            let finalResults = results
            let totalFixed = fixedCount

            await MainActor.run {
                self.lastProcessedItems.insert(contentsOf: finalResults, at: 0)
                self.isProcessing = false

                if shouldNotify {
                    if totalFixed > 0 {
                        NotificationHelper.sendNotification(
                            title: "RPixel",
                            subtitle: "Batch Complete",
                            message: String(format: "Fixed %d images in %.2fs", totalFixed, elapsed)
                        )
                    }
                }
            }
        }
    }
}
