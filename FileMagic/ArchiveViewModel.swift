//
//  ArchiveViewModel.swift
//  FileMagic
//
//  Created by 邓理 on 4/6/25.
//

import Foundation
import SwiftUI
import Combine

class ArchiveViewModel: ObservableObject {
    
    enum CompressionFormat {
        case sevenZip
        case zip
    }
    
    @Published var compressionFormat: CompressionFormat = .sevenZip
    
    // ArchiveManager实例
    private var sevenZipManager = SevenZipArchiveManager()
    private var zipManager = ZipArchiveManager()
    
    private var currentManager: ArchiveManager {
        switch compressionFormat {
        case .sevenZip:
            return sevenZipManager
        case .zip:
            return zipManager
        }
    }
    
    enum ArchiveState: Equatable {
        case idle
        case compressing
        case decompressing
        case listing
        case success(String)
        case error(String)
        
        // 手动实现Equatable协议的==操作符
        static func == (lhs: ArchiveState, rhs: ArchiveState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle),
                 (.compressing, .compressing),
                 (.decompressing, .decompressing),
                 (.listing, .listing):
                return true
            case let (.success(lhsMessage), .success(rhsMessage)):
                return lhsMessage == rhsMessage
            case let (.error(lhsMessage), .error(rhsMessage)):
                return lhsMessage == rhsMessage
            default:
                return false
            }
        }
    }
    
    @Published var state: ArchiveState = .idle
    @Published var progress: Float = 0
    @Published var password: String = ""
    @Published var password2: String = ""
    @Published var compressionLevel: UInt8 = 5  // 默认压缩级别
    @Published var encryptHeader: Bool = false
    @Published var selectedFiles: [URL] = []
    @Published var extractedFiles: [URL] = []
    @Published var archiveContents: [String] = []
    
    // 压缩文件
    func compressFiles() async {
        guard !selectedFiles.isEmpty else {
            setState(.error("请先选择文件"))
            return
        }
        
        setState(.compressing)
        setProgress(0)
        
        // 创建输出文件夹
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let archiveName = "Archive_\(Date().timeIntervalSince1970).7z"
        let outputPath = documentsDirectory.appendingPathComponent(archiveName)
        
        do {
            let result = try await currentManager.compressFiles(
                files: selectedFiles,
                outputPath: outputPath,
                password: password.isEmpty ? nil : password,
                compressionLevel: compressionLevel,
                encryptHeader: encryptHeader,
                copyOriginalFile: true,
                progressHandler: { [weak self] progress in
                    self?.setProgress(progress)
                }
            )
            
            setState(.success("压缩完成: \(result.lastPathComponent)"))
        } catch {
            setState(.error("压缩失败: \(error.localizedDescription)"))
        }
    }
    
    func compressFilesTwice() async {
        guard !selectedFiles.isEmpty else {
            setState(.error("请先选择文件"))
            return
        }
        
        setState(.compressing)
        setProgress(0)
        
        // 创建输出文件夹
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let archiveName = "Archive_\(Date().timeIntervalSince1970).7z"
        let outputPath = documentsDirectory.appendingPathComponent(archiveName)
        
        do {
            let result = try await currentManager.compressFiles(
                files: selectedFiles,
                outputPath: outputPath,
                password: password.isEmpty ? nil : password,
                compressionLevel: compressionLevel,
                encryptHeader: encryptHeader,
                copyOriginalFile: true,
                progressHandler: { [weak self] progress in
                    self?.setProgress(progress)
                }
            )
            
            var info = "压缩完成1: \(result.lastPathComponent)"
            setState(.success(info))
            
            let archive2Name = "Archive2_\(Date().timeIntervalSince1970).7z"
            let output2Path = documentsDirectory.appendingPathComponent(archive2Name)
            
            let result2 = try await currentManager.compressFiles(
                files: [outputPath],
                outputPath: output2Path,
                password: password2.isEmpty ? nil : password2,
                compressionLevel: compressionLevel,
                encryptHeader: encryptHeader,
                copyOriginalFile: false,
                progressHandler: { [weak self] progress in
                    self?.setProgress(progress)
                }
            )
            
            info += "\n压缩完成2: \(result2.lastPathComponent)"
            setState(.success(info))
        } catch {
            setState(.error("压缩失败: \(error.localizedDescription)"))
        }
    }

    
    // 解压文件
    func decompressFile(url: URL) async {
        setState(.decompressing)
        setProgress(0)
        
        // 创建解压目标文件夹
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let extractFolderName = "Extract_\(Date().timeIntervalSince1970)"
        let destinationPath = documentsDirectory.appendingPathComponent(extractFolderName)
        
        do {
            let result = try await currentManager.decompressFile(
                archivePath: url,
                destinationPath: destinationPath,
                password: password.isEmpty ? nil : password,
                copyOriginalFile: true,
                progressHandler: { [weak self] progress in
                    self?.setProgress(progress)
                }
            )
            
            // 获取解压后的文件列表
            if let files = try? FileManager.default.contentsOfDirectory(
                at: result,
                includingPropertiesForKeys: nil
            ) {
                setExtractedFiles(files)
            }
            
            setState(.success("解压完成: \(result.lastPathComponent)"))
        } catch let error as CompressionError {
            switch error {
            case .invalidPassword:
                setState(.error("密码错误"))
            default:
                setState(.error("解压失败: \(error.localizedDescription)"))
            }
        } catch {
            setState(.error("解压失败: \(error.localizedDescription)"))
        }
    }
    
    // 解压文件
    func decompressFileTwice(url: URL) async {
        setState(.decompressing)
        setProgress(0)
        
        // 创建解压目标文件夹
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let extractFolderName = "Extract_\(Date().timeIntervalSince1970)"
        let extractFolderName2 = "Extract2_\(Date().timeIntervalSince1970)"
        let destinationPath = documentsDirectory.appendingPathComponent(extractFolderName)
        let destinationPath2 = documentsDirectory.appendingPathComponent(extractFolderName2)
        
        do {
            let result = try await currentManager.decompressFile(
                archivePath: url,
                destinationPath: destinationPath,
                password: password2.isEmpty ? nil : password2,
                copyOriginalFile: true,
                progressHandler: { [weak self] progress in
                    self?.setProgress(progress)
                }
            )
            
            var info = "解压完成: \(result.lastPathComponent)"
            setState(.success(info))
            
            // 获取目录中的所有内容
            let contents = try FileManager.default.contentsOfDirectory(at: destinationPath, includingPropertiesForKeys: nil)
            
            // 如果目录中只有一个文件
            if contents.count > 0 {
                let result2 = try await currentManager.decompressFile(
                    archivePath: contents[0],
                    destinationPath: destinationPath2,
                    password: password.isEmpty ? nil : password,
                    copyOriginalFile: false,
                    progressHandler: { [weak self] progress in
                        self?.setProgress(progress)
                    }
                )
                
                // 获取解压后的文件列表
                if let files = try? FileManager.default.contentsOfDirectory(
                    at: result2,
                    includingPropertiesForKeys: nil
                ) {
                    setExtractedFiles(files)
                }
                
                info += "\n解压完成2: \(result2.lastPathComponent)"
                setState(.success(info))
            }
        } catch let error as CompressionError {
            switch error {
            case .invalidPassword:
                setState(.error("密码错误"))
            default:
                setState(.error("解压失败: \(error.localizedDescription)"))
            }
        } catch {
            setState(.error("解压失败: \(error.localizedDescription)"))
        }
    }
    
    // 查看压缩文件内容
    func listArchiveContents(url: URL) async {
        setState(.listing)
        
        do {
            let contents = try await currentManager.listContents(
                archivePath: url,
                password: password.isEmpty ? nil : password
            )
            
            setArchiveContents(contents)
            setState(.success("已列出 \(contents.count) 个文件"))
        } catch let error as CompressionError {
            switch error {
            case .invalidPassword:
                setState(.error("密码错误"))
            default:
                setState(.error("列出文件失败: \(error.localizedDescription)"))
            }
        } catch {
            setState(.error("列出文件失败: \(error.localizedDescription)"))
        }
    }
    
    // 清除所选文件
    func clearSelectedFiles() {
        selectedFiles = []
    }
    
    // MARK: - 私有方法
    private func setState(_ newState: ArchiveState) {
        DispatchQueue.main.async {
            self.state = newState
        }
    }
    
    private func setProgress(_ newProgress: Float) {
        DispatchQueue.main.async {
            self.progress = newProgress
        }
    }
    
    private func setExtractedFiles(_ files: [URL]) {
        DispatchQueue.main.async {
            self.extractedFiles = files
        }
    }
    
    private func setArchiveContents(_ contents: [String]) {
        DispatchQueue.main.async {
            self.archiveContents = contents
        }
    }
}
