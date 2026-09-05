import ServiceManagement
import Foundation

/// PLAN.md Faz 5 madde 5 — launchd plist elle yazmak yerine
/// SMAppService (dersler.md'deki launchd sorunlarından kaçınmak için).
enum LaunchAtLogin {
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
