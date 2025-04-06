//
//  ZipArchiveManager.swift
//  FileMagic
//
//  Created by 邓理 on 4/6/25.
//

// ZipManager.swift
import Foundation
import ZipArchive

class ZipArchiveManager: ArchiveManager {
    
    func compressFiles(files: [URL],
                       outputPath: URL,
                       password: String?,
                       compressionLevel: UInt8,
                       encryptHeader: Bool,
                       copyOriginalFile: Bool,
                       progressHandler: ((Float) -> Void)? = nil) async throws -> URL {
        // 创建一个临时目录来存放选定的文件
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
        
        // 复制文件到临时目录
        for file in files {
            let destination = tempDir.appendingPathComponent(file.lastPathComponent)
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: file, to: destination)
        }
        
        // 确定目标 zip 文件路径
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let zipFileName = "Archive_\(Date().timeIntervalSince1970).zip"
        let zipFilePath = documentsDirectory.appendingPathComponent(zipFileName)
        
        // 删除已存在的同名文件
        if FileManager.default.fileExists(atPath: zipFilePath.path) {
            try FileManager.default.removeItem(at: zipFilePath)
        }
        
        // 使用 SSZipArchive 创建 zip 文件
        let success = SSZipArchive.createZipFile(
            atPath: zipFilePath.path,
            withContentsOfDirectory: tempDir.path,
            keepParentDirectory: false,
            compressionLevel: Int32(compressionLevel),
            password: password ?? nil,
            aes: true,
            progressHandler: { (entryNumber, total) in
                // 更新压缩进度
                progressHandler?(Float(entryNumber) / Float(total))
            }
        )
        
        // 清理临时目录
        try FileManager.default.removeItem(at: tempDir)
        
        if success {
            return zipFilePath
        } else {
            throw NSError(domain: "ZipError", code: -1, userInfo: [NSLocalizedDescriptionKey: "ZIP压缩失败"])
        }
    }
    
    func decompressFile(archivePath: URL,
                        destinationPath: URL,
                        password: String?,
                        copyOriginalFile: Bool,
                        progressHandler: ((Float) -> Void)? = nil) async throws -> URL {
        // 确定解压目标路径
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let extractPath = documentsDirectory.appendingPathComponent(UUID().uuidString)
        
        // 创建解压目录
        try FileManager.default.createDirectory(at: extractPath, withIntermediateDirectories: true, attributes: nil)
        
        // 使用 SSZipArchive 解压文件
        let success = SSZipArchive.unzipFile(
            atPath: archivePath.path,
            toDestination: extractPath.path,
            preserveAttributes: true,
            overwrite: true,
            nestedZipLevel: 1,
            password: password ?? nil,
            error: nil,
            delegate: nil,
            progressHandler: { (_, _, entryNumber, total) in
                // 更新解压进度
                progressHandler?(Float(entryNumber) / Float(total))
            },
            completionHandler: nil
        )
        
        if success {
            // 获取解压后的文件列表
            let fileURLs = try FileManager.default.contentsOfDirectory(at: extractPath, includingPropertiesForKeys: nil)
            return fileURLs[0]
        } else {
            throw NSError(domain: "ZipError", code: -2, userInfo: [NSLocalizedDescriptionKey: "ZIP解压失败，可能是密码错误"])
        }
    }
    
    func listContents(archivePath: URL, password: String?) async throws -> [String] {
        // ZIP文件列表实现
        
        throw NSError(domain: "ZipError", code: -3, userInfo: [NSLocalizedDescriptionKey: "无法列出ZIP文件内容"])
        
    }
}
