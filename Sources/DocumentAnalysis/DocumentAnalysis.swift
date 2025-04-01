// DocumentAnalysis.swift
// OnlySlide 文档分析模块

// 导出公共API
@_exported import PDFKit

// 核心组件
public typealias DocumentAnalysisCore = DocumentAnalysisEngine

// 导出UI组件
public typealias AnalysisView = DocumentAnalysisView
public typealias ResultView = DocumentAnalysisResultView
public typealias SavedResultsView = SavedResultsListView

// 导出导出组件
public typealias PDFExport = PDFExporter
public typealias ExportManager = DocumentExportManager 