import AVFoundation

let attributes = [kCVPixelBufferCGImageCompatibilityKey:kCFBooleanTrue,
          kCVPixelBufferCGBitmapContextCompatibilityKey:kCFBooleanTrue] as CFDictionary
var nullablePixelBuffer: CVPixelBuffer? = nil
let status = CVPixelBufferCreate(
    kCFAllocatorDefault,
    Int(640),
    Int (480),
    kCVPixelFormatType_OneComponent8,
    attributes,
    &nullablePixelBuffer)
guard status == kCVReturnSuccess, let pixelBuffer = nullablePixelBuffer else { fatalError() }
CVPixelBufferLockBaseAddress(pixelBuffer,CVPixelBufferLockFlags (rawValue: 0))

let width = CVPixelBufferGetWidth (pixelBuffer)
let height = CVPixelBufferGetHeight (pixelBuffer)
let duration = 1
let assetWriterSettings = [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey : 640, AVVideoHeightKey: 480] as [String : Any]
let outputMovieURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("test\(Int.random(in: 100..<1000)).mov")

let assetwriter = try! AVAssetWriter(outputURL: outputMovieURL, fileType: .mov)
let settingsAssistant = AVOutputSettingsAssistant(preset: .preset640x480)?.videoSettings
let assetWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: settingsAssistant)
let assetWriterAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: assetWriterInput, sourcePixelBufferAttributes: nil)
assetwriter.add(assetWriterInput)
assetwriter.startWriting()
assetwriter.startSession(atSourceTime: CMTime.zero)

let framesPerSecond = 30
let totalFrames = duration * framesPerSecond
var frameCount = 0
let data = (0..<width*height).map{ _ in UInt8.random(in: 0...255)}

while frameCount < totalFrames {
  if assetWriterInput.isReadyForMoreMediaData {
    let frameTime = CMTimeMake(value: Int64(frameCount), timescale: Int32(framesPerSecond))
    // Are these eight lines below the prime suspect for ineficiency?
    //
    // if let baseAddress = CVPixelBufferGetBaseAddress (pixelBuffer) {
    //     var buf = baseAddress.assumingMemoryBound(to: UInt8.self)
    //     for i in 0..<width*height{
    //         buf[i] = UInt8.random(in: 0...255)
    //     }
    // }    
    // assetWriterAdaptor.append(pixelBuffer, withPresentationTime: frameTime)
    // frameCount+=1
    //        
    // If I take an example from Apple documentation, as previously suggested by Dirk-FU on https://developer.apple.com/forums/thread/720647,
    // then I need to have random data already in AVAssetReaderOutput, which means moving initialization to AVAssetTrack, or further.
    // I've got an answer to optimising initialization here: https://developer.apple.com/forums/thread/721231       
    // So the only remaining part of the puzzle is what object should be initialized this way? 
    // And how to wire it to AVAssetReaderOutput to use its copyNextSampleBuffer() as recommended?
    //
    // Below are the lines and comments from Apple documentation
    // Copy the next sample buffer from source media.
    //    guard let nextSampleBuffer = copyNextSampleBufferToWrite() else {
    //        // Mark the input as finished.
    //        self.assetWriterInput.markAsFinished()
    //        break
    //    }
    //    // Append the sample buffer to the input.
    //    self.assetWriterInput.append(nextSampleBuffer)
    //
  }
}

CVPixelBufferUnlockBaseAddress(pixelBuffer,CVPixelBufferLockFlags (rawValue: 0))
assetWriterInput.markAsFinished()
assetwriter.finishWriting{
}

print(outputMovieURL)
