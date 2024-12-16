import Photos
import AVFoundation
import CoreText
import UIKit

final class VideoProcessingServiceImpl: VideoProcessingService {
    private let animationService: AnimationService
    
    init(animationService: AnimationService) {
        self.animationService = animationService
    }
    
    func processVideo(url: URL, text: String) async throws -> URL {
        let asset = AVURLAsset(url: url)
        
        
        
        let metadata = try await asset.load(.metadata)
print("Метаданные: \(metadata)")
        
        
        // Проверяем наличие видеодорожки
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw VideoProcessingError.videoTrackMissing
        }
        
        // Получаем аудиодорожки
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        
        // Создаем композицию
        let composition = try await assembleMediaTracks(
            asset: asset,
            videoTrack: videoTrack,
            audioTracks: audioTracks
        )
        
        // Создаем слой с текстом
        let videoSize = try await videoTrack.load(.naturalSize)

        let textLayer = createTextLayer(text: text, videoSize: videoSize)
        print("Размер исходного видео: \(videoSize)")
        // Добавляем анимацию
        let animation = animationService.createTextAnimation()
        textLayer.add(animation, forKey: "animation")
        
        // Создаем инструкции для композиции
        let videoComposition = await setupVisualEffects(
            composition: composition,
            textLayer: textLayer
        )
        
        // Создаем URL для выходного файла
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")
        
        // Экспортируем видео
        let exporter = try createExporter(
            composition: composition,
            videoComposition: videoComposition,
            outputURL: outputURL
        )
        
        // Выполняем экспорт
        try await exporter.export(to: outputURL, as: .mov)
        
        // Проверяем существование файла
        guard FileManager.default.fileExists(atPath: outputURL.path) else {
            throw VideoProcessingError.processingFailed(
                NSError(domain: "Ошибка создания выходного файла", code: -1)
            )
        }
        
        print("Видео успешно обработано и сохранено по пути: \(outputURL.path)")
        return outputURL
    }
    
    func saveToGallery(url: URL) async throws {
        print("Начало сохранения в галерею. Путь к файлу: \(url.path)")
        
        // Проверяем существование файла
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("Файл не найден по пути: \(url.path)")
            throw VideoProcessingError.processingFailed(
                NSError(domain: "Файл не найден", code: -1)
            )
        }
        
        // Запрашиваем разрешение
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard status == .authorized else {
            print("Нет разрешения на доступ к галерее")
            throw VideoProcessingError.processingFailed(
                NSError(domain: "Нет разрешения на доступ к галерее", code: -1)
            )
        }
        
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            }
            print("Видео успешно сохранено в галерею")
        } catch {
            print("Ошибка при сохранении в галерею: \(error.localizedDescription)")
            throw VideoProcessingError.processingFailed(error)
        }
    }
    
    private func assembleMediaTracks(asset: AVAsset, videoTrack: AVAssetTrack, audioTracks: [AVAssetTrack]) async throws -> AVMutableComposition {
        let composition = AVMutableComposition()
        
        guard let videoCompositionTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw VideoProcessingError.compositionTrackCreationFailed
        }
        
        let duration = try await asset.load(.duration)
        try videoCompositionTrack.insertTimeRange(
            CMTimeRange(start: .zero, duration: duration),
            of: videoTrack,
            at: .zero
        )
        
        // Добавляем аудио дорожку, если она есть
        if let audioTrack = audioTracks.first,
           let audioCompositionTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
           ) {
            try audioCompositionTrack.insertTimeRange(
                CMTimeRange(start: .zero, duration: duration),
                of: audioTrack,
                at: .zero
            )
        }
        
        return composition
    }
    
    private func createExporter(composition: AVComposition, videoComposition: AVMutableVideoComposition, outputURL: URL) throws -> AVAssetExportSession {
        guard let exporter = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw VideoProcessingError.exporterCreationFailed
        }
        
        exporter.videoComposition = videoComposition
        exporter.outputURL = outputURL
        exporter.outputFileType = .mov
        
        return exporter
    }
    
    private func createTextLayer(text: String, videoSize: CGSize) -> CATextLayer {
        let fontSize: CGFloat = min(videoSize.width, videoSize.height) / 10 // Адаптивный размер шрифта
        let textLayer = CATextLayer()
        textLayer.string = text
        textLayer.font = UIFont.boldSystemFont(ofSize: fontSize)
        textLayer.fontSize = fontSize
        textLayer.foregroundColor = UIColor.white.cgColor
        textLayer.alignmentMode = .center
        textLayer.frame = CGRect(
            x: 0,
            y: 0,
            width: videoSize.width,
            height: fontSize * 1.2
        )
        
        return textLayer
    }
    
    private func setupVisualEffects(composition: AVComposition, textLayer: CATextLayer) async -> AVMutableVideoComposition {
        guard let videoTrack = try? await composition.loadTracks(withMediaType: .video).first else {
            fatalError("Видео дорожка отсутствует")
        }
        
        // Загружаем трансформацию и натуральный размер
        let videoTransform = try! await videoTrack.load(.preferredTransform)
        let naturalSize = try! await videoTrack.load(.naturalSize)
        print(videoTransform)
        // Определяем ориентацию видео на основе трансформации
        let isPortrait = videoTransform.a == 0 && abs(videoTransform.b) == 1
        
        // Вычисляем финальные размеры с учетом ориентации
        let finalSize = isPortrait ? 
            CGSize(width: naturalSize.height, height: naturalSize.width) :
            naturalSize
        
        // Создаем слои с правильными размерами
        let videoLayer = CALayer()
        videoLayer.frame = CGRect(origin: .zero, size: finalSize)
        
        let parentLayer = CALayer()
        parentLayer.frame = CGRect(origin: .zero, size: finalSize)
        parentLayer.addSublayer(videoLayer)
        
        // Обновляем размеры текстового слоя
        textLayer.frame = CGRect(
            x: 0,
            y: (finalSize.height - textLayer.bounds.height) / 2,
            width: finalSize.width,
            height: textLayer.bounds.height
        )
        parentLayer.addSublayer(textLayer)
        
        // Настройка видео-композиции
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = finalSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = await CMTimeRange(start: .zero, duration: try! composition.load(.duration))
        
        // Создаем правильную трансформацию для вертикального видео
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        layerInstruction.setTransform(videoTransform, at: .zero)
        
        instruction.layerInstructions = [layerInstruction]
        videoComposition.instructions = [instruction]
        
        videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayer: videoLayer,
            in: parentLayer
        )

        return videoComposition
    }
}
