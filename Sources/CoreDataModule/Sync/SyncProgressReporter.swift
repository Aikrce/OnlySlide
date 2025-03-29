/// SyncProgressReporter类负责报告同步进度
@MainActor
public class SyncProgressReporter: SyncProgressReporterProtocol, Sendable {
    /// 状态管理Actor
    private actor StateActor {
        var stateValue = SyncState.idle
        var progressValue = 0.0
        var errorValue: Error? = nil
        
        func setState(_ state: SyncState) {
            stateValue = state
        }
        
        func setProgress(_ progress: Double) {
            progressValue = max(0, min(1, progress)) // 确保在0-1范围内
        }
        
        func setError(_ error: Error?) {
            errorValue = error
        }
        
        func getState() -> SyncState {
            return stateValue
        }
        
        func getProgress() -> Double {
            return progressValue
        }
        
        func getError() -> Error? {
            return errorValue
        }
        
        func reset() {
            stateValue = .idle
            progressValue = 0.0
            errorValue = nil
        }
    }
    
    /// 状态Actor实例
    private let stateActor = StateActor()
    
    /// 初始化进度报告器
    public init() {}
    
    /// 当前状态
    nonisolated public var state: SyncState {
        get async {
            return await stateActor.getState()
        }
    }
    
    /// 当前进度
    nonisolated public var progress: Double {
        get async {
            return await stateActor.getProgress()
        }
    }
    
    /// 当前错误
    nonisolated public var error: Error? {
        get async {
            return await stateActor.getError()
        }
    }
    
    /// 重置报告器
    public func reset() async {
        await stateActor.reset()
    }
    
    /// 报告准备开始
    public func reportPreparing() async {
        await stateActor.setState(.preparing)
        await stateActor.setProgress(0.0)
    }
    
    /// 报告同步中
    public func reportSyncing() async {
        await stateActor.setState(.syncing)
        await stateActor.setProgress(0.2)
    }
    
    /// 报告上传进度
    public func reportUploading(progress: Double) async {
        await stateActor.setState(.uploading(progress: progress))
        await stateActor.setProgress(progress)
    }
    
    /// 报告下载进度
    public func reportDownloading(progress: Double) async {
        await stateActor.setState(.downloading(progress: progress))
        await stateActor.setProgress(progress)
    }
    
    /// 报告完成
    public func reportCompleted() async {
        await stateActor.setState(.completed)
        await stateActor.setProgress(1.0)
    }
    
    /// 报告失败
    public func reportFailed(error: Error) async {
        await stateActor.setState(.failed(error))
        await stateActor.setError(error)
    }
} 