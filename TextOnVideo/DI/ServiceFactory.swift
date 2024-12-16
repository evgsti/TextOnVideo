final class ServiceFactory {
    static func makeMainViewModel() -> MainViewModel {
        let animationService = AnimationServiceImpl()
        let videoService = VideoProcessingServiceImpl(animationService: animationService)
        return MainViewModel(videoService: videoService)
    }
} 