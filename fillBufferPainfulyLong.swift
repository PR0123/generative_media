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
    if let baseAddress = CVPixelBufferGetBaseAddress (pixelBuffer) {
        var buf = baseAddress.assumingMemoryBound(to: UInt8.self)
        for i in 0..<width*height{
            buf[i] = UInt8.random(in: 0...255)
        }
    }
    assetWriterAdaptor.append(pixelBuffer, withPresentationTime: frameTime)
    frameCount+=1
  }
}

CVPixelBufferUnlockBaseAddress(pixelBuffer,CVPixelBufferLockFlags (rawValue: 0))
assetWriterInput.markAsFinished()
assetwriter.finishWriting{
}

print(outputMovieURL)
