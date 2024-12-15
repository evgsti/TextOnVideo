//
//  VideoPickerView.swift
//  TextOnVideo
//
//  Created by Евгений on 15.12.2024.
//

import SwiftUI
import PhotosUI

struct VideoPicker: UIViewControllerRepresentable {
    @Binding var videoURL: URL?
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .videos
        config.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: VideoPicker
        
        init(_ parent: VideoPicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            
            guard let result = results.first else {
                return
            }
            
            result.itemProvider.loadItem(forTypeIdentifier: UTType.movie.identifier, options: nil) { (videoURL, error) in
                if let error = error {
                    print("Ошибка загрузки видео: \(error.localizedDescription)")
                    return
                }
                
                guard let videoURL = videoURL as? URL else {
                    print("Не удалось получить URL видео")
                    return
                }
                
                // Создаем постоянную копию во временной директории
                let tempDir = FileManager.default.temporaryDirectory
                let fileName = videoURL.lastPathComponent
                let localURL = tempDir.appendingPathComponent(fileName)
                
                do {
                    if FileManager.default.fileExists(atPath: localURL.path) {
                        try FileManager.default.removeItem(at: localURL)
                    }
                    try FileManager.default.copyItem(at: videoURL, to: localURL)
                    
                    DispatchQueue.main.async {
                        self.parent.videoURL = localURL
                    }
                    print("Видео успешно загружено: \(localURL.path)")
                } catch {
                    print("Ошибка копирования видео: \(error.localizedDescription)")
                }
            }
        }
    }
}
