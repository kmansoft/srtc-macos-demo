//
//  CameraPreviewView.swift
//  srtc-macos-demo
//
//  Created by Kostya Vasilyev on 4/25/25.
//

import Cocoa
import CoreMedia

class CameraPreviewView: NSView {
    private var imageLayer: CALayer?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupLayer()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayer()
    }
    
    private func setupLayer() {
        wantsLayer = true
        layer = CALayer()
        layer?.backgroundColor = NSColor.black.cgColor
        
        imageLayer = CALayer()
        imageLayer?.contentsGravity = .resizeAspect
        
        if let imageLayer = imageLayer {
            layer?.addSublayer(imageLayer)
        }
    }
    
    override func layout() {
        super.layout()
        imageLayer?.frame = bounds
    }
    
    func displayPixelBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        // Lock the base address of the pixel buffer
        CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)
        
        // Get the CoreVideo image
        let imageRef = self.createCGImage(from: imageBuffer)
        
        // Unlock the pixel buffer
        CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly)
        
        // Update the layer on the main thread
        DispatchQueue.main.async { [weak self] in
            self?.imageLayer?.contents = imageRef
        }
    }
    
    private func createCGImage(from pixelBuffer: CVPixelBuffer) -> CGImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext(options: nil)
        return context.createCGImage(ciImage, from: ciImage.extent)
    }
}

