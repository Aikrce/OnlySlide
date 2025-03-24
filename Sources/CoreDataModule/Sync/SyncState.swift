import Foundation

public enum SyncState: Equatable {
    case idle
    case syncing
    case completed
    case error(Error)
    
    public static func == (lhs: SyncState, rhs: SyncState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.syncing, .syncing),
             (.completed, .completed):
            return true
        case let (.error(error1), .error(error2)):
            return error1.localizedDescription == error2.localizedDescription
        default:
            return false
        }
    }
} 