# CoreData 迁移架构图表

本文档使用 Mermaid 图表展示 CoreData 迁移架构中各组件之间的关系和数据流。

## 组件关系图

```mermaid
graph TD
    User[用户/应用] --> CDM[CoreDataMigrationManager]
    CDM --> PR[MigrationProgressReporter]
    CDM --> BM[BackupManager]
    CDM --> P[MigrationPlanner]
    CDM --> E[MigrationExecutor]
    
    BM --> RM[CoreDataResourceManager]
    P --> RM
    P --> MM[CoreDataModelVersionManager]
    E --> P
    
    MM --> RM
    
    classDef main fill:#f96,stroke:#333,stroke-width:2px;
    classDef component fill:#bbf,stroke:#33c,stroke-width:1px;
    classDef resource fill:#bfb,stroke:#3c3,stroke-width:1px;
    
    class CDM main;
    class PR,BM,P,E,MM component;
    class RM resource;
    
    subgraph 迁移流程
        direction TB
        U1[用户请求] --> |1. 请求迁移| MIG
        MIG[迁移管理器] --> |2. 检查是否需要迁移| PLN
        PLN[迁移规划器] --> |3a. 不需要迁移| MIG
        PLN --> |3b. 需要迁移| BKP
        BKP[备份管理器] --> |4. 创建备份| EXE
        EXE[迁移执行器] --> |5. 执行迁移步骤| REP
        REP[进度报告器] --> |6. 更新进度| MIG
        MIG --> |7. 迁移完成| U1
    end
```

## 数据流图

```mermaid
flowchart TD
    Start([开始]) --> Check{需要迁移?}
    Check -- 是 --> Backup[创建数据库备份]
    Check -- 否 --> End([结束])
    
    Backup --> CreatePlan[创建迁移计划]
    CreatePlan --> InitProgress[初始化进度报告]
    InitProgress --> MigrationLoop[执行迁移步骤]
    
    MigrationLoop --> UpdateProgress[更新进度]
    UpdateProgress --> CheckComplete{完成所有步骤?}
    CheckComplete -- 否 --> MigrationLoop
    CheckComplete -- 是 --> Validate[验证迁移结果]
    
    Validate --> Success{迁移成功?}
    Success -- 是 --> Cleanup[清理临时文件]
    Success -- 否 --> Restore[从备份恢复]
    
    Cleanup --> End
    Restore --> End
    
    style Start fill:#7f7,stroke:#484,stroke-width:2px
    style End fill:#7f7,stroke:#484,stroke-width:2px
    style Check fill:#ff7,stroke:#884,stroke-width:2px
    style Success fill:#ff7,stroke:#884,stroke-width:2px
    style CheckComplete fill:#ff7,stroke:#884,stroke-width:2px
    style Restore fill:#f77,stroke:#844,stroke-width:2px
```

## 组件职责表

| 组件 | 主要职责 | 与其他组件的关系 |
|------|---------|-----------------|
| CoreDataMigrationManager | 协调整个迁移过程 | 使用其他所有组件 |
| MigrationProgressReporter | 报告迁移进度 | 被 MigrationManager 使用 |
| BackupManager | 管理备份和恢复 | 使用 ResourceManager，被 MigrationManager 使用 |
| MigrationPlanner | 规划迁移路径 | 使用 ResourceManager 和 ModelVersionManager，被 MigrationManager 和 Executor 使用 |
| MigrationExecutor | 执行迁移步骤 | 使用 MigrationPlanner，被 MigrationManager 使用 |
| CoreDataModelVersionManager | 管理模型版本 | 使用 ResourceManager，被 MigrationPlanner 使用 |
| CoreDataResourceManager | 管理 CoreData 资源 | 被其他组件使用 |

## CoreDataResourceManager 的资源查找算法

```mermaid
flowchart TD
    Start([开始查找资源]) --> CheckPrimary[检查主要 Bundle]
    CheckPrimary --> FindInPrimary{在主要 Bundle 中找到?}
    
    FindInPrimary -- 是 --> ReturnResource([返回资源])
    FindInPrimary -- 否 --> CheckAdditional[检查额外的 Bundle]
    
    CheckAdditional --> FindInAdditional{在额外 Bundle 中找到?}
    FindInAdditional -- 是 --> ReturnResource
    FindInAdditional -- 否 --> CheckModule[检查模块 Bundle]
    
    CheckModule --> FindInModule{在模块 Bundle 中找到?}
    FindInModule -- 是 --> ReturnResource
    FindInModule -- 否 --> CheckAlternateNames[检查替代命名格式]
    
    CheckAlternateNames --> FindAlternate{找到替代命名的资源?}
    FindAlternate -- 是 --> ReturnResource
    FindAlternate -- 否 --> ReturnNil([返回 nil])
    
    style Start fill:#7f7,stroke:#484,stroke-width:2px
    style ReturnResource fill:#7f7,stroke:#484,stroke-width:2px
    style ReturnNil fill:#f77,stroke:#844,stroke-width:2px
```

## 总结

CoreData 迁移架构采用了模块化的设计，明确划分了各组件的职责，确保了迁移过程的安全性和可靠性。CoreDataResourceManager 作为基础组件，通过灵活的资源查找算法，支持在模块化环境中可靠地工作。