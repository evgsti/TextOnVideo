import Foundation

enum VideoProcessingError: LocalizedError {
    case videoNotSelected
    case videoTrackMissing
    case audioTrackMissing
    case compositionTrackCreationFailed
    case exporterCreationFailed
    case processingFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .videoNotSelected:
            return "Видео не выбрано"
        case .videoTrackMissing:
            return "Видео дорожка отсутствует"
        case .audioTrackMissing:
            return "Аудио дорожка отсутствует"
        case .compositionTrackCreationFailed:
            return "Не удалось создать дорожку для композиции"
        case .exporterCreationFailed:
            return "Не удалось создать экспортер"
        case .processingFailed(let error):
            return "Ошибка обработки: \(error.localizedDescription)"
        }
    }
} 
