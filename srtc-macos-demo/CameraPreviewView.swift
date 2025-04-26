//
//  CameraPreviewView.swift
//  srtc-macos-demo
//
//  Created by Kostya Vasilyev on 4/25/25.
//

import Cocoa
import CoreGraphics

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
    
    func displayPreview(_ preview: CGImage) {
        // Update the layer on the main thread
        DispatchQueue.main.async { [weak self] in
            self?.imageLayer?.contents = preview
        }
    }
}

