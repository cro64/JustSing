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
    private var sampleRateAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyNominalSampleRate,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    private var listenedSampleRateDeviceID: AudioDeviceID?

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

        refreshSampleRateListener()

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
        removeSampleRateListener()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    fileprivate func handleDeviceChange() {
        refreshSampleRateListener()
        DispatchQueue.main.async { [onDeviceChange] in
            onDeviceChange()
        }
    }

    fileprivate func handleSampleRateChange() {
        DispatchQueue.main.async { [onDeviceChange] in
            onDeviceChange()
        }
    }

    private func refreshSampleRateListener() {
        removeSampleRateListener()
        guard let deviceID = CoreAudioDevices.defaultOutputDeviceID() else { return }

        listenedSampleRateDeviceID = deviceID
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        AudioObjectAddPropertyListener(
            deviceID,
            &sampleRateAddress,
            sampleRateListener,
            selfPointer
        )
    }

    private func removeSampleRateListener() {
        guard let deviceID = listenedSampleRateDeviceID else { return }
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        AudioObjectRemovePropertyListener(
            deviceID,
            &sampleRateAddress,
            sampleRateListener,
            selfPointer
        )
        listenedSampleRateDeviceID = nil
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

private let sampleRateListener: AudioObjectPropertyListenerProc = { _, _, _, userData in
    guard let userData else { return noErr }
    let monitor = Unmanaged<DeviceMonitor>.fromOpaque(userData).takeUnretainedValue()
    monitor.handleSampleRateChange()
    return noErr
}
