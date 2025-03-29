import CoreData
import Foundation
import os

/// 实体迁移策略基类
/// 为特定实体的迁移提供自定义逻辑
public class EntityMigrationPolicy: NSEntityMigrationPolicy, @unchecked Sendable {
    
    /// Logger for migration operations
    private let logger = Logger(subsystem: "com.onlyslide.coredatamodule", category: "Migration")
    
    // MARK: - Destination Instance Creation
    
    /// 创建目标实体实例
    /// 在创建目标实例时自定义属性设置和关系处理
    @objc override open func createDestinationInstances(
        forSource sInstance: NSManagedObject,
        in mapping: NSEntityMapping,
        manager: NSMigrationManager
    ) throws {
        // 首先调用父类方法创建目标实例
        try super.createDestinationInstances(forSource: sInstance, in: mapping, manager: manager)
        
        // 获取为源实例创建的所有目标实例
        guard let dInstance = manager.destinationInstances(
            forEntityMappingName: mapping.name,
            sourceInstances: [sInstance]
        ).first else {
            logger.warning("No destination instance created for source: \(sInstance.objectID.uriRepresentation().lastPathComponent)")
            return
        }
        
        // 执行自定义迁移逻辑
        do {
            try customMigrate(source: sInstance, destination: dInstance, mapping: mapping, manager: manager)
        } catch {
            logger.error("Error during custom migration for entity \(mapping.name ?? "unknown"): \(error.localizedDescription)")
            throw error
        }
    }
    
    /// 自定义迁移逻辑
    /// 子类应该重写此方法以提供特定实体的迁移逻辑
    /// - Parameters:
    ///   - source: 源实例
    ///   - destination: 目标实例
    ///   - mapping: 实体映射
    ///   - manager: 迁移管理器
    open func customMigrate(
        source: NSManagedObject,
        destination: NSManagedObject,
        mapping: NSEntityMapping,
        manager: NSMigrationManager
    ) throws {
        // 由子类实现
    }
    
    // MARK: - Relationship Creation
    
    /// 创建关系
    /// 可以自定义关系创建逻辑
    @objc override open func createRelationships(
        forDestination dInstance: NSManagedObject,
        in mapping: NSEntityMapping,
        manager: NSMigrationManager
    ) throws {
        do {
            try super.createRelationships(forDestination: dInstance, in: mapping, manager: manager)
            
            // 可以在此处添加自定义关系处理
            try customCreateRelationships(forDestination: dInstance, in: mapping, manager: manager)
        } catch {
            logger.error("Error creating relationships for entity \(mapping.name ?? "unknown"): \(error.localizedDescription)")
            throw error
        }
    }
    
    /// 自定义关系创建逻辑
    /// 子类可以重写此方法来提供特定的关系创建逻辑
    open func customCreateRelationships(
        forDestination dInstance: NSManagedObject,
        in mapping: NSEntityMapping,
        manager: NSMigrationManager
    ) throws {
        // 由子类实现
    }
    
    // MARK: - Value Generation
    
    /// 生成目标实例的特定属性值
    /// - Parameters:
    ///   - propertyName: 属性名称
    ///   - source: 源实例
    ///   - manager: 迁移管理器
    /// - Returns: 生成的属性值
    open func value(
        forPropertyName propertyName: String,
        in source: NSManagedObject,
        withMigrationManager manager: NSMigrationManager
    ) throws -> Any? {
        do {
            // 首先尝试自定义值处理
            if let customValue = try customValue(forPropertyName: propertyName, in: source, withMigrationManager: manager) {
                return customValue
            }
            
            // 如果没有自定义值，默认返回nil
            return nil
        } catch {
            logger.error("Error generating value for property \(propertyName): \(error.localizedDescription)")
            throw error
        }
    }
    
