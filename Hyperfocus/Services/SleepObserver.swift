import AppKit

final class SleepObserver {
    private var observer: NSObjectProtocol?

    init(onSleep: @escaping () -> Void) {
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { _ in
            onSleep()
        }
    }

    deinit {
        if let observer = observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }
}
