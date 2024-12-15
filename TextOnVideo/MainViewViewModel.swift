//
//  MainViewViewModel.swift
//  TextOnVideo
//
//  Created by Евгений on 15.12.2024.
//

import UIKit
import Photos

class MainViewModel: ObservableObject {
    @Published var videoURL: URL?
    @Published var showVideoPicker = false
    @Published var isProcessing = false
    @Published var showSuccessMessage = false

    // Основная функция обработки видео
    @MainActor
    func processVideo() async {
        guard let videoURL = videoURL else {
            print("Видео не выбрано!")
            return
        }

        isProcessing = true
        if let outputURL = await overlayAnimatedTextOnVideo(videoURL: videoURL, text: "Привет, мир!") {
            await saveVideoToGallery(videoURL: outputURL)
        } else {
            print("Ошибка обработки видео")
        }
        isProcessing = false
    }
    
    func overlayAnimatedTextOnVideo(videoURL: URL, text: String) async -> URL? {
        let asset = AVURLAsset(url: videoURL)
        
        do {
            let videoTracks = try await asset.loadTracks(withMediaType: .video)
            let audioTracks = try await asset.loadTracks(withMediaType: .audio)
            
            guard let videoTrack = videoTracks.first else {
                print("Ошибка: Видео дорожка отсутствует")
                return nil
            }
            
            let videoTransform = try await videoTrack.load(.preferredTransform)
            let naturalSize = try await videoTrack.load(.naturalSize)
            
            let videoSize: CGSize
            if videoTransform.a == 0 {
                videoSize = CGSize(width: naturalSize.height, height: naturalSize.width)
            } else {
                videoSize = naturalSize
            }

            let composition = AVMutableComposition()
            
            guard let videoCompositionTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else {
                print("Ошибка: Не удалось создать дорожку для видео")
                return nil
            }

            if let audioTrack = audioTracks.first,
               let audioCompositionTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
               ) {
                let duration = try await asset.load(.duration)
                try audioCompositionTrack.insertTimeRange(
                    CMTimeRange(start: .zero, duration: duration),
                    of: audioTrack,
                    at: .zero
                )
            }

            let duration = try await asset.load(.duration)
            try videoCompositionTrack.insertTimeRange(
                CMTimeRange(start: .zero, duration: duration),
                of: videoTrack,
                at: .zero
            )

            // Создание текстового слоя
            let textLayer = CATextLayer()
            textLayer.string = text
            textLayer.font = UIFont.boldSystemFont(ofSize: 50)
            textLayer.foregroundColor = UIColor.white.cgColor
            textLayer.alignmentMode = .center
            textLayer.frame = CGRect(
                x: 0,
                y: (videoSize.height - 50) / 2,
                width: videoSize.width,
                height: 50
            )

            // Создание и настройка анимации масштабирования
            let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
            scaleAnimation.fromValue = 1.0
            scaleAnimation.toValue = 3
            scaleAnimation.duration = 1.0
            scaleAnimation.autoreverses = true
            scaleAnimation.repeatCount = .infinity
            scaleAnimation.beginTime = AVCoreAnimationBeginTimeAtZero
            scaleAnimation.isRemovedOnCompletion = false
            scaleAnimation.fillMode = .forwards

            textLayer.add(scaleAnimation, forKey: "scaleEffect")

            // Создание и настройка слоев для композиции
            let overlayLayer = CALayer()
            overlayLayer.frame = CGRect(origin: .zero, size: videoSize)
            overlayLayer.addSublayer(textLayer)

            let videoLayer = CALayer()
            videoLayer.frame = CGRect(origin: .zero, size: videoSize)

            let parentLayer = CALayer()
            parentLayer.frame = CGRect(origin: .zero, size: videoSize)
            parentLayer.addSublayer(videoLayer)
            parentLayer.addSublayer(overlayLayer)

            // Создание и настройка видео композиции
            let videoComposition = AVMutableVideoComposition()
            videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
            videoComposition.renderSize = videoSize

            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = CMTimeRange(start: .zero, duration: duration)

            let layerInstruction = AVMutableVideoCompositionLayerInstruction(
                assetTrack: videoCompositionTrack
            )
            layerInstruction.setTransform(videoTransform, at: .zero)

            instruction.layerInstructions = [layerInstruction]
            videoComposition.instructions = [instruction]
            videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
                postProcessingAsVideoLayer: videoLayer,
                in: parentLayer
            )

            // Экспорт итогового видео
            let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
            guard let exporter = AVAssetExportSession(
                asset: composition,
                presetName: AVAssetExportPresetHighestQuality
            ) else {
                return nil
            }
            exporter.videoComposition = videoComposition

            try await exporter.export(to: outputURL, as: .mov)
            print("Видео успешно обработано: \(outputURL)")
            return outputURL
            
        } catch {
            print("Ошибка при обработке видео: \(error)")
            return nil
        }
    }

    @MainActor
    func saveVideoToGallery(videoURL: URL) async {
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
            }
            showSuccessMessage = true
            print("Видео успешно сохранено в галерею!")
        } catch {
            print("Ошибка при сохранении видео: \(error.localizedDescription)")
        }
    }
}
