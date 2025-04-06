//
//  ZipManager.swift
//  FileMagic
//
//  Created by 邓理 on 4/6/25.
//

import Foundation
import PLzmaSDK

class SevenZipArchiveManager: ArchiveManager {
    
    // 压缩文件到7z
    func compressFiles(files: [URL],
                        outputPath: URL,
                        password: String? = nil,
                        compressionLevel: UInt8 = 5,
                        encryptHeader: Bool = false,
                        copyOriginalFile: Bool = true,
                        progressHandler: ((Float) -> Void)? = nil) async throws -> URL {
        
        return try await withCheckedThrowingContinuation { continuation in
            // 创建后台队列
            let queue = DispatchQueue(label: "com.innosaika.FileMagic", qos: .userInitiated)
            
            queue.async {
                do {
                    // 创建一个应用沙盒中的目标URL
                    let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                    
                    // 1. 创建输出流用于写入归档文件内容
                    let archivePath = try PLzmaSDK.Path(outputPath.path)
                    let archiveOutStream = try PLzmaSDK.OutStream(path: archivePath)
                    
                    // 2. 创建编码器，指定输出流、归档类型、压缩方法和可选的进度委托
                    let encoder = try PLzmaSDK.Encoder(
                        stream: archiveOutStream,
                        fileType: .sevenZ,
                        method: .LZMA2,
                        delegate: ProgressDelegate(progressHandler: progressHandler)
                    )
                    
                    // 2.1. 如果有密码，设置密码用于加密
                    if let password = password, !password.isEmpty {
                        try encoder.setPassword(password)
                        
                        // 2.2. 设置归档属性，包括是否加密头部/内容
                        if encryptHeader {
                            try encoder.setShouldEncryptHeader(true)
                        }
                        try encoder.setShouldEncryptContent(true)
                    }
                    
                    // 设置压缩级别 (1-9，9为最高压缩率)
                    try encoder.setCompressionLevel(compressionLevel)
                    
                    // 3. 添加要归档的内容
                    for fileURL in files {
                        // 开始安全访问
                        let didStartAccessing = fileURL.startAccessingSecurityScopedResource()
                        
                        // 停止安全访问
                        defer {
                            if didStartAccessing {
                                fileURL.stopAccessingSecurityScopedResource()
                            }
                        }
                        
                        let destinationURL = documentsDirectory.appendingPathComponent(fileURL.lastPathComponent)
                        
                        do {
                            if copyOriginalFile && !fileURL.path.contains(destinationURL.path) {
                                if FileManager.default.fileExists(atPath: destinationURL.path) {
                                    // 如果存在，先删除
                                    try FileManager.default.removeItem(at: destinationURL)
                                }
                                // 复制文件到应用沙盒
                                try FileManager.default.copyItem(at: fileURL, to: destinationURL)
                            }
                            
                        } catch {
                            print("Error handling file: \(error)")
                        }
                        
                        if didStartAccessing {
                            fileURL.stopAccessingSecurityScopedResource()
                        }
                        
                        // 使用沙盒中的文件进行操作
                        if !FileManager.default.fileExists(atPath: destinationURL.path) {
                            throw CompressionError.fileNotFound
                        }
                        
                        // 创建文件路径对象
                        let filePath = try PLzmaSDK.Path(destinationURL.path)
                        
                        // 添加文件到归档，使用文件名作为归档路径
                        try encoder.add(path: filePath, mode: .default, archivePath: PLzmaSDK.Path(destinationURL.lastPathComponent))
                    
                    }
                    
                    // 4. 打开归档
                    let opened = try encoder.open()
                    if !opened {
                        throw CompressionError.compressionFailed("Failed to open archive for writing")
                    }
                    
                    // 5. 执行压缩
                    let compressed = try encoder.compress()
                    if !compressed {
                        throw CompressionError.compressionFailed("Compression failed")
                    }
                    
                    continuation.resume(returning: outputPath)
                    
                } catch let error as PLzmaSDK.Exception {
                    continuation.resume(throwing: CompressionError.compressionFailed(error.description))
                } catch let error as CompressionError {
                    continuation.resume(throwing: error)
                } catch {
                    continuation.resume(throwing: CompressionError.compressionFailed(error.localizedDescription))
                }
            }
        }
    }
    
