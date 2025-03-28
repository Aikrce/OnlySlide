#!/bin/bash

# 创建备份目录
mkdir -p Backups/Migration
mkdir -p Backups/Sync
mkdir -p Backups/Concurrency

# 备份文件
cp Sources/CoreDataModule/Migration/MigrationDomainTypes.swift Backups/Migration/
cp Sources/CoreDataModule/Migration/EnhancedMigrationManager.swift Backups/Migration/
cp Sources/CoreDataModule/Migration/Models/MigrationState.swift Backups/Migration/ 2>/dev/null

cp Sources/CoreDataModule/Sync/EnhancedSyncManager.swift Backups/Sync/
cp Sources/CoreDataModule/Sync/CoreDataSyncManager.swift Backups/Sync/

cp Sources/CoreDataModule/Concurrency/ConcurrencySafety.swift Backups/Concurrency/
cp Sources/CoreDataModule/Utils/ThreadSafeFix.swift Backups/Concurrency/ 2>/dev/null
cp Sources/CoreDataModule/Concurrency/ThreadSafeFix.swift Backups/Concurrency/ 2>/dev/null

# 清理临时文件
rm -f Sources/CoreDataModule/Migration/*Fix*.swift*
rm -f Sources/CoreDataModule/Sync/*Fix*.swift*
rm -f Sources/CoreDataModule/Concurrency/*Fix*.swift*
rm -f Sources/CoreDataModule/Utils/*Fix*.swift*

# 清理构建文件夹
rm -rf .build
rm -rf DerivedData

echo "清理完成。请在Xcode中清理项目缓存，然后重新构建。" 