import Foundation
import Combine

public class StateStorage {
    public static let shared = StateStorage()
    
    private init() {}
    
    public func saveState(_ state: Data, forKey key: String) {
        UserDefaults.standard.set(state, forKey: key)
    }
    
    public func loadState(forKey key: String) -> Data? {
        return UserDefaults.standard.data(forKey: key)
    }
    
    public func clearState(forKey key: String) {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

