//
//  ContentView.swift
//  FileMagic
//
//  Created by 邓理 on 4/3/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var model = FileProcessingModel()
    @State private var showingFilePicker = false
    @State private var showingShareSheet = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 模式选择
                    Picker("处理模式", selection: $model.processingMode) {
                        ForEach(ProcessingMode.allCases) { mode in
                            Text(mode == .encrypt ? "加密压缩" : "解密解压")
                                .tag(mode)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    
                    // 文件选择区域
                    VStack {
                        HStack {
                            Image(systemName: "doc")
                                .font(.largeTitle)
                            Text(model.selectedFileName)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        
                        Button("选择文件") {
                            showingFilePicker = true
                        }
                        .buttonStyle(.bordered)
                        .padding(.top, 5)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // 密码区域
                    VStack(spacing: 12) {
                        SecureField("输入密码", text: $model.password)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        if model.processingMode == .encrypt {
                            SecureField("确认密码", text: $model.confirmPassword)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                    }
                    .padding(.horizontal)
                    
                    // 压缩格式选择（仅加密模式）
                    if model.processingMode == .encrypt {
                        VStack(alignment: .leading) {
                            Text("压缩格式")
                                .font(.headline)
                            
                            Picker("压缩格式", selection: $model.compressionFormat) {
                                ForEach(CompressionFormat.allCases) { format in
                                    Text(format.description).tag(format)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                        }
                        .padding(.horizontal)
                    }
                    
                    // 处理按钮
                    Button {
                        if model.processingMode == .encrypt {
                            model.encryptAndCompress { success in
                                if success {
                                    showingShareSheet = true
                                }
                            }
                        } else {
                            model.decompressAndDecrypt { success in
                                if success {
                                    showingShareSheet = true
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: model.processingMode == .encrypt ? "lock.fill" : "lock.open.fill")
                            Text(model.processingMode == .encrypt ? "加密并压缩" : "解密并解压")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(model.isProcessing || model.selectedFileURL == nil)
                    .padding(.horizontal)
                    
                    // 状态信息
                    if !model.statusMessage.isEmpty {
                        Text(model.statusMessage)
                            .font(.footnote)
                            .foregroundColor(model.statusMessage.contains("失败") ? .red : .green)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    if model.isProcessing {
                        ProgressView()
                            .padding()
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("文件加密工具")
            .alert(isPresented: $model.showAlert) {
                Alert(
                    title: Text(model.alertTitle),
                    message: Text(model.alertMessage),
                    dismissButton: .default(Text("确定"))
                )
            }
            .sheet(isPresented: $showingFilePicker) {
                DocumentPicker(fileURL: $model.selectedFileURL, fileName: $model.selectedFileName)
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = model.processedFileURL {
                    ShareSheet(url: url)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
