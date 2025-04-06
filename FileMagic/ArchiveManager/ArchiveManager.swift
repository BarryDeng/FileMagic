//
//  ArchiveManager.swift
//  FileMagic
//
//  Created by 邓理 on 4/6/25.
//

import Foundation

enum CompressionError: Error {
    case compressionFailed(String)
    case decompressionFailed(String)
    case invalidPassword
    case fileNotFound
}

protocol ArchiveManager {
    func compressFiles(files: [URL],
                       outputPath: URL,
                       password: String?,
                       compressionLevel: UInt8,
                       encryptHeader: Bool,
                       copyOriginalFile: Bool,
                       progressHandler: ((Float) -> Void)?) async throws -> URL
    
    func decompressFile(archivePath: URL,
                        destinationPath: URL,
                        password: String?,
                        copyOriginalFile: Bool,
                        progressHandler: ((Float) -> Void)?) async throws -> URL
                        
    func listContents(archivePath: URL, password: String?) async throws -> [String]
}
