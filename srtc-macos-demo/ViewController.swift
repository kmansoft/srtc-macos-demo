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

            guard let url = URL(string: server) else {
                showError("Invalid server URL")
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/sdp", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.httpBody = sdpOffer!.data(using: .utf8)

            let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
                if let self = self {
                    DispatchQueue.main.async { [weak self] in
                        self?.onSdpAnswer(data: data, response: response, error: error)
                    }
                }
            }

            task.resume()
        } else {
            // Disconnect
            peerConnection = nil
        }

        isConnecting = !isConnecting
        
        if isConnecting {
            sharedPrefs.set(server, forKey: kPrefsKeyServer)
            sharedPrefs.set(token, forKey: kPrefsKeyToken)

            sender.title = "Disconnect"
            inputGridView.isHidden = true
        } else {
            clearIsConnecting()
        }
    }

    private func clearIsConnecting() {
        isConnecting = false
        inputGridView.isHidden = false
        connectButton.title = "Connect"
    }

    private func onSdpAnswer(data: Data?, response: URLResponse?, error: (any Error)?) {
        if let error = error {
            showError("SDP http error: \(error.localizedDescription)")
            clearIsConnecting()
            return
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            showError("Invalid SDP http response")
            clearIsConnecting()
            return
        }

        NSLog("SDP http status code: \(httpResponse.statusCode)")

        if let data = data {
            if let answer = String(data: data, encoding: .utf8) {
                onSdpAnswer(answer)
            }
        }
    }

    private func onSdpAnswer(_ answer: String) {
        print("SDP answer: \(answer)")
        var error: NSError?
        peerConnection?.setAnswer(answer, outError: &error)
        if let error = error {
            showError("Failed to set SDP answer: \(error.localizedDescription)")
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

