//
//  CaptureManager.swift
//  srtc-macos-demo
//
//  Created by Kostya Vasilyev on 4/25/25.
//

import AVFoundation
import CoreMedia
import CoreGraphics
import CoreImage

class CaptureManager {
    static let shared = CaptureManager()
    
    // Callbacks
    class CaptureCallback {
        func onCameraFrame(sampleBuffer: CMSampleBuffer, preview: CGImage?) {
        }
    }
    
    func registerCallback(_ callback: CaptureCallback) {
        if !callbackList.contains(where: { $0 === callback }) {
            callbackList.append(callback)

            if callbackList.count == 1 {
                startCaptureSession()
            }
        }
    }
    
    func unregisterCallback(_ callback: CaptureCallback) {
        if let index = callbackList.firstIndex(where: { $0 === callback }) {
            callbackList.remove(at: index)

            if callbackList.isEmpty {
                stopCaptureSession()
            }
        }
    }
    
    // Callbacks
    private var callbackList: [CaptureCallback] = []

    // Media capture
    private let captureQueue = DispatchQueue(label: "capture-queue")
    private var captureSession: AVCaptureSession?

    private var audioOutput: AVCaptureOutput?
    private var videoOutput: AVCaptureOutput?

    private var cameraCaptureDelegate: CameraCaptureDelegate?

    private let ciContext = CIContext(options: nil)

    private func startCaptureSession() {
        guard self.captureSession == nil else { return }
        
        let captureSession = AVCaptureSession()
        captureSession.beginConfiguration()
        
        cameraCaptureDelegate = CameraCaptureDelegate(owner: self)
        
        // Video
        if
            let videoDevice = AVCaptureDevice.default(for: .video),
            let videoInput = try? AVCaptureDeviceInput(device: videoDevice)
        {
            if captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
                
                let videoOutput = AVCaptureVideoDataOutput()
                videoOutput.setSampleBufferDelegate(cameraCaptureDelegate, queue: captureQueue)
                videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
                
                if captureSession.canAddOutput(videoOutput) {
                    captureSession.addOutput(videoOutput)
                    self.videoOutput = videoOutput
                }
            }
        }
        
        captureSession.commitConfiguration()
        captureSession.startRunning()
        
        self.captureSession = captureSession
    }
    
    private func stopCaptureSession() {
        captureSession?.stopRunning()
        captureSession = nil
        cameraCaptureDelegate = nil
    }
    
    private func captureOutput(output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if output == videoOutput {
            let preview = createPixelBuffer(sampleBuffer)

            DispatchQueue.main.async { [weak self] in
                if let self = self {
                    for callback in self.callbackList {
                        callback.onCameraFrame(sampleBuffer: sampleBuffer, preview: preview)
                    }
                }
            }
        }
    }

    private func createPixelBuffer(_ sampleBuffer: CMSampleBuffer) -> CGImage? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return nil
        }
        
        // Lock the base address of the pixel buffer
        CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)
        defer {
            CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly)
        }
        
        // Get the CoreVideo image
        return self.createCGImage(from: imageBuffer)
    }
    
    private func createCGImage(from pixelBuffer: CVPixelBuffer) -> CGImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        return ciContext.createCGImage(ciImage, from: ciImage.extent)
    }

    private class CameraCaptureDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
        private var owner: CaptureManager? = nil
        
        init(owner: CaptureManager) {
            super.init()
            self.owner = owner
        }
        
        func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            self.owner?.captureOutput(output: output, didOutput: sampleBuffer, from: connection)
        }
    }
}
