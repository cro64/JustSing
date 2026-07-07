import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let preferences = Preferences()
    private lazy var audioEngine = AudioEngine(preferences: preferences)
    private var menuBarController: MenuBarController?
    private var deviceMonitor: DeviceMonitor?
    private var hotKeyController: HotKeyController?
    private var restartAfterWake = false
    private var deviceRebuildWorkItem: DispatchWorkItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if #available(macOS 14.2, *) {
            ProcessTapSession.destroyStaleAggregates()
        }
        audioEngine.recoverOrphanedBlackHoleIfNeeded()

        menuBarController = MenuBarController(
            preferences: preferences,
            audioEngine: audioEngine
        )
        audioEngine.onStatusChanged = { [weak self] status in
            self?.menuBarController?.updateStatus(status)
        }

        deviceMonitor = DeviceMonitor(
            onDeviceChange: { [weak self] in
                guard let self else { return }
                deviceRebuildWorkItem?.cancel()
                let item = DispatchWorkItem { [weak self] in
                    guard let self, audioEngine.isRunning else { return }
                    audioEngine.rebuildForDeviceChange()
                }
                deviceRebuildWorkItem = item
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.75, execute: item)
            },
            onWillSleep: { [weak self] in
                guard let self else { return }
                restartAfterWake = audioEngine.isRunning
                audioEngine.stop(restoreOutput: true)
            },
            onDidWake: { [weak self] in
                guard let self, restartAfterWake else { return }
                restartAfterWake = false
                audioEngine.start()
            }
        )
        deviceMonitor?.start()

        hotKeyController = HotKeyController { [weak self] in
            self?.audioEngine.toggleReduction()
            self?.menuBarController?.updateStatus(self?.audioEngine.status ?? .idle)
        }
        hotKeyController?.registerDefaultHotKey()

        menuBarController?.updateStatus(.idle)
        AppLogger.shared.info("JustSing launched")
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeyController?.unregister()
        deviceMonitor?.stop()
        audioEngine.stop(restoreOutput: true)
        AppLogger.shared.info("JustSing terminated")
    }
}
