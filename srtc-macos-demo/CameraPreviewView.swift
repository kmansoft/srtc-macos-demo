//
//  CameraPreviewView.swift
//  srtc-macos-demo
//
//  Created by Kostya Vasilyev on 4/25/25.
//

import Cocoa
import AVFoundation

class CameraPreviewView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupLayer()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayer()
    }
    
    override func layout() {
        super.layout()
        previewLayer?.frame = bounds
    }

    func setPreviewLayer(_ previewLayer: AVCaptureVideoPreviewLayer?) {
        layer?.sublayers?.removeAll()

        self.previewLayer = previewLayer

        if let newLayer = previewLayer {
            layer?.addSublayer(newLayer)
            newLayer.bounds = bounds
        }
    }

    private func setupLayer() {
        wantsLayer = true
        layer = CALayer()
        layer?.backgroundColor = NSColor.black.cgColor
    }

    private var previewLayer: AVCaptureVideoPreviewLayer?
}

