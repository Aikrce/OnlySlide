import Foundation
import CoreGraphics

public protocol PlatformAdapter {
    func getScreenSize() -> CGSize
    func openDocument() -> URL?
}

#if os(iOS)
public class IOSPlatformAdapter: PlatformAdapter {
    public init() {}
    
    public func getScreenSize() -> CGSize {
        // iOS实现
        return CGSize(width: 390, height: 844)
    }
    
    public func openDocument() -> URL? {
        // iOS实现
        return nil
    }
}
#elseif os(macOS)
public class MacOSPlatformAdapter: PlatformAdapter {
    public init() {}
    
    public func getScreenSize() -> CGSize {
        // macOS实现
        return CGSize(width: 1440, height: 900)
    }
    
    public func openDocument() -> URL? {
        // macOS实现
        return nil
    }
}
#endif

public func createPlatformAdapter() -> PlatformAdapter {
    #if os(iOS)
    return IOSPlatformAdapter()
    #elseif os(macOS)
    return MacOSPlatformAdapter()
    #endif
}