// AdaptiveComponents.swift
// 提供常用UI组件的跨平台实现

import SwiftUI

#if os(iOS) || os(tvOS)
import UIKit
#endif

// MARK: - 自适应按钮
public struct AdaptiveButton: View {
    private let title: String
    private let icon: String?
    private let action: () -> Void
    private let style: ButtonStyleType
    
    public enum ButtonStyleType {
        case primary, secondary, destructive, plain
    }
    
    public init(
        _ title: String,
        icon: String? = nil,
        style: ButtonStyleType = .primary,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            HStack {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                }
                
                Text(title)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, style == .plain ? 0 : 12)
            .padding(.vertical, style == .plain ? 0 : 8)
        }
        .applyButtonStyle(style)
    }
}

// MARK: - 按钮样式扩展
extension View {
    @ViewBuilder
    func applyButtonStyle(_ style: AdaptiveButton.ButtonStyleType) -> some View {
        switch style {
        case .primary:
            #if os(macOS)
            self.buttonStyle(.borderedProminent)
            #else
            self.buttonStyle(.borderedProminent)
            #endif
        case .secondary:
            #if os(macOS)
            self.buttonStyle(.bordered)
            #else
            self.buttonStyle(.bordered)
            #endif
        case .destructive:
            #if os(macOS)
            self.buttonStyle(.bordered)
                .foregroundColor(.red)
            #else
            self.buttonStyle(.bordered)
                .foregroundColor(.red)
            #endif
        case .plain:
            #if os(macOS)
            self.buttonStyle(.plain)
            #else
            self.buttonStyle(.plain)
            #endif
        }
    }
}

// MARK: - 自适应文本输入
public struct AdaptiveTextField: View {
    private let title: String
    @Binding private var text: String
    private let placeholder: String
    private let keyboardType: KeyboardType
    private let onCommit: (() -> Void)?
    
    // 定义跨平台的键盘类型
    public enum KeyboardType {
        case `default`, email, url, number, phone, search
    }
    
    public init(
        _ title: String,
        text: Binding<String>,
        placeholder: String = "",
        keyboardType: KeyboardType = .default,
        onCommit: (() -> Void)? = nil
    ) {
        self.title = title
        self._text = text
        self.placeholder = placeholder
        self.keyboardType = keyboardType
        self.onCommit = onCommit
    }
    
    public var body: some View {
        VStack(alignment: .leading) {
            if !title.isEmpty {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            #if os(macOS)
            TextField(placeholder, text: $text, onCommit: {
                onCommit?()
            })
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: .infinity)
            #else
            TextField(placeholder, text: $text)
                #if os(iOS) || os(tvOS)
                .keyboardType(uiKeyboardType)
                #endif
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .onSubmit {
                    onCommit?()
                }
            #endif
        }
    }
    
    #if os(iOS) || os(tvOS)
    // 转换为UI键盘类型
    private var uiKeyboardType: UIKeyboardType {
        switch keyboardType {
        case .default:
            return .default
        case .email:
            return .emailAddress
        case .url:
            return .URL
        case .number:
            return .numberPad
        case .phone:
            return .phonePad
        case .search:
            return .webSearch
        }
    }
    #endif
}

// MARK: - 自适应区域选择器
public struct AdaptiveSegmentedPicker<T: Hashable>: View {
    @Binding private var selection: T
    private let options: [T]
    private let labels: [String]
    
    public init(selection: Binding<T>, options: [T], labels: [String]) {
        self._selection = selection
        self.options = options
        self.labels = labels
    }
    
    public var body: some View {
        Picker("", selection: $selection) {
            ForEach(0..<options.count, id: \.self) { index in
                Text(labels[index]).tag(options[index])
            }
        }
        #if os(macOS)
        .pickerStyle(.segmented)
        .frame(maxWidth: 300)
        #else
        .pickerStyle(.segmented)
        .padding(.horizontal)
        #endif
    }
}

// MARK: - 自适应列表项
public struct AdaptiveListItem<Content: View>: View {
    private let content: Content
    private let onTap: (() -> Void)?
    private let accessories: [ListItemAccessory]
    
