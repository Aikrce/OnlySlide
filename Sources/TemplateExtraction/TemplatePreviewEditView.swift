import SwiftUI

/// 模板预览与编辑组合视图，为用户提供统一的预览和编辑体验
public struct TemplatePreviewEditView: View {
    /// 被预览/编辑的模板信息
    @State private var templateInfo: PPTLayoutExtractor.PPTTemplateInfo
    /// 是否处于编辑模式
    @State private var isEditingMode: Bool = false
    /// 是否有未保存的更改
    @State private var hasUnsavedChanges: Bool = false
    /// 是否显示丢弃更改确认对话框
    @State private var showingDiscardChangesAlert: Bool = false
    /// 完成回调
    var onComplete: ((PPTLayoutExtractor.PPTTemplateInfo?) -> Void)?
    
    /// 初始化方法
    /// - Parameters:
    ///   - templateInfo: 模板信息
    ///   - onComplete: 完成回调，如果参数为nil表示取消操作
    public init(templateInfo: PPTLayoutExtractor.PPTTemplateInfo, onComplete: ((PPTLayoutExtractor.PPTTemplateInfo?) -> Void)? = nil) {
        self._templateInfo = State(initialValue: templateInfo)
        self.onComplete = onComplete
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            HStack {
                // 模式切换
                Picker("模式", selection: $isEditingMode) {
                    Text("预览").tag(false)
                    Text("编辑").tag(true)
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 200)
                
                Spacer()
                
                // 取消按钮
                Button("取消") {
                    if hasUnsavedChanges {
                        showingDiscardChangesAlert = true
                    } else {
                        dismiss()
                    }
                }
                
                // 保存按钮（仅在编辑模式下显示）
                if isEditingMode {
                    Button("保存") {
                        saveChanges()
                    }
                    .disabled(!hasUnsavedChanges)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            
            // 主内容区域
            if isEditingMode {
                // 编辑视图
                TemplateEditView(templateInfo: templateInfo) { updatedInfo in
                    templateInfo = updatedInfo
                    hasUnsavedChanges = true
                }
            } else {
                // 预览视图
                TemplatePreviewView(templateInfo: templateInfo)
            }
        }
        .alert(isPresented: $showingDiscardChangesAlert) {
            Alert(
                title: Text("放弃更改"),
                message: Text("您有未保存的更改，确定要放弃吗？"),
                primaryButton: .destructive(Text("放弃")) {
                    dismiss()
                },
                secondaryButton: .cancel(Text("取消"))
            )
        }
    }
    
    /// 保存更改并关闭
    private func saveChanges() {
        onComplete?(templateInfo)
    }
    
    /// 取消并关闭
    private func dismiss() {
        onComplete?(nil)
    }
}

// MARK: - 预览

struct TemplatePreviewEditView_Previews: PreviewProvider {
    static var previews: some View {
        // 使用与TemplatePreviewView_Previews相同的示例数据
        let templateInfo = TemplatePreviewView_Previews.createSampleTemplateInfo()
        
        TemplatePreviewEditView(templateInfo: templateInfo)
    }
}
