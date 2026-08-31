import Foundation

public final class DeviceDirectoryWatcher: @unchecked Sendable {
    private let rootURL: URL
    private let debounceInterval: DispatchTimeInterval
    private let queue = DispatchQueue(label: "app.bootbar.device-directory-watcher")
    private var sources: [String: DispatchSourceFileSystemObject] = [:]
    private var onChange: (@Sendable () -> Void)?
    private var pendingNotification: DispatchWorkItem?

    public static var coreSimulatorDevices: String {
        NSHomeDirectory() + "/Library/Developer/CoreSimulator/Devices"
    }

    public static var androidAVDs: String {
        ProcessInfo.processInfo.environment["ANDROID_AVD_HOME"] ?? NSHomeDirectory() + "/.android/avd"
    }

    public init(rootPath: String, debounceInterval: DispatchTimeInterval = .milliseconds(250)) {
        self.rootURL = URL(fileURLWithPath: rootPath)
        self.debounceInterval = debounceInterval
    }

    deinit { sources.values.forEach { $0.cancel() } }

    public func start(onChange: @escaping @Sendable () -> Void) {
        queue.async {
            self.onChange = onChange
            self.syncWatchedDirectories()
        }
    }

    public func stop() {
        queue.async {
            self.pendingNotification?.cancel()
            self.pendingNotification = nil
            self.onChange = nil
            self.sources.values.forEach { $0.cancel() }
            self.sources.removeAll()
        }
    }

    private func syncWatchedDirectories() {
        var wanted: Set<String> = [rootURL.path]
        let contents = (try? FileManager.default.contentsOfDirectory(at: rootURL,
                                                                     includingPropertiesForKeys: [.isDirectoryKey],
                                                                     options: [.skipsHiddenFiles])) ?? []
        for url in contents where (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
            wanted.insert(url.path)
        }

        for (path, source) in sources where !wanted.contains(path) {
            source.cancel()
            sources[path] = nil
        }
        for path in wanted where sources[path] == nil {
            watch(path)
        }
    }

    private func watch(_ path: String) {
        let descriptor = open(path, O_EVTONLY)
        guard descriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .delete, .rename, .revoke],
            queue: queue
        )
        let isRoot = (path == rootURL.path)
        source.setEventHandler { [weak self] in
            guard let self else { return }
            let event = source.data
            if event.contains(.delete) || event.contains(.rename) || event.contains(.revoke) {
                source.cancel()
                self.sources[path] = nil
            }
            if isRoot || self.sources[path] == nil {
                self.syncWatchedDirectories()
            }
            self.scheduleNotification()
        }
        source.setCancelHandler { close(descriptor) }
        sources[path] = source
        source.resume()
    }

    private func scheduleNotification() {
        pendingNotification?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.pendingNotification = nil
            self?.onChange?()
        }
        pendingNotification = work
        queue.asyncAfter(deadline: .now() + debounceInterval, execute: work)
    }
}