    /// 自定义属性值处理
    /// 子类可以重写此方法来提供特定属性的值处理
    open func customValue(
        forPropertyName propertyName: String,
        in source: NSManagedObject,
        withMigrationManager manager: NSMigrationManager
    ) throws -> Any? {
        // 由子类实现，返回nil表示使用默认处理
        return nil
    }
    
    // MARK: - End Migration
    
    /// 迁移结束回调
    /// 可以在迁移完成后执行清理或验证操作
    @objc override open func endInstanceCreation(
        forMapping mapping: NSEntityMapping,
        manager: NSMigrationManager
    ) throws {
        do {
            try super.endInstanceCreation(forMapping: mapping, manager: manager)
            
            // 执行自定义结束处理
            try customEndInstanceCreation(forMapping: mapping, manager: manager)
        } catch {
            logger.error("Error during end instance creation for entity \(mapping.name ?? "unknown"): \(error.localizedDescription)")
            throw error
        }
    }
    
    /// 自定义迁移结束处理
    open func customEndInstanceCreation(
        forMapping mapping: NSEntityMapping,
        manager: NSMigrationManager
    ) throws {
        // 由子类实现
    }
    
    /// 开始验证迁移结果
    /// - Parameters:
    ///   - mapping: 实体映射
    ///   - manager: 迁移管理器
    open func beginValidation(
        forMapping mapping: NSEntityMapping,
        manager: NSMigrationManager
    ) throws {
        do {
            // 执行自定义验证开始处理
            try customBeginValidation(forMapping: mapping, manager: manager)
        } catch {
            logger.error("Error during begin validation for entity \(mapping.name ?? "unknown"): \(error.localizedDescription)")
            throw error
        }
    }
    
    /// 自定义验证开始处理
    open func customBeginValidation(
        forMapping mapping: NSEntityMapping,
        manager: NSMigrationManager
    ) throws {
        // 由子类实现
    }
    
    /// 结束验证迁移结果
    /// - Parameters:
    ///   - mapping: 实体映射
    ///   - manager: 迁移管理器
    open func endValidation(
        forMapping mapping: NSEntityMapping,
        manager: NSMigrationManager
    ) throws {
        do {
            // 执行自定义验证结束处理
            try customEndValidation(forMapping: mapping, manager: manager)
        } catch {
            logger.error("Error during end validation for entity \(mapping.name ?? "unknown"): \(error.localizedDescription)")
            throw error
        }
    }
    
    /// 自定义验证结束处理
    open func customEndValidation(
        forMapping mapping: NSEntityMapping,
        manager: NSMigrationManager
    ) throws {
        // 由子类实现
    }
    
