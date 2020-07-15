//
//  PhotoPageViewController+Player.swift
//  ProgressGif
//
//  Created by Zheng on 7/13/20.
//

import UIKit
import AVFoundation
import Photos

protocol UpdateSliderProgress: class {
    func updateSlider(to value: Float)
    func finishedVideo()
}

enum PlayerContext {
    case none
    case jumpForward5
    case initialize
}
class PlayerView: UIView {
    
    weak var updateSliderProgress: UpdateSliderProgress?
    
    override class var layerClass: AnyClass {
        return AVPlayerLayer.self
    }
    
    private var playerItemContext = 0
    
    // Keep the reference and use it to observe the loading status.
    private var playerItem: AVPlayerItem?
    
//    var shouldJumpForward5 = false
    var playerContext = PlayerContext.none
    var playingState = PlayingState.paused
    var hasFinishedVideo = false
    
    private var avAsset: AVAsset?
    var avURLAsset: AVURLAsset?
    
    
    var player: AVPlayer? {
        get {
            return playerLayer.player
        }
        set {
            playerLayer.player = newValue
        }
    }
    
    var playerLayer: AVPlayerLayer {
        return layer as! AVPlayerLayer
    }
    
    private func setUpPlayerItem(with asset: AVAsset) {
        playerItem = AVPlayerItem(asset: asset)
        playerItem?.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.status), options: [.old, .new], context: &playerItemContext)
        
        DispatchQueue.main.async { [weak self] in
            self?.player = AVPlayer(playerItem: self?.playerItem!)
            
            let _ = self?.player?.addPeriodicTimeObserver(forInterval: CMTimeMake(value: 1, timescale: 30), queue: DispatchQueue.main) { [weak self] (time) in
                let newProgress = Float(CMTimeGetSeconds(time)) / Float(CMTimeGetSeconds(asset.duration))
                if self?.playingState == .playing {
                    self?.updateSliderProgress?.updateSlider(to: newProgress)
                }
            }
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        // Only handle observations for the playerItemContext
        guard context == &playerItemContext else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }
        
        if keyPath == #keyPath(AVPlayerItem.status) {
            let status: AVPlayerItem.Status
            if let statusNumber = change?[.newKey] as? NSNumber {
                status = AVPlayerItem.Status(rawValue: statusNumber.intValue)!
            } else {
                status = .unknown
            }
            
            // Switch over status value
            switch status {
            case .readyToPlay:
//                if shouldJumpForward5 {
//                    shouldJumpForward5 = false
//                    if let videoDuration = avAsset?.duration {
//                        let forward5seconds = min(CMTimeGetSeconds(videoDuration), 5)
//
//                        if forward5seconds == CMTimeGetSeconds(videoDuration) {
//                            hasFinishedVideo = true
//                            updateSliderProgress?.finishedVideo()
//                        }
//
//                        if let currentTimescale = player?.currentItem?.duration.timescale {
//                            let newCMTime = CMTimeMakeWithSeconds(forward5seconds, preferredTimescale: currentTimescale)
//                            player?.seek(to: newCMTime, toleranceBefore: CMTimeMake(value: 1, timescale: 30), toleranceAfter: CMTimeMake(value: 1, timescale: 30))
//
//                            if playingState == .paused {
//                                let forwardSliderValue = Float(forward5seconds / CMTimeGetSeconds(videoDuration))
//                                self.updateSliderProgress?.updateSlider(to: forwardSliderValue)
//                            }
//                        }
//                    }
//                } else {
//                    playingState = .playing
//                    player?.play()
//                }
                
                switch playerContext {
                case .none:
                    playingState = .playing
                    player?.play()
                case .jumpForward5:
                    playerContext = .none
                    if let videoDuration = avAsset?.duration {
                        let forward5seconds = min(CMTimeGetSeconds(videoDuration), 5)
                        
                        if forward5seconds == CMTimeGetSeconds(videoDuration) {
                            hasFinishedVideo = true
                            updateSliderProgress?.finishedVideo()
                        }
                        
                        if let currentTimescale = player?.currentItem?.duration.timescale {
                            let newCMTime = CMTimeMakeWithSeconds(forward5seconds, preferredTimescale: currentTimescale)
                            player?.seek(to: newCMTime, toleranceBefore: CMTimeMake(value: 1, timescale: 30), toleranceAfter: CMTimeMake(value: 1, timescale: 30))
                            
                            if playingState == .paused {
                                let forwardSliderValue = Float(forward5seconds / CMTimeGetSeconds(videoDuration))
                                self.updateSliderProgress?.updateSlider(to: forwardSliderValue)
                            }
                        }
                    }
                case .initialize:
                    
                    playerContext = .none
                    print("init")
                }
                
            case .failed:
                print(".failed")
            case .unknown:
                print(".unknown")
            @unknown default:
                print("@unknown default")
            }
        }
    }
    
    func startPlay(with asset: PHAsset, playerContext: PlayerContext = .none) {
//        self.shouldJumpForward5 = shouldJumpForward5
        self.playerContext = playerContext
        NotificationCenter.default.addObserver(self, selector: #selector(playerDidFinishPlaying), name: .AVPlayerItemDidPlayToEndTime, object: nil)
        
        PHCachingImageManager().requestAVAsset(forVideo: asset, options: nil) { (avAsset, audioMix, info) in
            self.avAsset = avAsset
            if let avAssetU = avAsset as? AVURLAsset {
                self.setUpPlayerItem(with: avAssetU)
                self.avURLAsset = avAssetU
            }
        }
    }
    
    func play() {
        playingState = .playing
        
        if hasFinishedVideo {
            hasFinishedVideo = false
            player?.seek(to: CMTime.zero, toleranceBefore: CMTimeMake(value: 1, timescale: 30), toleranceAfter: CMTimeMake(value: 1, timescale: 30)) { [weak self](state) in
                
                self?.player?.play()
            }
        } else {
            player?.play()
        }
        
    }
    func pause(fromSlider: Bool = false) {
        if !fromSlider {
            /// if slider paused, that means it was temporary (pause so that seek can occur)
            playingState = .paused
        }
        player?.pause()
    }
    
    @objc func playerDidFinishPlaying(note: Notification) {
        hasFinishedVideo = true
        updateSliderProgress?.finishedVideo()
    }
    
    deinit {
        playerItem?.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.status))
        print("deinit of PlayerView")
    }
}

