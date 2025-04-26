//
//  ViewController.swift
//  srtc-macos-demo
//
//  Created by Kostya Vasilyev on 4/25/25.
//

import Cocoa
import CoreMedia
import CoreGraphics

class ViewController: NSViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        connectButton.action = #selector(connectButtonAction)

        serverTextField.stringValue = sharedPrefs.string(forKey: kPrefsKeyServer) ?? ""
        tokenTextField.stringValue = sharedPrefs.string(forKey: kPrefsKeyToken) ?? ""

        cameraCaptureCallback = CameraCaptureCallback(owner: self)
        cameraManager.registerCameraCaptureCallback(cameraCaptureCallback!)
    }
    
    override func viewDidDisappear() {
        super.viewDidDisappear()
        
        cameraManager.unregisterCameraCaptureCallback(cameraCaptureCallback!)
    }

    @IBOutlet weak var cameraPreviewView: CameraPreviewView!
    @IBOutlet weak var inputGridView: NSGridView!
    @IBOutlet weak var serverTextField: NSTextField!
    @IBOutlet weak var tokenTextField: NSTextField!
    @IBOutlet weak var connectButton: NSButton!

    private let sharedPrefs = UserDefaults.standard
    private let kPrefsKeyServer = "server"
    private let kPrefsKeyToken = "token"
    
    private var isConnecting = false
    private var peerConnection: MacPeerConnection?

    @IBAction private func connectButtonAction(_ sender: NSButton) {
        let server = serverTextField.stringValue
        let token = tokenTextField.stringValue
        
        guard !server.isEmpty, !token.isEmpty else {
            showError("Server and token fields are required")
            return
        }

        if !isConnecting {
            // Initiate connection
            let offerConfig = MacOfferConfig(cName: UUID().uuidString)

            let codec0 = MacPubVideoCodec(codec: Codec_H264, profileLevelId: H264_Profile_Default)
            let codec1 = MacPubVideoCodec(codec: Codec_H264, profileLevelId: H264_Profile_ConstrainedBaseline)

            let videoConfig = MacPubVideoConfig(codecList: [codec0!, codec1!])

            peerConnection = MacPeerConnection()

            let sdpOffer = try? peerConnection?.createOffer(offerConfig, videoConfig: videoConfig)
            if sdpOffer == nil {
                showError("The SDP offer is null")
                return
            }

            NSLog("SDP offer: \(sdpOffer!)")
        }

        isConnecting = !isConnecting
        
        if isConnecting {
            sharedPrefs.set(server, forKey: kPrefsKeyServer)
            sharedPrefs.set(token, forKey: kPrefsKeyToken)

            sender.title = "Disconnect"
            inputGridView.isHidden = true
        } else {
            sender.title = "Connect"
            inputGridView.isHidden = false
        }
    }
    
    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = message
        alert.runModal()
    }

    private class CameraCaptureCallback: CameraManager.CameraCaptureCallback {
        private var owner: ViewController!
        
        init(owner: ViewController) {
            self.owner = owner
        }
        
        override func onCameraFrame(sampleBuffer: CMSampleBuffer, preview: CGImage?) {
            if let preview = preview {
                owner.onCameraFramePreview(preview)
            }
        }
    }
    
    private let cameraManager = CameraManager.shared
    private var cameraCaptureCallback: CameraCaptureCallback!
    
    private func onCameraFramePreview(_ preview: CGImage) {
        cameraPreviewView.displayPreview(preview)
    }
}

