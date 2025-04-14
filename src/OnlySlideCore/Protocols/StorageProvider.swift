import Foundation

public protocol StorageProvider {
    func save(_ data: Data, to identifier: String) throws
    func load(from identifier: String) throws -> Data
    func delete(identifier: String) throws
    func exists(identifier: String) -> Bool
}

public enum StorageError: Error {
    case saveFailure
    case loadFailure
    case deleteFailure
    case notFound
} 