extension PhotoPageViewController {
    
}

extension PhotoPageViewController: PlayerControlsDelegate {
    func backPressed() {
        if let currentTime = currentViewController.playerView.player?.currentTime() {
            let seconds = CMTimeGetSeconds(currentTime)
            let back5seconds = max(0, seconds - 5)
            
            if let currentTimescale = currentViewController.playerView.player?.currentItem?.duration.timescale {
                let newCMTime = CMTimeMakeWithSeconds(back5seconds, preferredTimescale: currentTimescale)
                currentViewController.playerView.player?.seek(to: newCMTime, toleranceBefore: CMTimeMake(value: 1, timescale: 30), toleranceAfter: CMTimeMake(value: 1, timescale: 30))
                
                if currentViewController.playerView.playingState == .paused {
                    let backSliderValue = Float(back5seconds / currentViewController.asset.duration)
                    playerControlsView.customSlider.setValue(backSliderValue, animated: false)
                }
            }
        }
        
    }
    
    func forwardPressed() {
        if !currentViewController.hasInitializedPlayer {
            
            /// if the user hasn't pressed play yet, but already pressed the forward button
            currentViewController.jumpForward5()
        } else {
            if let currentTime = currentViewController.playerView.player?.currentTime() {
                let seconds = CMTimeGetSeconds(currentTime)
                let forward5seconds = min(currentViewController.asset.duration, seconds + 5)
                
                if forward5seconds == currentViewController.asset.duration {
                    currentViewController.playerView.hasFinishedVideo = true
                    currentViewController.playerView.updateSliderProgress?.finishedVideo()
                }
                
                if let currentTimescale = currentViewController.playerView.player?.currentItem?.duration.timescale {
                    let newCMTime = CMTimeMakeWithSeconds(forward5seconds, preferredTimescale: currentTimescale)
                    currentViewController.playerView.player?.seek(to: newCMTime, toleranceBefore: CMTimeMake(value: 1, timescale: 30), toleranceAfter: CMTimeMake(value: 1, timescale: 30))
                    
                    if currentViewController.playerView.playingState == .paused {
                        let forwardSliderValue = Float(forward5seconds / currentViewController.asset.duration)
                        playerControlsView.customSlider.setValue(forwardSliderValue, animated: false)
                    }
                }
            }
        }
    }
    
    func sliderChanged(value: Float, event: SliderEvent) {
        switch event {
        case .began:
            
            if !currentViewController.hasInitializedPlayer {
//                currentViewController.playerView.startPlay(with: currentViewController.asset, playerContext: .initialize)
                currentViewController.startSlider()
            } else {
                /// pause first
                currentViewController.playerView.pause(fromSlider: true)
            }
        case .moved:
            if let currentTimescale = currentViewController.playerView.player?.currentItem?.duration.timescale {
                let timeStamp = value * Float(currentViewController.asset.duration)
                let time = CMTimeMakeWithSeconds(Float64(timeStamp), preferredTimescale: currentTimescale)
                currentViewController.playerView.player?.seek(to: time, toleranceBefore: CMTimeMake(value: 1, timescale: 30), toleranceAfter: CMTimeMake(value: 1, timescale: 30))
            }
        case .ended:
            /// slider went to end
            if value >= 1.0 {
                currentViewController.playerView.pause()
                currentViewController.playerView.hasFinishedVideo = true
                currentViewController.playerView.updateSliderProgress?.finishedVideo()
                
            } else if currentViewController.playerView.hasFinishedVideo == true {
                /// if the slider went to the end, then slid back again
                currentViewController.playerView.hasFinishedVideo = false
            }
            if currentViewController.playerView.playingState == .playing {
                currentViewController.playerView.play()
            }
            
        }
    }
    
    func changedPlay(playingState: PlayingState) {
        if playingState == .playing {
            currentViewController.playVideo()
        } else {
            currentViewController.pauseVideo()
        }
    }
}