//
//  FileProcess.swift
//  FileMagic
//
//  Created by 邓理 on 4/3/25.
//

import Foundation
import CryptoSwift
import ZIPFoundation

enum CompressionFormat: String, CaseIterable, Identifiable {
    case zip
    var id: Self { self }
    
    var description: String {
        switch self {
        case .zip: return "ZIP"
        }
    }
}

enum ProcessingMode: String, CaseIterable, Identifiable {
    case encrypt, decrypt
    var id: Self { self }
}

class FileProcessingModel: ObservableObject {
    @Published var selectedFileURL: URL?
    @Published var selectedFileName: String = "未选择文件"
    @Published var password: String = ""
    @Published var confirmPassword: String = ""
    @Published var compressionFormat: CompressionFormat = .zip
    @Published var processingMode: ProcessingMode = .encrypt
    @Published var isProcessing: Bool = false
    @Published var statusMessage: String = ""
    @Published var showAlert: Bool = false
    @Published var alertTitle: String = ""
    @Published var alertMessage: String = ""
    @Published var processedFileURL: URL?
    
    // 加密并压缩文件
    func encryptAndCompress(completion: @escaping (Bool) -> Void) {
        guard let fileURL = selectedFileURL else {
            showAlert(title: "错误", message: "请先选择文件")
            completion(false)
            return
        }
        
        if password.isEmpty {
            showAlert(title: "错误", message: "请输入密码")
            completion(false)
            return
        }
        
        if password != confirmPassword {
            showAlert(title: "错误", message: "两次输入的密码不一致")
            completion(false)
            return
        }
        
        isProcessing = true
        statusMessage = "处理中..."
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                // 创建临时目录
                let tempDir = FileManager.default.temporaryDirectory
                let encryptedFileName = fileURL.deletingPathExtension().lastPathComponent + "_encrypted"
                
                // 读取文件数据
                let fileData = try Data(contentsOf: fileURL)
                
                // 1. 先加密文件
                let key = try self.deriveKey(password: self.password)
                let iv = AES.randomIV(AES.blockSize)
                let aes = try AES(key: key, blockMode: CBC(iv: iv), padding: .pkcs7)
                let encryptedData = try aes.encrypt(fileData.bytes)
                
                // 添加IV到加密数据的开头
                var encryptedDataWithIV = Data(iv)
                encryptedDataWithIV.append(Data(encryptedData))
                
                // 2. 压缩
                let zipFileURL = tempDir.appendingPathComponent(encryptedFileName + ".zip")
                let tempFileURL = tempDir.appendingPathComponent("temp_file")
                try encryptedDataWithIV.write(to: tempFileURL)
                
                // 使用 ZIPFoundation 创建加密 ZIP
                let fileManager = FileManager()
                let archive = Archive(url: zipFileURL, accessMode: .create)
                
                try archive?.addEntry(with: tempFileURL.lastPathComponent,
                                     relativeTo: tempFileURL.deletingLastPathComponent(),
                                     compressionMethod: .deflate,
                                     password: self.password)
                
                try fileManager.removeItem(at: tempFileURL)
                
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.processedFileURL = zipFileURL
                    self.statusMessage = "处理完成: \(zipFileURL.lastPathComponent)"
                    completion(true)
                }
            } catch {
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.showAlert(title: "处理失败", message: error.localizedDescription)
                    self.statusMessage = "处理失败: \(error.localizedDescription)"
                    completion(false)
                }
            }
        }
    }
    
    // 解压并解密文件
    func decompressAndDecrypt(completion: @escaping (Bool) -> Void) {
        guard let fileURL = selectedFileURL else {
            showAlert(title: "错误", message: "请先选择文件")
            completion(false)
            return
        }
        
        if password.isEmpty {
            showAlert(title: "错误", message: "请输入密码")
            completion(false)
            return
        }
        
        isProcessing = true
        statusMessage = "解密解压中..."
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                let tempDir = FileManager.default.temporaryDirectory
                let fileExtension = fileURL.pathExtension.lowercased()
                let outputFileURL = tempDir.appendingPathComponent("decrypted_\(UUID().uuidString)")
                
                if fileExtension == "zip" {
                    // 解压ZIP
                    let unzipDir = tempDir.appendingPathComponent("unzip_temp")
                    try FileManager.default.createDirectory(at: unzipDir, withIntermediateDirectories: true, attributes: nil)
                    
                    // 使用 ZIPFoundation 解压
                    let archive = Archive(url: fileURL, accessMode: .read, password: self.password)
                    guard let entry = archive?.makeIterator().next() else {
                        throw NSError(domain: "AppErrorDomain", code: 2, userInfo: [NSLocalizedDescriptionKey: "ZIP 文件为空或无法读取"])
                    }
                    
                    let extractedFileURL = unzipDir.appendingPathComponent(entry.path)
                    _ = try archive?.extract(entry, to: extractedFileURL)
                    
                    let encryptedDataWithIV = try Data(contentsOf: extractedFileURL)
                    try FileManager.default.removeItem(at: unzipDir)
                    
                    // 提取IV和加密数据
                    let ivLength = AES.blockSize
                    guard encryptedDataWithIV.count > ivLength else {
                        throw NSError(domain: "AppErrorDomain", code: 5, userInfo: [NSLocalizedDescriptionKey: "文件格式错误或未加密"])
                    }
                    
                    let iv = Array(encryptedDataWithIV.prefix(ivLength))
                    let encryptedData = Array(encryptedDataWithIV.suffix(from: ivLength))
                    
                    // 解密
                    let key = try self.deriveKey(password: self.password)
                    let aes = try AES(key: key, blockMode: CBC(iv: iv), padding: .pkcs7)
                    let decryptedData = try aes.decrypt(encryptedData)
                    
                    try Data(decryptedData).write(to: outputFileURL)
                    
                    DispatchQueue.main.async {
                        self.isProcessing = false
                        self.processedFileURL = outputFileURL
                        self.statusMessage = "解密完成"
                        completion(true)
                    }
                } else {
                    throw NSError(domain: "AppErrorDomain", code: 4, userInfo: [NSLocalizedDescriptionKey: "目前仅支持ZIP格式"])
                }
            } catch {
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.showAlert(title: "解密失败", message: error.localizedDescription)
                    self.statusMessage = "解密失败: \(error.localizedDescription)"
                    completion(false)
                }
            }
        }
    }
    
    // 密钥派生函数
    private func deriveKey(password: String) throws -> [UInt8] {
        let salt: [UInt8] = [0x12, 0x34, 0x56, 0x78, 0x9A, 0xBC, 0xDE, 0xF0]
        return try PKCS5.PBKDF2(password: password.bytes, salt: salt, iterations: 4096, keyLength: 32, variant: .sha256).calculate()
    }
    
    // 显示警告
    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
}