    public enum ListItemAccessory {
        case disclosure
        case info(action: () -> Void)
        case delete(action: () -> Void)
        case custom(icon: String, action: () -> Void)
    }
    
    public init(
        @ViewBuilder content: () -> Content,
        accessories: [ListItemAccessory] = [],
        onTap: (() -> Void)? = nil
    ) {
        self.content = content()
        self.accessories = accessories
        self.onTap = onTap
    }
    
    public var body: some View {
        #if os(macOS)
        HStack {
            content
            
            Spacer()
            
            // 添加操作按钮
            ForEach(0..<accessories.count, id: \.self) { index in
                accessoryView(for: accessories[index])
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        #else
        HStack {
            content
            
            Spacer()
            
            // 添加操作按钮
            ForEach(0..<accessories.count, id: \.self) { index in
                accessoryView(for: accessories[index])
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
        .padding(.vertical, 8)
        #endif
    }
    
    @ViewBuilder
    private func accessoryView(for accessory: ListItemAccessory) -> some View {
        switch accessory {
        case .disclosure:
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        case .info(let action):
            Button(action: action) {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
        case .delete(let action):
            Button(action: action) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        case .custom(let icon, let action):
            Button(action: action) {
                Image(systemName: icon)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - 自适应工具栏
public struct AdaptiveToolbar<Content: View>: View {
    private let content: Content
    private let position: Position
    
    public enum Position {
        case top, bottom, leading, trailing
    }
    
    public init(position: Position = .top, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.position = position
    }
    
    public var body: some View {
        Group {
            #if os(macOS)
            switch position {
            case .top:
                VStack(spacing: 0) {
                    toolbarContent
                    Divider()
                }
            case .bottom:
                VStack(spacing: 0) {
                    Divider()
                    toolbarContent
                }
            case .leading:
                HStack(spacing: 0) {
                    toolbarContent
                    Divider()
                }
            case .trailing:
                HStack(spacing: 0) {
                    Divider()
                    toolbarContent
                }
            }
            #else
            // iOS中依据位置，适当调整工具栏样式
            switch position {
            case .top:
                VStack(spacing: 0) {
                    toolbarContent
                    Divider()
                }
            case .bottom:
                VStack(spacing: 0) {
                    Divider()
                    toolbarContent
                }
                .background(Color(UIColor.secondarySystemBackground))
            case .leading, .trailing:
                // iOS不常用侧边工具栏，但仍提供支持
                if position == .leading {
                    HStack(spacing: 0) {
                        toolbarContent
                            .frame(width: 44)
                        Divider()
                    }
                } else {
                    HStack(spacing: 0) {
                        Divider()
                        toolbarContent
                            .frame(width: 44)
                    }
                }
                .background(Color(UIColor.secondarySystemBackground))
            }
            #endif
        }
    }
    
    private var toolbarContent: some View {
        content
            .padding(.horizontal, position == .leading || position == .trailing ? 8 : 12)
            .padding(.vertical, position == .top || position == .bottom ? 8 : 12)
    }
}

// MARK: - 自适应分割视图
public struct AdaptiveSplitView<Leading: View, Trailing: View>: View {
    private let leading: Leading
    private let trailing: Trailing
    @Binding private var position: Double
    
    public init(position: Binding<Double> = .constant(0.3), 
                @ViewBuilder leading: () -> Leading, 
                @ViewBuilder trailing: () -> Trailing) {
        self._position = position
        self.leading = leading()
        self.trailing = trailing()
    }
    
    public var body: some View {
        #if os(macOS)
        HSplitView {
            leading
            trailing
        }
        #else
        GeometryReader { geometry in
            HStack(spacing: 0) {
                leading
                    .frame(width: geometry.size.width * position)
                
                // 拖动手柄
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 1)
                    .overlay(
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: 10)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        let newPosition = (position * geometry.size.width + value.translation.width) / geometry.size.width
                                        self.position = min(max(0.1, newPosition), 0.9)
                                    }
                            )
                    )
                
                trailing
                    .frame(width: geometry.size.width * (1 - position) - 1)
            }
        }
        #endif
    }
} 