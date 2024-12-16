import Foundation

protocol VideoProcessingService {
    func processVideo(url: URL, text: String) async throws -> URL
    func saveToGallery(url: URL) async throws
} 
