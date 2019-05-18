
import Foundation
import NetworkExtension

extension Notification.Name {
    static let vpnStatus = Notification.Name("VPNManager.status")
    static let vpnError = Notification.Name("VPNManager.error")
    static let killLauncher = Notification.Name("KillLauncher")
}

extension NEVPNStatus {
    var description: String {
        switch self {
        case .connected: return "status.сonnected"
        case .connecting: return "status.connecting"
        case .disconnected: return  "status.disconnected"
        case .disconnecting: return  "status.disconnecting"
        case .reasserting: return  "status.reconnecting"
        case .invalid: return  "status.invalid"
        @unknown default:
            return "Error"
        }
    }
}

typealias OperationHandler = ((Error?) -> Void)
typealias EmptyClosure = () -> Void

class VPNManager {
    static let shared = VPNManager()
    
    private let manager = NEVPNManager.shared()
    private let storage = Storage.shared
    private let settings = Settings.shared
    private let defaultHost = ""
    
    private var isConfigured = false
    private var connectWhenConfigured = false
    private var requestIPWhenDisconnected = false

    var autoconnect = false {
        didSet {
            if oldValue == autoconnect { return  }
            if isConfigured {
                connectToLatestServer()
            } else {
                connectWhenConfigured = true
            }
        }
    }
    
    func initialize() {
        loadConfiguration()
        subscribe()
        setupAutoconnect()
    }
    
    var isConnected: Bool {
        return manager.connection.status == .connected
    }
    
    var isDisconnected: Bool {
        return manager.connection.status == .disconnected || manager.connection.status == .invalid
    }
    
    var status: NEVPNStatus {
        return manager.connection.status
    }
    
    var selectedHost: String? {
        return manager.protocolConfiguration?.serverAddress
    }
    
    var isKillswitchActivated: Bool {
        return manager.isEnabled && manager.isOnDemandEnabled
    }
    
    var isActivated: Bool {
        return manager.isEnabled &&
            manager.connection.status != .disconnected &&
            manager.connection.status != .invalid
    }
    
    func reload() {
        loadConfiguration()
    }
    
    func connectToLatestServer() {
        let host = settings.latestConnectedHost ?? defaultHost
        connect(to: host)
    }
    
    func connect(to host: String) {
        if !isDisconnected {
            disconnect {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.connect(to: host)
                }
            }
            return
        }
        
        let needsReolad = manager.connection.status == .invalid
        let configuration = createVPNConfiguration(host: host)
        manager.protocolConfiguration = configuration
        manager.isEnabled = true
        
        if Settings.shared.isOnDemandEnabled {
            manager.isOnDemandEnabled = true
            let connectRule = NEOnDemandRuleConnect()
            connectRule.interfaceTypeMatch = .any
            manager.onDemandRules = [connectRule]
        }
        
        saveConfiguration { error in
            if let error = error {
                self.postNotification(type: .vpnError, userInfo: ["message": error.localizedDescription])
            } else if needsReolad {
                self.loadConfiguration { _ in
                    self.startTunnel()
                    self.postNotification(type: .vpnStatus)
                }
            } else {
                self.startTunnel()
            }
        }
    }
    
    func disconnect(_ callback: EmptyClosure? = nil) {
        manager.connection.stopVPNTunnel()
        manager.isOnDemandEnabled = false
        manager.isEnabled = false
        manager.saveToPreferences { error in
            callback?()
        }
        
        if callback == nil {
            requestIPWhenDisconnected = true
        }
    }
    
    //MARK: Private
    
    private func setupAutoconnect() {
        autoconnect = Settings.shared.isAutoconnectEnabled
    }
    
    private func loadConfiguration(handler: OperationHandler? = nil) {
        manager.loadFromPreferences(completionHandler: handler ?? handleConfigurationLoaded)
    }
    
    private func saveConfiguration(handler: OperationHandler?) {
        manager.saveToPreferences(completionHandler: handler)
    }
    
    private func postNotification(type: Notification.Name, userInfo: [AnyHashable : Any]? = nil) {
        let notification = Notification(name: type,
                                        object: self,
                                        userInfo: userInfo)
        NotificationCenter.default.post(notification)
        
    }
    
    private func subscribe() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleConfigurationChange),
                                               name: .NEVPNConfigurationChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleConnectionStatusChange),
                                               name: .NEVPNStatusDidChange, object: nil)
    }
    
    private func startTunnel() {
        do {
            try self.manager.connection.startVPNTunnel()
        } catch {
            print(error.localizedDescription);
        }
    }
    
    private func createVPNConfiguration(host: String) -> NEVPNProtocol {
        let ikev2 = NEVPNProtocolIKEv2()
        
        ikev2.serverAddress = host
        ikev2.remoteIdentifier = host
        
        ikev2.authenticationMethod = .none
        ikev2.useExtendedAuthentication = true
        //ikev2.localIdentifier   = username
        ikev2.username          = settings.username
        ikev2.passwordReference = storage.getPasswordReference()
        
        ikev2.disconnectOnSleep = true
        
        return ikev2
    }
    
    //MARK: Private Handlers
    private func handleConfigurationLoaded(error: Error?) {
        postNotification(type: .vpnStatus, userInfo:  ["isVisible": false])
        if let error = error {
            postNotification(type: .vpnError, userInfo: ["message": error.localizedDescription])
        }
        
        isConfigured = true
        if connectWhenConfigured && !isActivated {
            connectToLatestServer()
        }
    }
    
    @objc func handleConfigurationChange(change: Any?) {
        postNotification(type: .vpnStatus)
    }
    
    @objc func handleConnectionStatusChange(change: Any?) {
        if status == .invalid {
            reload()
        }
        
        postNotification(type: .vpnStatus)
    }
}
