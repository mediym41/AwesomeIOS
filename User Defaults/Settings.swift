
import Foundation

class Settings {
    static let shared = Settings()
    
    private let storage = UserDefaults.standard//UserDefaults(suiteName: "group.com.")!
    private let key = "key"
    
    var value: Bool {
        get {
            return storage.object(forKey: key)            
        }
        set {            
            storage.set(newValue, forKey: key)
        }
    }
    
    func clear() {
        guard let domain = Bundle.main.bundleIdentifier else { return }
        storage.removePersistentDomain(forName: domain)
        storage.synchronize()
    }
    
}
