import ServiceManagement
import SwiftUI

enum LaunchAtLoginStatus: Equatable {
    case disabled
    case enabled
    case requiresApproval
    case unavailable
}

protocol LaunchAtLoginServicing {
    var status: LaunchAtLoginStatus { get }
    func register() throws
    func unregister() throws
    func openSystemSettings()
}

struct SystemLaunchAtLoginService: LaunchAtLoginServicing {
    var status: LaunchAtLoginStatus {
        switch SMAppService.mainApp.status {
        case .notRegistered: return .disabled
        case .enabled: return .enabled
        case .requiresApproval: return .requiresApproval
        case .notFound: return .unavailable
        @unknown default: return .unavailable
        }
    }

    func register() throws { try SMAppService.mainApp.register() }
    func unregister() throws { try SMAppService.mainApp.unregister() }
    func openSystemSettings() { SMAppService.openSystemSettingsLoginItems() }
}

final class LaunchAtLoginController: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var requiresApproval = false
    @Published private(set) var message: String?
    private let service: LaunchAtLoginServicing

    init(service: LaunchAtLoginServicing = SystemLaunchAtLoginService()) {
        self.service = service
        refresh()
    }

    func refresh() {
        let status = service.status
        isEnabled = status == .enabled || status == .requiresApproval
        requiresApproval = status == .requiresApproval
        if !requiresApproval, message?.contains("Systemeinstellungen") == true {
            message = nil
        }
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                if service.status == .disabled || service.status == .unavailable {
                    try service.register()
                }
            } else if service.status != .disabled {
                try service.unregister()
            }
            refresh()
            if requiresApproval {
                message = "macOS wartet noch auf deine Freigabe in den Systemeinstellungen."
            } else {
                message = enabled ? "MausSprung startet künftig bei der Anmeldung." : "Autostart wurde ausgeschaltet."
            }
        } catch {
            refresh()
            message = "Autostart konnte nicht geändert werden: \(error.localizedDescription)"
        }
    }

    func openSystemSettings() { service.openSystemSettings() }
}
