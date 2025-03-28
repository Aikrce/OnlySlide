# 优化架构设计

## 架构总览

以下是我们新架构的总体设计图，展示了主要组件及其关系：

```mermaid
graph TD
    subgraph "依赖注入系统"
        DI[DependencyRegistry] --> |提供| F1[Factories]
        F1 --> |创建| Components[组件实例]
        DI --> |解析| Components
    end
    
    subgraph "核心组件"
        subgraph "错误处理系统"
            EH[EnhancedErrorHandler] --> |使用| RS[EnhancedRecoveryService]
            EH --> |添加| Context[ErrorContext]
            RS --> |注册| Strategies[RecoveryStrategies]
        end
        
        subgraph "迁移系统"
            MM[EnhancedMigrationManager] --> |使用| VM[EnhancedModelVersionManager]
            VM --> |查找| Models[NSManagedObjectModel]
            VM --> |创建| Mappings[NSMappingModel]
        end
        
        subgraph "同步系统"
            SM[EnhancedSyncManager] --> |使用| SS[SyncService]
            SM --> |使用| SA[StoreAccess]
            SM --> |报告| PR[ProgressReporter]
        end
    end
    
    subgraph "并发安全"
        TS[ThreadSafe属性包装器] --> |应用于| States[状态变量]
        CD[ConcurrentDictionary] --> |安全存储| Data[共享数据]
        CA[CoreDataContextAccessor] --> |隔离访问| Context[数据上下文]
        IPC[IsolatedPersistentContainer] --> |管理| PersistentStore[持久化存储]
    end
    
    subgraph "适配层"
        Adapters[适配器] --> |包装| NewComponents[新组件]
        Adapters --> |兼容| Legacy[旧API]
    end
    
    Components --> |包含| EH
    Components --> |包含| MM
    Components --> |包含| SM
    
    SM --> |使用| TS
    MM --> |使用| TS
    EH --> |使用| CD
```

## 组件依赖关系

```mermaid
flowchart LR
    subgraph "应用层"
        App[应用代码] --> |使用| DI[DependencyRegistry]
    end
    
    subgraph "服务层"
        DI --> |解析| EH[EnhancedErrorHandler]
        DI --> |解析| MM[EnhancedMigrationManager]
        DI --> |解析| VM[EnhancedModelVersionManager]
        DI --> |解析| SM[EnhancedSyncManager]
    end
    
    subgraph "核心层"
        EH --> |依赖| RS[EnhancedRecoveryService]
        MM --> |依赖| VM
        SM --> |依赖| SS[SyncService]
        SM --> |依赖| SA[StoreAccess]
        SM --> |依赖| PR[ProgressReporter]
    end
    
    subgraph "基础设施层"
        EH & RS & MM & VM & SM & SS & SA & PR --> |使用| CS[并发安全工具]
        CS --> TS[ThreadSafe]
        CS --> CD[ConcurrentDictionary]
        CS --> IPC[IsolatedPersistentContainer]
    end
```

## 数据流

```mermaid
sequenceDiagram
    participant App as 应用
    participant DI as DependencyRegistry
    participant SM as EnhancedSyncManager
    participant SS as SyncService
    participant SA as StoreAccess
    participant PR as ProgressReporter
    
    App->>DI: 解析 SyncManager
    DI-->>App: 返回 EnhancedSyncManager
    App->>SM: sync(options)
    SM->>PR: 报告准备状态
    
    par 并行获取数据
        SM->>SS: fetchDataFromServer()
        SS-->>SM: 返回远程数据
    and
        SM->>SA: readDataFromStore()
        SA-->>SM: 返回本地数据
    end
    
    SM->>SM: 检查数据变化
    alt 数据有变化
        SM->>SS: resolveConflicts(local, remote, strategy)
        SS-->>SM: 返回合并数据
        SM->>SA: writeDataToStore(mergedData)
        SA-->>SM: 保存成功
        SM->>SS: uploadDataToServer(mergedData)
        SS-->>SM: 上传成功
    end
    
    SM->>PR: 报告完成状态
    SM-->>App: 返回同步结果
```

## 迁移策略

```mermaid
graph LR
    subgraph "旧架构"
        OS[旧单例] --> |直接访问| OC[旧组件]
    end
    
    subgraph "过渡阶段"
        OS --> |通过适配器访问| Adapter[适配器]
        Adapter --> |包装| NC1[新组件]
        NA[新API] --> |直接使用| NC2[新组件]
    end
    
    subgraph "新架构"
        DI[DependencyRegistry] --> |解析| NC3[新组件]
        NA2[新API] --> |通过依赖注入| DI
    end
    
    OS -.-> |逐步淘汰| NA
    OC -.-> |逐步替换| NC1
    Adapter -.-> |最终移除| DI
    NC1 & NC2 -.-> |统一为| NC3
```

## 并发安全性设计

```mermaid
graph TD
    subgraph "并发安全原则"
        direction LR
        P1[使用Swift协议隔离] --> Design
        P2[优先值类型] --> Design
        P3[Actor隔离] --> Design
        P4[避免共享可变状态] --> Design
        Design[安全设计]
    end
    
    subgraph "工具使用"
        TS[ThreadSafe属性包装器] --> |应用于| SV[状态变量]
        CD[ConcurrentDictionary] --> |替代| Dict[普通Dictionary]
        IPC[IsolatedPersistentContainer] --> |替代| PC[PersistentContainer]
        RAP[ResourceAccessProtocol] --> |抽象| RA[资源访问]
    end
    
    subgraph "迁移方法"
        SM1[识别@preconcurrency使用点] --> SM2[应用并发安全工具]
        SM2 --> SM3[编写并发测试]
        SM3 --> SM4[验证并回归测试]
        SM4 --> SM5[移除@preconcurrency]
    end
```

## 设计原则

1. **依赖注入**: 所有组件通过依赖注入获取依赖，而不是直接创建或使用单例
2. **协议抽象**: 使用协议定义组件接口，实现可替换性和可测试性
3. **值类型优先**: 优先使用结构体而非类，减少共享状态和内存管理问题
4. **并发安全**: 使用专门的并发工具确保线程安全，避免数据竞争
5. **适配器模式**: 通过适配器提供向后兼容性，实现渐进式迁移
6. **单一职责**: 每个组件只负责一项功能，避免大型多功能类 