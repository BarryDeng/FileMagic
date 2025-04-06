//
//  ShareSheet.swift
//  FileMagic
//
//  Created by 邓理 on 4/3/25.
//
import SwiftUI
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let item: URL
    
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = DocumentShareController(fileURL: item)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

// 自定义控制器来处理文件分享
class DocumentShareController: UIViewController {
    private var fileURL: URL
    private var documentInteractionController: UIDocumentInteractionController?
    
    init(fileURL: URL) {
        self.fileURL = fileURL
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // 确保文件存在
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("文件不存在: \(fileURL.path)")
            self.dismiss(animated: true)
            return
        }
        
        // 创建文档交互控制器
        documentInteractionController = UIDocumentInteractionController(url: fileURL)
        documentInteractionController?.delegate = self
        
        // 显示分享选项
        if let controller = documentInteractionController {
            if !controller.presentOptionsMenu(from: self.view.frame, in: self.view, animated: true) {
                print("无法显示分享菜单")
                self.dismiss(animated: true)
            }
        }
    }
}

// 文档交互控制器的委托实现
extension DocumentShareController: UIDocumentInteractionControllerDelegate {
    func documentInteractionControllerDidDismissOptionsMenu(_ controller: UIDocumentInteractionController) {
        // 当用户关闭分享菜单时，关闭视图控制器
        self.dismiss(animated: true)
    }
    
    func documentInteractionController(_ controller: UIDocumentInteractionController, didEndSendingToApplication application: String?) {
        // 文件发送完成后，关闭视图控制器
        self.dismiss(animated: true)
    }
    
    // 提供父视图控制器
    func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
        return self
    }
}
