import SwiftUI

/// 文档分析进度视图
struct AnalysisProgressView: View {
    /// 分析进度 (0.0 - 1.0)
    let progress: Float
    /// 文件类型
    var fileType: DocumentFileType?
    /// 当前分析阶段
    var currentStage: AnalysisStage?
    /// 是否显示取消按钮
    var showCancelButton: Bool = true
    /// 取消分析回调
    var onCancel: (() -> Void)?
    
    /// 分析阶段枚举
    enum AnalysisStage: String {
        case preparing = "准备分析"
        case extractingText = "提取文本"
        case analyzingStructure = "分析结构"
        case processingImages = "处理图像"
        case transcribingAudio = "转录音频"
        case extractingFrames = "提取视频帧"
        case generatingSlides = "生成幻灯片"
        case finalizing = "最终处理"
    }
    
    // 自动计算当前阶段
    private var calculatedStage: AnalysisStage {
        if let stage = currentStage {
            return stage
        }
        
        // 根据进度推断阶段
        switch progress {
        case 0.0..<0.15:
            return .preparing
        case 0.15..<0.35:
            if fileType == .audio {
                return .transcribingAudio
            } else if fileType == .video {
                return .extractingFrames
            } else {
                return .extractingText
            }
        case 0.35..<0.6:
            return .analyzingStructure
        case 0.6..<0.8:
            if fileType == .pdf || fileType == .word {
                return .processingImages
            } else {
                return .analyzingStructure
            }
        case 0.8..<0.95:
            return .generatingSlides
        default:
            return .finalizing
        }
    }
    
    // 进度百分比文本
    private var progressText: String {
        let percentage = Int(progress * 100)
        return "\(percentage)%"
    }
    
    // 预计剩余时间（模拟）
    private var estimatedTimeText: String {
        let remaining = max(0, 1.0 - progress)
        let seconds = Int(remaining * 10) // 假设最长10秒
        
        if seconds < 1 {
            return "即将完成"
        } else {
            return "预计剩余 \(seconds) 秒"
        }
    }
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // 标题和图标
            VStack(spacing: 16) {
                Image(systemName: getIconForFileType())
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                    .opacity(0.8)
                
                Text("正在分析文档")
                    .font(.title)
                    .fontWeight(.semibold)
                
                Text(getAnalysisDescription())
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // 进度区域
            VStack(spacing: 20) {
                // 当前阶段
                HStack {
                    Image(systemName: getIconForStage(calculatedStage))
                        .foregroundColor(.blue)
                    
                    Text(calculatedStage.rawValue)
                        .fontWeight(.medium)
                    
                    Spacer()
                }
                .padding(.horizontal, 30)
                
                // 进度条
                ZStack(alignment: .leading) {
                    // 背景
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    // 进度
                    Rectangle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [.blue, .purple]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: max(CGFloat(progress) * UIScreen.main.bounds.width - 40, 0), height: 8)
                        .cornerRadius(4)
                }
                .padding(.horizontal, 20)
                
                // 进度文本和预计时间
                HStack {
                    Text(progressText)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Text(estimatedTimeText)
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                }
                .padding(.horizontal, 30)
            }
            .padding(.vertical)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 2)
            )
            .padding(.horizontal)
            
            // 分析步骤指示器
            analysisStepsView
                .padding()
            
            Spacer()
            
            // 取消按钮
            if showCancelButton {
                Button(action: {
                    onCancel?()
                }) {
                    Text("取消")
                        .foregroundColor(.red)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.red, lineWidth: 1)
                        )
                }
                .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
    
    /// 分析步骤指示器视图
    private var analysisStepsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("分析步骤")
                .font(.headline)
                .padding(.bottom, 4)
            
            ForEach(getAnalysisSteps(), id: \.self) { stage in
                HStack(spacing: 12) {
                    // 阶段完成状态图标
                    ZStack {
                        Circle()
                            .fill(getStageColor(stage))
                            .frame(width: 24, height: 24)
                        
                        if isStageComplete(stage) {
                            Image(systemName: "checkmark")
                                .font(.caption)
                                .foregroundColor(.white)
                        } else if stage == calculatedStage {
                            // 当前阶段显示动画
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.6)
                        }
                    }
                    
                    // 阶段名称
                    Text(stage.rawValue)
                        .foregroundColor(stage == calculatedStage ? .primary : .secondary)
                        .fontWeight(stage == calculatedStage ? .medium : .regular)
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
        .padding(.horizontal)
    }
    
    /// 获取文件类型图标
    private func getIconForFileType() -> String {
        if let fileType = fileType {
            return fileType.icon
        } else {
            return "doc.text"
        }
    }
    
    /// 获取分析描述
    private func getAnalysisDescription() -> String {
        if let fileType = fileType {
            switch fileType {
            case .pdf:
                return "正在提取PDF文档内容并分析结构"
            case .word:
                return "正在解析Word文档并提取关键内容"
            case .text:
                return "正在分析文本内容并识别主题结构"
            case .audio:
                return "正在转录音频内容并提取关键信息"
            case .video:
                return "正在处理视频内容，提取音频和关键帧"
            case .other:
                return "正在分析文档内容"
            }
        } else {
            return "正在处理您的文档，请稍候"
        }
    }
    
    /// 获取分析步骤
    private func getAnalysisSteps() -> [AnalysisStage] {
        if let fileType = fileType {
            switch fileType {
            case .pdf, .word:
                return [.preparing, .extractingText, .analyzingStructure, .processingImages, .generatingSlides, .finalizing]
            case .audio:
                return [.preparing, .transcribingAudio, .analyzingStructure, .generatingSlides, .finalizing]
            case .video:
                return [.preparing, .extractingFrames, .transcribingAudio, .analyzingStructure, .generatingSlides, .finalizing]
            default:
                return [.preparing, .extractingText, .analyzingStructure, .generatingSlides, .finalizing]
            }
        } else {
            return [.preparing, .extractingText, .analyzingStructure, .generatingSlides, .finalizing]
        }
    }
    
    /// 获取阶段图标
    private func getIconForStage(_ stage: AnalysisStage) -> String {
        switch stage {
        case .preparing:
            return "gear"
        case .extractingText:
            return "doc.text"
        case .analyzingStructure:
            return "chart.bar.doc.horizontal"
        case .processingImages:
            return "photo"
        case .transcribingAudio:
            return "waveform"
        case .extractingFrames:
            return "film"
        case .generatingSlides:
            return "rectangle.on.rectangle"
        case .finalizing:
            return "checkmark.circle"
        }
    }
    
    /// 判断阶段是否完成
    private func isStageComplete(_ stage: AnalysisStage) -> Bool {
        let stageOrder = getAnalysisSteps()
        guard let currentIndex = stageOrder.firstIndex(of: calculatedStage),
              let stageIndex = stageOrder.firstIndex(of: stage) else {
            return false
        }
        
        return stageIndex < currentIndex
    }
    
    /// 获取阶段颜色
    private func getStageColor(_ stage: AnalysisStage) -> Color {
        if isStageComplete(stage) {
            return .green
        } else if stage == calculatedStage {
            return .blue
        } else {
            return .gray.opacity(0.3)
        }
    }
} 