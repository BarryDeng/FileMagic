//
//  ContentView.swift
//  FileMagic
//
//  Created by 邓理 on 4/6/25.
//


import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var viewModel = ArchiveViewModel()
    @State private var isFilePickerShown = false
    @State private var isArchivePickerShown = false
    @State private var isShowingShareSheet = false
    @State private var sharedURL: URL?
    @State private var selectedTab = 0 // 0 表示压缩，1 表示解压
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 顶部标签选择器
                HStack(spacing: 0) {
                    TabButton(title: "压缩", systemImage: "doc.zipper", isSelected: selectedTab == 0) {
                        selectedTab = 0
                    }
                    
                    TabButton(title: "解压", systemImage: "folder", isSelected: selectedTab == 1) {
                        selectedTab = 1
                    }
                }
                .padding(.horizontal)
                
                // 显示当前状态（压缩中、解压中等）
                statusView
                    .padding(.top, 10)
                
                // 主内容区域 - 根据选项卡显示不同内容
                if selectedTab == 0 {
                    compressionView
                } else {
                    decompressionView
                }
                
                Spacer()
                
                // 底部操作按钮
                bottomActionButtons
                    .padding()
            }
            .padding(.top)
            .navigationTitle("7z 压缩工具")
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .sheet(isPresented: $isFilePickerShown) {
                DocumentPicker(
                    isPresented: $isFilePickerShown,
                    supportedTypes: [UTType.item],
                    allowsMultipleSelection: true
                ) { urls in
                    viewModel.selectedFiles = urls
                    
                    // 自动开始压缩
                    Task {
                        await viewModel.compressFiles()
                    }
                }
            }
            .sheet(isPresented: $isArchivePickerShown) {
                DocumentPicker(
                    isPresented: $isArchivePickerShown,
                    supportedTypes: [UTType.archive],
                    allowsMultipleSelection: false
                ) { urls in
                    guard let url = urls.first else { return }
                    
                    // 自动开始解压
                    Task {
                        await viewModel.decompressFile(url: url)
                    }
                }
            }
            .sheet(isPresented: $isShowingShareSheet) {
                if let url = sharedURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }
    
    // 压缩面板
    private var compressionView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 压缩设置面板
                VStack(alignment: .leading, spacing: 16) {
                    Text("压缩设置")
                        .font(.headline)
                    
                    VStack(spacing: 12) {
                        // 压缩级别
                        HStack {
                            Text("压缩级别:")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(viewModel.compressionLevel)")
                                .font(.headline)
                                .frame(width: 30)
                        }
                        
                        Slider(value: Binding(
                            get: { Float(viewModel.compressionLevel) },
                            set: { viewModel.compressionLevel = UInt8($0) }
                        ), in: 1...9, step: 1)
                        
                        HStack {
                            Text("更快")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("更小")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Divider()
                    
                    // 密码设置
                    VStack(alignment: .leading, spacing: 12) {
                        Text("加密选项")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Image(systemName: "lock")
                                .foregroundColor(.secondary)
                            TextField("密码 (可选)", text: $viewModel.password)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        if !viewModel.password.isEmpty {
                            Toggle("加密文件列表", isOn: $viewModel.encryptHeader)
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // 选择的文件列表
                if !viewModel.selectedFiles.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("已选择的文件")
                                .font(.headline)
                            Spacer()
                            Button(action: {
                                viewModel.clearSelectedFiles()
                            }) {
                                Text("清除")
                                    .font(.subheadline)
                                    .foregroundColor(.red)
                            }
                        }
                        
                        Divider()
                        
                        ForEach(viewModel.selectedFiles, id: \.self) { file in
                            HStack {
                                Image(systemName: "doc")
                                    .foregroundColor(.blue)
                                Text(file.lastPathComponent)
                                    .lineLimit(1)
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
    
    // 解压面板
    private var decompressionView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 解压密码
                VStack(alignment: .leading, spacing: 16) {
                    Text("解压设置")
                        .font(.headline)
                    
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "key")
                                .foregroundColor(.secondary)
                            TextField("输入密码 (如果需要)", text: $viewModel.password)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // 解压后的文件列表
                if !viewModel.extractedFiles.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("解压的文件")
                            .font(.headline)
                        
                        Divider()
                        
                        ForEach(viewModel.extractedFiles, id: \.self) { file in
                            HStack {
                                Image(systemName: file.hasDirectoryPath ? "folder" : "doc")
                                    .foregroundColor(file.hasDirectoryPath ? .yellow : .blue)
                                Text(file.lastPathComponent)
                                    .lineLimit(1)
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
    
    private var statusView: some View {
        VStack {
            statusContent
        }
        .frame(minHeight: 60)
    }
    
    // 状态视图
    @ViewBuilder
    private var statusContent: some View {
        switch viewModel.state {
        case .idle:
            EmptyView()
        case .compressing:
            ProgressWithText(text: "正在压缩...", value: Double(viewModel.progress))
        case .decompressing:
            ProgressWithText(text: "正在解压...", value: Double(viewModel.progress))
        case .listing:
            ProgressWithText(text: "正在列出文件...", value: Double(viewModel.progress))
        case .success(let message):
            VStack(spacing: 10) {
                Text(message)
                    .foregroundColor(.green)
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                
                if let url = getLastURL(from: message) {
                    Button(action: {
                        sharedURL = url
                        isShowingShareSheet = true
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("分享文件")
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
            }
            .padding(.horizontal)
        case .error(let message):
            Text(message)
                .foregroundColor(.white)
                .padding()
                .background(Color.red.opacity(0.8))
                .cornerRadius(8)
                .padding(.horizontal)
        }
    }
    
    // 底部操作按钮
    private var bottomActionButtons: some View {
        HStack(spacing: 20) {
            if selectedTab == 0 {
                // 压缩按钮
                ActionButton(
                    icon: "doc.zipper",
                    title: "选择并压缩",
                    action: { isFilePickerShown = true },
                    isDisabled: viewModel.state == .compressing || viewModel.state == .decompressing
                )
            } else {
                // 解压按钮
                ActionButton(
                    icon: "folder",
                    title: "选择并解压",
                    action: { isArchivePickerShown = true },
                    isDisabled: viewModel.state == .compressing || viewModel.state == .decompressing
                )
            }
        }
    }
    
    // 从成功消息中提取URL
    private func getLastURL(from message: String) -> URL? {
        if let startRange = message.range(of: ": ") {
            let fileNameSubstring = message[startRange.upperBound...]
            let fileName = String(fileNameSubstring)
            
            // 构建URL
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            if message.contains("压缩完成") {
                return documentsDirectory.appendingPathComponent(fileName)
            } else if message.contains("解压完成") {
                return documentsDirectory.appendingPathComponent(fileName)
            }
        }
        return nil
    }
}

// 自定义标签按钮
struct TabButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 20))
                Text(title)
                    .font(.subheadline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            .foregroundColor(isSelected ? .blue : .primary)
            .cornerRadius(10)
            .overlay(
                isSelected ?
                    Rectangle()
                        .frame(height: 2)
                        .foregroundColor(.blue)
                        .offset(y: 17)
                    : nil,
                alignment: .bottom
            )
        }
    }
}

// 操作按钮组件
struct ActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    let isDisabled: Bool
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(title)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(isDisabled ? Color.gray.opacity(0.3) : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            .shadow(color: isDisabled ? .clear : Color.blue.opacity(0.3), radius: 5, x: 0, y: 2)
        }
        .disabled(isDisabled)
    }
}

// 进度条带文字组件
struct ProgressWithText: View {
    let text: String
    let value: Double
    
    var body: some View {
        VStack(spacing: 8) {
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .frame(width: geometry.size.width, height: 8)
                        .opacity(0.1)
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .frame(width: min(CGFloat(value) * geometry.size.width, geometry.size.width), height: 8)
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                        .animation(.linear, value: value)
                }
            }
            .frame(height: 8)
            
            // 百分比显示
            Text("\(Int(value * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
    }
}

#Preview {
    ContentView()
}
