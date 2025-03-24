import Foundation
import CoreData

/// 幻灯片映射模型
/// 用于将Slide实体迁移到SlideV2实体
public final class SlideToSlideV2MappingModel: NSEntityMigrationPolicy {
    
    // MARK: - Constants
    
    /// 错误域
    private static let errorDomain = "SlideToSlideV2MappingModel"
    
    // MARK: - Migration Methods
    
    /// 创建目标实例
    override public func createDestinationInstances(
        forSource sInstance: NSManagedObject,
        in mapping: NSEntityMapping,
        manager: NSMigrationManager
    ) throws {
        // 调用父类方法创建基本实例
        try super.createDestinationInstances(
            forSource: sInstance,
            in: mapping,
            manager: manager
        )
        
        // 获取源实例对应的目标实例
        guard let dInstance = manager.destinationInstances(
            forEntityMappingName: mapping.name,
            sourceInstances: [sInstance]
        ).first else {
            let error = NSError(
                domain: SlideToSlideV2MappingModel.errorDomain,
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey: "无法获取目标实例"
                ]
            )
            throw error
        }
        
        // 从源实例提取数据
        let title = sInstance.value(forKey: "title") as? String ?? ""
        let createdAt = sInstance.value(forKey: "createdAt") as? Date ?? Date()
        
        // 为新增的字段设置默认值
        let slideDescription = "从版本1迁移的幻灯片: \(title)"
        
        // 设置默认值
        dInstance.setValue(slideDescription, forKey: "slideDescription")
        
        // 迁移关联的元素
        migrateElements(
            forSource: sInstance,
            destination: dInstance,
            manager: manager
        )
        
        // 设置额外的元数据
        let metadata: [String: Any] = [
            "migrated": true,
            "migrationDate": Date(),
            "sourceVersion": "1.0",
            "destinationVersion": "2.0"
        ]
        
        if let data = try? JSONSerialization.data(withJSONObject: metadata),
           let metadataString = String(data: data, encoding: .utf8) {
            dInstance.setValue(metadataString, forKey: "metadataJSON")
        }
    }
    
    /// 迁移元素
    /// - Parameters:
    ///   - sourceSlide: 源幻灯片
    ///   - destinationSlide: 目标幻灯片
    ///   - manager: 迁移管理器
    private func migrateElements(
        forSource sourceSlide: NSManagedObject,
        destination destinationSlide: NSManagedObject,
        manager: NSMigrationManager
    ) {
        // 检查源幻灯片是否有元素
        guard let sourceElements = sourceSlide.value(forKey: "elements") as? Set<NSManagedObject>,
              !sourceElements.isEmpty else {
            // 如果没有元素，创建一个默认文本元素
            createDefaultTextElement(for: destinationSlide, in: manager)
            return
        }
        
        // 源幻灯片有元素，将它们迁移到目标幻灯片
        for sourceElement in sourceElements {
            // 获取源元素对应的目标元素
            if let destinationElement = manager.destinationInstances(
                forEntityMappingName: "ElementToSlideElement",
                sourceInstances: [sourceElement]
            ).first {
                // 建立关系
                destinationElement.setValue(destinationSlide, forKey: "slide")
                
                // 将元素添加到幻灯片的元素集合中
                if var elements = destinationSlide.value(forKey: "elements") as? Set<NSManagedObject> {
                    elements.insert(destinationElement)
                    destinationSlide.setValue(elements, forKey: "elements")
                } else {
                    destinationSlide.setValue(
                        Set([destinationElement]),
                        forKey: "elements"
                    )
                }
            }
        }
    }
    
    /// 创建默认文本元素
    /// - Parameters:
    ///   - slide: 幻灯片
    ///   - manager: 迁移管理器
    private func createDefaultTextElement(
        for slide: NSManagedObject,
        in manager: NSMigrationManager
    ) {
        // 获取目标上下文
        let context = manager.destinationContext
        
        // 创建新的元素实体
        guard let elementEntity = NSEntityDescription.entity(
            forEntityName: "SlideElement",
            in: context
        ) else {
            return
        }
        
        // 创建新的元素实例
        let element = NSManagedObject(
            entity: elementEntity,
            insertInto: context
        )
        
        // 设置元素属性
        element.setValue("text", forKey: "type")
        element.setValue("默认文本元素", forKey: "content")
        element.setValue(slide, forKey: "slide")
        
        // 设置位置和大小
        let frame: [String: Double] = [
            "x": 100.0,
            "y": 100.0,
            "width": 200.0,
            "height": 50.0
        ]
        
        if let frameData = try? JSONSerialization.data(withJSONObject: frame),
           let frameString = String(data: frameData, encoding: .utf8) {
            element.setValue(frameString, forKey: "frameJSON")
        }
        
        // 设置样式
        let style: [String: Any] = [
            "fontName": "Helvetica",
            "fontSize": 18,
            "textColor": "#000000",
            "backgroundColor": "transparent",
            "alignment": "left"
        ]
        
        if let styleData = try? JSONSerialization.data(withJSONObject: style),
           let styleString = String(data: styleData, encoding: .utf8) {
            element.setValue(styleString, forKey: "styleJSON")
        }
        
        // 将元素添加到幻灯片的元素集合中
        if var elements = slide.value(forKey: "elements") as? Set<NSManagedObject> {
            elements.insert(element)
            slide.setValue(elements, forKey: "elements")
        } else {
            slide.setValue(
                Set([element]),
                forKey: "elements"
            )
        }
    }
    
    /// 自定义验证
    override public func endInstanceCreation() throws {
        // 在所有实例创建完成后执行验证
        try super.endInstanceCreation()
        
        // 这里可以添加额外的验证逻辑
    }
} 