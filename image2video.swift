// Solution adapted from http://twocentstudios.com/2017/02/20/creating-a-movie-with-an-image-and-audio-on-ios/ for educational purposes.
// Not optimal, but working.

import UIKit
import AVFoundation

class Utility {
    
    static func pixelBuffer(fromImage image: CGImage, size: CGSize) throws -> CVPixelBuffer {
        let options: CFDictionary = [kCVPixelBufferCGImageCompatibilityKey as String: true, kCVPixelBufferCGBitmapContextCompatibilityKey as String: true] as CFDictionary
        var pxbuffer: CVPixelBuffer? = nil
        let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(size.width), Int(size.height), kCVPixelFormatType_32ARGB, options, &pxbuffer)
        guard let buffer = pxbuffer, status == kCVReturnSuccess else { throw fatalError() }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        guard let pxdata = CVPixelBufferGetBaseAddress(buffer) else { throw fatalError() }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: pxdata, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else { throw fatalError() }
        context.concatenate(CGAffineTransform(rotationAngle: 0))
        context.draw(image, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        
        CVPixelBufferUnlockBaseAddress(buffer, [])
        
        return buffer
    }
    
    static func writeSingleImageToMovie(image: UIImage, movieLength: TimeInterval, outputFileURL: URL, completion: @escaping (Error?) -> ()) {
        do {
            let imageSize = image.size
            let videoWriter = try AVAssetWriter(outputURL: outputFileURL, fileType: AVFileType.mov)
            let videoSettings: [String: Any] = [AVVideoCodecKey: AVVideoCodecType.h264,
                                                AVVideoWidthKey: imageSize.width,
                                               AVVideoHeightKey: imageSize.height]
            let videoWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: videoSettings)
            let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoWriterInput, sourcePixelBufferAttributes: nil)
            
            if !videoWriter.canAdd(videoWriterInput) { throw fatalError() }
            videoWriterInput.expectsMediaDataInRealTime = true
            videoWriter.add(videoWriterInput)
            
            videoWriter.startWriting()
            let timeScale: Int32 = 600 // recommended in CMTime for movies.
            let halfMovieLength = Float64(movieLength/2.0) // videoWriter assumes frame lengths are equal.
            let startFrameTime = CMTimeMake(value: 0, timescale: timeScale)
            let endFrameTime = CMTimeMakeWithSeconds(halfMovieLength, preferredTimescale: timeScale)
            videoWriter.startSession(atSourceTime: startFrameTime)
            
            guard let cgImage = image.cgImage else { throw fatalError() }
            let buffer: CVPixelBuffer = try self.pixelBuffer(fromImage: cgImage, size: imageSize)
            
            while !adaptor.assetWriterInput.isReadyForMoreMediaData { usleep(10) }
            adaptor.append(buffer, withPresentationTime: startFrameTime)
            while !adaptor.assetWriterInput.isReadyForMoreMediaData { usleep(10) }
            adaptor.append(buffer, withPresentationTime: endFrameTime)
            
            
            /*
            The four lines above in opinion shared on StackOverflow.com are wrong,
             and I tried to convert them to something closer to what Apple suggested in https://developer.apple.com/documentation/avfoundation/avassetwriterinput/1387508-requestmediadatawhenready
             but I failed.
             
            assetWriterInput.requestMediaDataWhenReady(on: serialQueue) { [weak self] in
                guard let self = self else { return }
                while self.assetWriterInput.isReadyForMoreMediaData {
                    // Copy the next sample buffer from source media.
                    guard let nextSampleBuffer = copyNextSampleBufferToWrite() else {
                        // Mark the input as finished.
                        self.assetWriterInput.markAsFinished()
                        break
                    }
                    // Append the sample buffer to the input.
                    self.assetWriterInput.append(nextSampleBuffer)
                }
            }
            */
            
            videoWriterInput.markAsFinished()
            videoWriter.finishWriting {
                completion(videoWriter.error)
            }
        } catch {
            completion(error)
        }
    }
    
    static func addAudioToMovie(audioAsset: AVURLAsset, inputVideoAsset: AVURLAsset, outputVideoFileURL: URL, quality: String, completion: @escaping (Error?) -> ()) {
        do {
            let composition = AVMutableComposition()
            
            guard let videoAssetTrack = inputVideoAsset.tracks(withMediaType: AVMediaType.video).first else { throw fatalError() }
            let compositionVideoTrack = composition.addMutableTrack(withMediaType: AVMediaType.video, preferredTrackID: kCMPersistentTrackID_Invalid)
            try compositionVideoTrack?.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: inputVideoAsset.duration), of: videoAssetTrack, at: CMTime.zero)
            
            let audioStartTime = CMTime.zero
            guard let audioAssetTrack = audioAsset.tracks(withMediaType: AVMediaType.audio).first else { throw fatalError() }
            let compositionAudioTrack = composition.addMutableTrack(withMediaType: AVMediaType.audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            try compositionAudioTrack!.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: audioAsset.duration), of: audioAssetTrack, at: audioStartTime)
            
            guard let assetExport = AVAssetExportSession(asset: composition, presetName: quality) else { throw fatalError() }
            assetExport.outputFileType = AVFileType.mov
            assetExport.outputURL = outputVideoFileURL
            
            assetExport.exportAsynchronously {
                completion(assetExport.error)
            }
        } catch {
            completion(error)
        }
    }
    
    // See AVAssetExportSession.h for quality presets.
    static func createMovieWithSingleImageAndMusic(image: UIImage, audioFileURL: URL, assetExportPresetQuality: String, outputVideoFileURL: URL, completion: @escaping (Error?) -> ()) {
        let audioAsset = AVURLAsset(url: audioFileURL)
        let length = TimeInterval(audioAsset.duration.seconds)
        let videoOnlyURL = outputVideoFileURL.appendingPathExtension(".tmp.mov")
        self.writeSingleImageToMovie(image: image, movieLength: length, outputFileURL: videoOnlyURL) { (error: Error?) in
            if let error = error {
                completion(error)
                return
            }
            let videoAsset = AVURLAsset(url: videoOnlyURL)
            self.addAudioToMovie(audioAsset: audioAsset, inputVideoAsset: videoAsset, outputVideoFileURL: outputVideoFileURL, quality: assetExportPresetQuality) { (error: Error?) in
                completion(error)
            }
        }
    }
}
