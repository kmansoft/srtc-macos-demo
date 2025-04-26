//
//  CameraManager.swift
//  srtc-macos-demo
//
//  Created by Kostya Vasilyev on 4/25/25.
//

import AVFoundation
import CoreMedia
import CoreGraphics
import CoreImage

class CameraManager {
    static let shared = CameraManager()
    
    // Callbacks
    class CameraCaptureCallback {
        func onCameraFrame(sampleBuffer: CMSampleBuffer, preview: CGImage?) {
        }
    }
    
    func registerCameraCaptureCallback(_ callback: CameraCaptureCallback) {
        if !cameraCaptureCallbackList.contains(where: { $0 === callback }) {
            cameraCaptureCallbackList.append(callback)
            
            if cameraCaptureCallbackList.count == 1 {
                startCaptureSession()
            }
        }
    }
    
    func unregisterCameraCaptureCallback(_ callback: CameraCaptureCallback) {
        if let index = cameraCaptureCallbackList.firstIndex(where: { $0 === callback }) {
            cameraCaptureCallbackList.remove(at: index)

            if cameraCaptureCallbackList.isEmpty {
                stopCaptureSession()
            }
        }
    }
    
    // Callbacks
    private var cameraCaptureCallbackList: [CameraCaptureCallback] = []

    // Media capture
    private let captureQueue = DispatchQueue(label: "media-queue")
    private var captureSession: AVCaptureSession?

    private var audioOutput: AVCaptureOutput?
    private var videoOutput: AVCaptureOutput?

    private var cameraCaptureDelegate: CameraCaptureDelegate?
    private var cameraInputFrameCount = 0
    

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
                    for callback in self.cameraCaptureCallbackList {
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
        let context = CIContext(options: nil)
        return context.createCGImage(ciImage, from: ciImage.extent)
    }

    private class CameraCaptureDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
        private var owner: CameraManager? = nil
        
        init(owner: CameraManager) {
            super.init()
            self.owner = owner
        }
        
        func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            self.owner?.captureOutput(output: output, didOutput: sampleBuffer, from: connection)
        }
    }
}
