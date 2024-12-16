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
    @Binding var isLoading: Bool // Добавляем binding для отслеживания состояния загрузки
    
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
            
            guard let result = results.first,
                  result.itemProvider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) else {
                print("Файл не выбран или не соответствует формату видео")
                return
            }
            
            DispatchQueue.main.async {
                self.parent.isLoading = true // Начинаем загрузку
            }
            
            result.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
                if let error = error {
                    print("Ошибка загрузки видео: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.parent.isLoading = false // Завершаем загрузку при ошибке
                    }
                    return
                }
                
                guard let sourceURL = url else {
                    print("URL видео не найден")
                    DispatchQueue.main.async {
                        self.parent.isLoading = false // Завершаем загрузку при ошибке
                    }
                    return
                }
                
                let uniqueName = UUID().uuidString + ".mov"
                let destinationURL = FileManager.default.temporaryDirectory.appendingPathComponent(uniqueName)
                
                do {
                    try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
                    DispatchQueue.main.async {
                        self.parent.videoURL = destinationURL
                        self.parent.isLoading = false // Завершаем загрузку после успешного копирования
                    }
                    print("Видео успешно скопировано в \(destinationURL.path)")
                } catch {
                    print("Ошибка копирования файла: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.parent.isLoading = false // Завершаем загрузку при ошибке
                    }
                }
            }
        }
    }
}
