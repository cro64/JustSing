import AppKit
import CoreAudio
import Foundation

final class DeviceMonitor {
    private let onDeviceChange: () -> Void
    private let onWillSleep: () -> Void
    private let onDidWake: () -> Void
    private var defaultOutputAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    init(
        onDeviceChange: @escaping () -> Void,
        onWillSleep: @escaping () -> Void,
        onDidWake: @escaping () -> Void
    ) {
        self.onDeviceChange = onDeviceChange
        self.onWillSleep = onWillSleep
        self.onDidWake = onDidWake
    }

    deinit {
        stop()
    }

    func start() {
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()

        AudioObjectAddPropertyListener(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultOutputAddress,
            deviceChangeListener,
            selfPointer
        )

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(workspaceWillSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(workspaceDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    func stop() {
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        AudioObjectRemovePropertyListener(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultOutputAddress,
            deviceChangeListener,
            selfPointer
        )
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    fileprivate func handleDeviceChange() {
        DispatchQueue.main.async { [onDeviceChange] in
            onDeviceChange()
        }
    }

    @objc private func workspaceWillSleep() {
        onWillSleep()
    }

    @objc private func workspaceDidWake() {
        onDidWake()
    }
}

private let deviceChangeListener: AudioObjectPropertyListenerProc = { _, _, _, userData in
    guard let userData else { return noErr }
    let monitor = Unmanaged<DeviceMonitor>.fromOpaque(userData).takeUnretainedValue()
    monitor.handleDeviceChange()
    return noErr
}
