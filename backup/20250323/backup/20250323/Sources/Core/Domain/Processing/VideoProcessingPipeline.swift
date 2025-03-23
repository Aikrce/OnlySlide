import Foundation
import AVFoundation

public protocol VideoProcessor {
    func process(_ url: URL) async throws -> URL
}

public class VideoProcessingPipeline {
    private var processors: [VideoProcessor] = []
    
    public init() {}
    
    public func addProcessor(_ processor: VideoProcessor) {
        processors.append(processor)
    }
    
    public func process(_ url: URL) async throws -> URL {
        var processedURL = url
        
        for processor in processors {
            processedURL = try await processor.process(processedURL)
        }
        
        return processedURL
    }
    
    public func reset() {
        processors.removeAll()
    }
}

// 默认的视频处理器
public class VideoCompressionProcessor: VideoProcessor {
    private let quality: Float
    
    public init(quality: Float = 0.7) {
        self.quality = quality
    }
    
    public func process(_ url: URL) async throws -> URL {
        let asset = AVAsset(url: url)
        let composition = AVMutableComposition()
        
        // 创建视频轨道
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = videoTracks.first,
              let compositionVideoTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
              ) else {
            throw VideoProcessingError.trackCreationFailed
        }
        
        // 获取视频时长
        let duration = try await asset.load(.duration)
        
        // 添加视频轨道
        try compositionVideoTrack.insertTimeRange(
            CMTimeRange(start: .zero, duration: duration),
            of: videoTrack,
            at: .zero
        )
        
        // 创建导出会话
        let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetMediumQuality
        )
        
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        
        exportSession?.outputURL = outputURL
        exportSession?.outputFileType = .mp4
        
        // 导出压缩后的视频
        await exportSession?.export()
        
        guard exportSession?.status == .completed else {
            throw VideoProcessingError.exportFailed
        }
        
        return outputURL
    }
}

public class VideoTrimProcessor: VideoProcessor {
    private let startTime: CMTime
    private let duration: CMTime
    
    public init(startTime: CMTime, duration: CMTime) {
        self.startTime = startTime
        self.duration = duration
    }
    
    public func process(_ url: URL) async throws -> URL {
        let asset = AVAsset(url: url)
        let composition = AVMutableComposition()
        
        // 创建视频轨道
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = videoTracks.first,
              let compositionVideoTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
              ) else {
            throw VideoProcessingError.trackCreationFailed
        }
        
        // 获取视频时长
        let duration = try await asset.load(.duration)
        
        // 添加视频轨道
        try compositionVideoTrack.insertTimeRange(
            CMTimeRange(start: startTime, duration: duration),
            of: videoTrack,
            at: .zero
        )
        
        // 创建导出会话
        let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        )
        
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        
        exportSession?.outputURL = outputURL
        exportSession?.outputFileType = .mp4
        
        // 导出裁剪后的视频
        await exportSession?.export()
        
        guard exportSession?.status == .completed else {
            throw VideoProcessingError.exportFailed
        }
        
        return outputURL
    }
}

public enum VideoProcessingError: LocalizedError {
    case invalidVideoTrack
    case exportFailed
    case trackCreationFailed
    
    public var errorDescription: String? {
        switch self {
        case .invalidVideoTrack:
            return "Invalid video track"
        case .exportFailed:
            return "Failed to export video"
        case .trackCreationFailed:
            return "Failed to create video track"
        }
    }
} 