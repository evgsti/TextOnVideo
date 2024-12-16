import Foundation

final class MainViewModel: ObservableObject {
    @Published var videoURL: URL?
    @Published var showVideoPicker = false
    @Published var isProcessing = false
    @Published var isLoading = false
    @Published var showSuccessMessage = false
    @Published var error: VideoProcessingError?
    
    private let videoService: VideoProcessingService
    
    init(videoService: VideoProcessingService) {
        self.videoService = videoService
    }
    
    @MainActor
    func processVideo() async {
        guard let videoURL = videoURL else {
            print("Видео URL отсутствует")
            error = .videoNotSelected
            return
        }
        
        do {
            print("Начало обработки видео")
            isProcessing = true
            defer { 
                isProcessing = false
            }
            
            let outputURL = try await videoService.processVideo(
                url: videoURL,
                text: "Привет, мир!"
            )
            print("Видео обработано, сохраняем в галерею")
            try await videoService.saveToGallery(url: outputURL)
            print("Видео успешно сохранено")
            showSuccessMessage = true
        } catch {
            print("Ошибка при обработке: \(error)")
            if let videoError = error as? VideoProcessingError {
                self.error = videoError
            } else {
                self.error = .processingFailed(error)
            }
        }
    }
} 

extension FileManager {
    func clearTemporaryDirectory() {
        let tmpDirectory = FileManager.default.temporaryDirectory
        do {
            let tmpContents = try contentsOfDirectory(atPath: tmpDirectory.path)
            try tmpContents.forEach { file in
                let tmpFile = tmpDirectory.appendingPathComponent(file)
                try removeItem(at: tmpFile)
            }
            print("Временная директория очищена")
        } catch {
            print("Ошибка при очистке временной директории: \(error)")
        }
    }
}
