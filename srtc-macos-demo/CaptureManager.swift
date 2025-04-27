//
//  CaptureManager.swift
//  srtc-macos-demo
//
//  Created by Kostya Vasilyev on 4/25/25.
//

import AVFoundation
import CoreMedia

class CaptureManager {
    static let shared = CaptureManager()

    // Callbacks
    class CaptureCallback {
        func onCameraFrame(sampleBuffer: CMSampleBuffer, preview: CGImage?) {
        }
        func onMicrophoneFrame(sampleBuffer: CMSampleBuffer) {
        }
    }

    func registerCallback(_ callback: CaptureCallback) {
        lock.lock()
        defer { lock.unlock() }

        if !callbackList.contains(where: { $0 === callback }) {
            callbackList.append(callback)

            if callbackList.count == 1 {
                startCaptureSession()
            }
        }
    }

    func unregisterCallback(_ callback: CaptureCallback) {
        lock.lock()
        defer { lock.unlock() }

        if let index = callbackList.firstIndex(where: { $0 === callback }) {
            callbackList.remove(at: index)

            if callbackList.isEmpty {
                stopCaptureSession()
            }
        }
    }

    func createCameraPreviewLayer() -> AVCaptureVideoPreviewLayer? {
        guard let session = captureSession else { return nil }

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]

        return previewLayer
    }

    // Lock
    private let lock = NSLock()

    // Callbacks
    private var callbackList: [CaptureCallback] = []

    // Media capture
    private let captureQueue = DispatchQueue(label: "capture-queue")
    private var captureSession: AVCaptureSession?

    private var audioOutput: AVCaptureOutput?
    private var videoOutput: AVCaptureOutput?

    private var cameraCaptureDelegate: CameraCaptureDelegate?
    private var microphoneCaptureDelegate: MicrophoneCaptureDelegate?

    private func startCaptureSession() {
        guard self.captureSession == nil else { return }

        let captureSession = AVCaptureSession()
        captureSession.beginConfiguration()

        cameraCaptureDelegate = CameraCaptureDelegate(owner: self)
        microphoneCaptureDelegate = MicrophoneCaptureDelegate(owner: self)

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

        // Audio
        if
            let auidoDevice = AVCaptureDevice.default(for: .audio),
            let audioInput = try? AVCaptureDeviceInput(device: auidoDevice)
        {
            if captureSession.canAddInput(audioInput) {
                captureSession.addInput(audioInput)

                let audioOutput = AVCaptureAudioDataOutput()
                audioOutput.setSampleBufferDelegate(microphoneCaptureDelegate, queue: captureQueue)
                audioOutput.audioSettings = [
                    AVFormatIDKey as String: Int(kAudioFormatLinearPCM),
                    AVSampleRateKey as String: Int(48000),
                    AVNumberOfChannelsKey as String: Int(1),
                    AVLinearPCMBitDepthKey as String: Int(16),
                    AVLinearPCMIsBigEndianKey as String: false,
                    AVLinearPCMIsFloatKey as String: false
                ]

                if captureSession.canAddOutput(audioOutput) {
                    captureSession.addOutput(audioOutput)
                    self.audioOutput = audioOutput
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
        microphoneCaptureDelegate = nil
    }

    private func captureOutput(output: AVCaptureOutput,
                               didOutput sampleBuffer: CMSampleBuffer,
                               from connection: AVCaptureConnection) {
        if output == videoOutput {
            lock.lock()
            defer { lock.unlock() }

            for callback in self.callbackList {
                callback.onCameraFrame(sampleBuffer: sampleBuffer, preview: nil)
            }
        } else if output == audioOutput {
            lock.lock()
            defer { lock.unlock() }

            for callback in self.callbackList {
                callback.onMicrophoneFrame(sampleBuffer: sampleBuffer)
            }
        }
    }

    private class CameraCaptureDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
        private var owner: CaptureManager? = nil

        init(owner: CaptureManager) {
            super.init()
            self.owner = owner
        }

        func captureOutput(_ output: AVCaptureOutput,
                           didOutput sampleBuffer: CMSampleBuffer,
                           from connection: AVCaptureConnection) {
            self.owner?.captureOutput(output: output, didOutput: sampleBuffer, from: connection)
        }
    }

    private class MicrophoneCaptureDelegate: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate {
        private var owner: CaptureManager? = nil

        init(owner: CaptureManager) {
            super.init()
            self.owner = owner
        }

        func captureOutput(_ output: AVCaptureOutput,
                           didOutput sampleBuffer: CMSampleBuffer,
                           from connection: AVCaptureConnection) {
            self.owner?.captureOutput(output: output, didOutput: sampleBuffer, from: connection)
        }
    }
}