    // MARK: - 解压7z文件
    func decompressFile(archivePath: URL,
                          destinationPath: URL,
                          password: String? = nil,
                          copyOriginalFile: Bool = true,
                          progressHandler: ((Float) -> Void)? = nil) async throws -> URL {
        
        return try await withCheckedThrowingContinuation { continuation in
            let queue = DispatchQueue(label: "com.innosaika.FileMagic", qos: .userInitiated)
            
            queue.async {
                var didStartAccessing = false
                
                do {
                    // 确保目标文件夹存在
                    try FileManager.default.createDirectory(at: destinationPath,
                                                          withIntermediateDirectories: true)
                    
                    // 创建一个应用沙盒中的目标URL
                    let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                    
                    // 开始安全访问
                    didStartAccessing = archivePath.startAccessingSecurityScopedResource()
                    
                    let sandboxArchiveURL = documentsDirectory.appendingPathComponent(archivePath.lastPathComponent)
                    
                    if copyOriginalFile && !archivePath.path.contains(sandboxArchiveURL.path) {
                        if FileManager.default.fileExists(atPath: sandboxArchiveURL.path) {
                            // 如果存在，先删除
                            try FileManager.default.removeItem(at: sandboxArchiveURL)
                        }
                        // 复制文件到应用沙盒
                        try FileManager.default.copyItem(at: archivePath, to: sandboxArchiveURL)
                    }
                    
                    // 停止安全访问
                    if didStartAccessing {
                        archivePath.stopAccessingSecurityScopedResource()
                    }
                    
                    // 使用沙盒中的文件进行操作
                    if !FileManager.default.fileExists(atPath: sandboxArchiveURL.path) {
                        throw CompressionError.fileNotFound
                    }
                    
                    // 1. 创建源输入流用于读取归档文件内容
                    let archivePathObj = try PLzmaSDK.Path(sandboxArchiveURL.path)
                    let archiveInStream = try PLzmaSDK.InStream(path: archivePathObj)
                    
                    // 2. 创建解码器，指定输入流、归档类型和可选的委托
                    let decoder = try PLzmaSDK.Decoder(
                        stream: archiveInStream,
                        fileType: .sevenZ,
                        delegate: ProgressDelegate(progressHandler: progressHandler)
                    )
                    
                    // 2.1. 如果有密码，设置密码用于解密
                    if let password = password, !password.isEmpty {
                        try decoder.setPassword(password)
                    }
                    
                    // 3. 打开归档
                    let opened = try decoder.open()
                    if !opened {
                        throw CompressionError.decompressionFailed("Failed to open archive for reading")
                    }
                    
                    // 4. 解压所有内容到目标文件夹
                    let destPathObj = try PLzmaSDK.Path(destinationPath.path)
                    let extracted = try decoder.extract(to: destPathObj)
                    if !extracted {
                        throw CompressionError.decompressionFailed("Extraction failed")
                    }
                    
                    continuation.resume(returning: destinationPath)
                } catch let error as PLzmaSDK.Exception {
                    let errorMessage = error.description
                    if errorMessage.contains("password") {
                        continuation.resume(throwing: CompressionError.invalidPassword)
                    } else {
                        continuation.resume(throwing: CompressionError.decompressionFailed(errorMessage))
                    }
                } catch let error as CompressionError {
                    continuation.resume(throwing: error)
                } catch {
                    if didStartAccessing {
                        archivePath.stopAccessingSecurityScopedResource()
                    }
                    continuation.resume(throwing: CompressionError.decompressionFailed(error.localizedDescription))
                }
            }
        }
    }
    
    // MARK: - 获取压缩包内容列表，不解压
    func listContents(archivePath: URL, password: String? = nil) async throws -> [String] {
        return try await withCheckedThrowingContinuation { continuation in
            let queue = DispatchQueue(label: "com.innosaika.FileMagic", qos: .userInitiated)
            
            queue.async {
                do {
                    // 创建输入流
                    let archivePathObj = try PLzmaSDK.Path(archivePath.path)
                    let inStream = try PLzmaSDK.InStream(path: archivePathObj)
                    
                    // 创建解码器
                    let decoder = try PLzmaSDK.Decoder(stream: inStream, fileType: .sevenZ)
                    
                    // 如果有密码，设置密码
                    if let password = password, !password.isEmpty {
                        try decoder.setPassword(password)
                    }
                    
                    // 打开档案
                    let opened = try decoder.open()
                    if !opened {
                        throw CompressionError.decompressionFailed("Failed to open archive")
                    }
                    
                    // 获取所有项目
                    let items = try decoder.items()
                    
                    // 提取项目路径
                    var fileList = [String]()
                    let itemCount = items.count
                    for i in 0..<itemCount {
                        let item = try items.item(at: i)
                        let path = try item.path()
                        fileList.append(path.description)
                    }
                    
                    continuation.resume(returning: fileList)
                    
                } catch let error as PLzmaSDK.Exception {
                    let errorMessage = error.description
                    if errorMessage.contains("password") {
                        continuation.resume(throwing: CompressionError.invalidPassword)
                    } else {
                        continuation.resume(throwing: CompressionError.decompressionFailed(errorMessage))
                    }
                } catch {
                    continuation.resume(throwing: CompressionError.decompressionFailed(error.localizedDescription))
                }
            }
        }
    }
}

// MARK: - 进度委托
class ProgressDelegate: PLzmaSDK.DecoderDelegate, PLzmaSDK.EncoderDelegate {
    private let progressHandler: ((Float) -> Void)?
    
    init(progressHandler: ((Float) -> Void)?) {
        self.progressHandler = progressHandler
    }
    
    // DecoderDelegate方法
    func decoder(decoder: PLzmaSDK.Decoder, path: String, progress: Double) {
        DispatchQueue.main.async { [weak self] in
            self?.progressHandler?(Float(progress))
        }
    }
    
    // EncoderDelegate方法
    func encoder(encoder: PLzmaSDK.Encoder, path: String, progress: Double) {
        DispatchQueue.main.async { [weak self] in
            self?.progressHandler?(Float(progress))
        }
    }
}