    /// 执行自定义查询
    /// - Parameters:
    ///   - fetchRequest: 查询请求
    ///   - context: 上下文
    /// - Returns: 查询结果
    open func performCustomQuery(
        _ fetchRequest: NSPersistentStoreRequest,
        in context: NSManagedObjectContext
    ) throws -> Any {
        do {
            // 首先尝试自定义查询处理
            if let result = try customPerformQuery(fetchRequest, in: context) {
                return result
            }
            
            // 如果没有自定义处理，抛出错误
            throw NSError(domain: "EntityMigrationPolicy", code: 404, userInfo: [NSLocalizedDescriptionKey: "Custom query not handled"])
        } catch {
            logger.error("Error performing custom query: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// 自定义查询处理
    open func customPerformQuery(
        _ fetchRequest: NSPersistentStoreRequest,
        in context: NSManagedObjectContext
    ) throws -> Any? {
        // 由子类实现，返回nil表示使用默认处理
        return nil
    }
}

/// Document实体迁移策略
/// 处理Document实体特定的迁移逻辑
public class DocumentEntityMigrationPolicy: EntityMigrationPolicy {
    
    public override func customMigrate(
        source: NSManagedObject,
        destination: NSManagedObject,
        mapping: NSEntityMapping,
        manager: NSMigrationManager
    ) throws {
        // 迁移基本属性
        migrateBasicAttributes(from: source, to: destination)
        
        // 处理版本字段
        ensureVersionField(for: destination)
        
        // 处理元数据
        migrateMetadata(from: source, to: destination)
    }
    
    /// 迁移基本属性
    private func migrateBasicAttributes(from source: NSManagedObject, to destination: NSManagedObject) {
        // 处理基本字段
        if let title = source.value(forKey: "title") as? String {
            destination.setValue(title, forKey: "title")
        }
        
        if let content = source.value(forKey: "content") as? String {
            destination.setValue(content, forKey: "content")
        }
        
        if let createdAt = source.value(forKey: "createdAt") as? Date {
            destination.setValue(createdAt, forKey: "createdAt")
        }
        
        // 确保updatedAt字段存在且有值
        if let updatedAt = source.value(forKey: "updatedAt") as? Date {
            destination.setValue(updatedAt, forKey: "updatedAt")
        } else if let createdAt = source.value(forKey: "createdAt") as? Date {
            // 如果没有updatedAt，使用createdAt
            destination.setValue(createdAt, forKey: "updatedAt")
        } else {
            // 如果都没有，使用当前时间
            destination.setValue(Date(), forKey: "updatedAt")
        }
    }
    
    /// 确保版本字段存在
    private func ensureVersionField(for destination: NSManagedObject) {
        // 检查是否有version字段
        if destination.entity.attributesByName["version"] != nil {
            // 如果目标实体有version属性但没有值，设置为1
            if destination.value(forKey: "version") == nil {
                destination.setValue(1, forKey: "version")
            }
        }
    }
    
    /// 迁移元数据
    private func migrateMetadata(from source: NSManagedObject, to destination: NSManagedObject) {
        // 处理元数据字段
        if destination.entity.attributesByName["metadata"] != nil {
            var metadata: [String: Any] = [:]
            
            // 从源对象提取元数据
            if let existingMetadata = source.value(forKey: "metadata") as? [String: Any] {
                metadata = existingMetadata
            }
            
            // 在元数据中添加迁移信息
            metadata["migrated"] = true
            metadata["migrationDate"] = Date()
            
            // 设置元数据
            destination.setValue(metadata, forKey: "metadata")
        }
    }
}

/// Slide实体迁移策略
/// 处理Slide实体特定的迁移逻辑
public class SlideEntityMigrationPolicy: EntityMigrationPolicy {
    
    public override func customMigrate(
        source: NSManagedObject,
        destination: NSManagedObject,
        mapping: NSEntityMapping,
        manager: NSMigrationManager
    ) throws {
        // 迁移基本属性
        if let title = source.value(forKey: "title") as? String {
            destination.setValue(title, forKey: "title")
        }
        
        if let content = source.value(forKey: "content") as? String {
            destination.setValue(content, forKey: "content")
        }
        
        if let orderIndex = source.value(forKey: "orderIndex") as? Int {
            destination.setValue(orderIndex, forKey: "orderIndex")
        }
        
        // 处理内容类型
        migrateContentType(from: source, to: destination)
        
        // 处理样式信息
        migrateStyleInformation(from: source, to: destination)
    }
    
    /// 迁移内容类型
    private func migrateContentType(from source: NSManagedObject, to destination: NSManagedObject) {
        // 检查新的contentType字段是否存在
        if destination.entity.attributesByName["contentType"] != nil {
            // 尝试从源对象获取contentType
            if let contentType = source.value(forKey: "contentType") as? String {
                destination.setValue(contentType, forKey: "contentType")
            } else {
                // 如果源对象没有contentType，根据内容推断
                if let content = source.value(forKey: "content") as? String {
                    if content.hasPrefix("{") && content.hasSuffix("}") {
                        // 可能是JSON
                        destination.setValue("json", forKey: "contentType")
                    } else if content.hasPrefix("<") && content.hasSuffix(">") {
                        // 可能是XML或HTML
                        destination.setValue("html", forKey: "contentType")
                    } else {
                        // 默认为纯文本
                        destination.setValue("text", forKey: "contentType")
                    }
                } else {
                    // 默认为纯文本
                    destination.setValue("text", forKey: "contentType")
                }
            }
        }
    }
    
    /// 迁移样式信息
    private func migrateStyleInformation(from source: NSManagedObject, to destination: NSManagedObject) {
        // 检查style字段是否存在
        if destination.entity.attributesByName["style"] != nil {
            var style: [String: Any] = [:]
            
            // 尝试从源对象获取样式相关信息
            if let backgroundColor = source.value(forKey: "backgroundColor") as? String {
                style["backgroundColor"] = backgroundColor
            }
            
            if let textColor = source.value(forKey: "textColor") as? String {
                style["textColor"] = textColor
            }
            
            if let fontSize = source.value(forKey: "fontSize") as? Int {
                style["fontSize"] = fontSize
            }
            
            // 设置样式字段
            if !style.isEmpty {
                destination.setValue(style, forKey: "style")
            }
        }
    }
}

/// 元素实体迁移策略
/// 处理Element实体特定的迁移逻辑
public class ElementEntityMigrationPolicy: EntityMigrationPolicy {
    
    public override func customMigrate(
        source: NSManagedObject,
        destination: NSManagedObject,
        mapping: NSEntityMapping,
        manager: NSMigrationManager
    ) throws {
        // 迁移基本属性
        if let type = source.value(forKey: "type") as? String {
            destination.setValue(type, forKey: "type")
        }
        
        if let content = source.value(forKey: "content") as? String {
            destination.setValue(content, forKey: "content")
        }
        
        // 处理位置和大小信息
        migratePositionAndSize(from: source, to: destination)
        
        // 处理样式信息
        migrateStyleInformation(from: source, to: destination)
    }
    
    /// 迁移位置和大小信息
    private func migratePositionAndSize(from source: NSManagedObject, to destination: NSManagedObject) {
        // 提取位置信息
        let x = source.value(forKey: "x") as? Double ?? 0
        let y = source.value(forKey: "y") as? Double ?? 0
        let width = source.value(forKey: "width") as? Double ?? 0
        let height = source.value(forKey: "height") as? Double ?? 0
        
        // 检查是否有frame字段
        if destination.entity.attributesByName["frame"] != nil {
            // 创建frame字典
            let frame: [String: Double] = [
                "x": x,
                "y": y,
                "width": width,
                "height": height
            ]
            
            // 设置frame
            destination.setValue(frame, forKey: "frame")
        } else {
            // 如果没有frame字段，单独设置各个属性
            destination.setValue(x, forKey: "x")
            destination.setValue(y, forKey: "y")
            destination.setValue(width, forKey: "width")
            destination.setValue(height, forKey: "height")
        }
    }
    
    /// 迁移样式信息
    private func migrateStyleInformation(from source: NSManagedObject, to destination: NSManagedObject) {
        // 检查style字段是否存在
        if destination.entity.attributesByName["style"] != nil {
            var style: [String: Any] = [:]
            
            // 尝试从源对象获取样式相关信息
            if let color = source.value(forKey: "color") as? String {
                style["color"] = color
            }
            
            if let backgroundColor = source.value(forKey: "backgroundColor") as? String {
                style["backgroundColor"] = backgroundColor
            }
            
            if let borderColor = source.value(forKey: "borderColor") as? String {
                style["borderColor"] = borderColor
            }
            
            if let borderWidth = source.value(forKey: "borderWidth") as? Double {
                style["borderWidth"] = borderWidth
            }
            
            if let opacity = source.value(forKey: "opacity") as? Double {
                style["opacity"] = opacity
            }
            
            if let fontSize = source.value(forKey: "fontSize") as? Double {
                style["fontSize"] = fontSize
            }
            
            // 设置样式字段
            if !style.isEmpty {
                destination.setValue(style, forKey: "style")
            }
        }
    }
} 