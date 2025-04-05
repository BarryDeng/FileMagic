//
//  DocumentPicker.swift
//  FileMagic
//
//  Created by 邓理 on 4/3/25.
//
import SwiftUI
import UniformTypeIdentifiers

struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let supportedTypes: [UTType]
    let allowsMultipleSelection: Bool
    let onPick: ([URL]) -> Void
    
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes)
        controller.allowsMultipleSelection = allowsMultipleSelection
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            // 给予应用访问这些文件的权限
            let securedURLs = urls.map { url in
                url.startAccessingSecurityScopedResource()
                return url
            }
            
            parent.onPick(securedURLs)
            parent.isPresented = false
            
            // 使用完后停止访问
            for url in urls {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.isPresented = false
        }
    }
}
