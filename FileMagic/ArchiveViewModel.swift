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
            let result = try await ZipManager.compress(
                files: selectedFiles,
                outputPath: outputPath,
                password: password.isEmpty ? nil : password,
                compressionLevel: compressionLevel,
                encryptHeader: encryptHeader,
                progressHandler: { [weak self] progress in
                    self?.setProgress(progress)
                }
            )
            
            setState(.success("压缩完成: \(result.lastPathComponent)"))
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
            let result = try await ZipManager.decompress(
                archivePath: url,
                destinationPath: destinationPath,
                password: password.isEmpty ? nil : password,
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
        } catch let error as ZipManager.CompressionError {
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
            let contents = try await ZipManager.listContents(
                archivePath: url,
                password: password.isEmpty ? nil : password
            )
            
            setArchiveContents(contents)
            setState(.success("已列出 \(contents.count) 个文件"))
        } catch let error as ZipManager.CompressionError {
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
