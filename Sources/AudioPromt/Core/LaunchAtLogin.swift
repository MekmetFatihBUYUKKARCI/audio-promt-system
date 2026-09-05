import ServiceManagement
import Foundation

/// PLAN.md Faz 5 madde 5 — launchd plist elle yazmak yerine
/// SMAppService (dersler.md'deki launchd sorunlarından kaçınmak için).
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            NSLog("⚠️ Girişte otomatik başlatma değişikliği başarısız: \(error)")
        }
    }

    static func registerIfNeeded() {
        do {
            if SMAppService.mainApp.status != .enabled {
                try SMAppService.mainApp.register()
                NSLog("✅ Girişte otomatik başlatma kaydedildi")
            }
        } catch {
            NSLog("⚠️ Girişte otomatik başlatma kaydı başarısız: \(error)")
        }
    }
}
