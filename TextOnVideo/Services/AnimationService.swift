import AVFoundation

protocol AnimationService {
    func createTextAnimation() -> CAAnimation
}

final class AnimationServiceImpl: AnimationService {
    func createTextAnimation() -> CAAnimation {
        let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
        scaleAnimation.fromValue = 1.0
        scaleAnimation.toValue = 3.0
        scaleAnimation.duration = 1.0
        scaleAnimation.autoreverses = true
        scaleAnimation.repeatCount = .infinity
        scaleAnimation.beginTime = AVCoreAnimationBeginTimeAtZero
        scaleAnimation.isRemovedOnCompletion = false
        scaleAnimation.fillMode = .forwards
        return scaleAnimation
    }
} 
