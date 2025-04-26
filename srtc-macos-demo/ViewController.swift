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
    @IBOutlet weak var statusLabel: NSTextField!

    private let sharedPrefs = UserDefaults.standard
    private let kPrefsKeyServer = "server"
    private let kPrefsKeyToken = "token"
    
    private var isConnecting = false
    private var peerConnection: MacPeerConnection?
    private var peerConnectionStateCallback: MacPeerConnectionStateCallback?

    private let videoEncoderWrapperLock = NSLock()
    private var videoEncoderWrapperList: [VideoEncoderWrappper] = []

    @IBAction private func connectButtonAction(_ sender: NSButton) {
        let server = serverTextField.stringValue
        let token = tokenTextField.stringValue
        
        guard !server.isEmpty, !token.isEmpty else {
            showError("Server and token fields are required")
            return
        }

        if !isConnecting {
            // Initiate connection
            sharedPrefs.set(server, forKey: kPrefsKeyServer)
            sharedPrefs.set(token, forKey: kPrefsKeyToken)

            guard let url = URL(string: server) else {
                showError("Invalid server URL")
                return
            }

            // Configure and the generate the offer
            let offerConfig = MacOfferConfig(cName: UUID().uuidString)

            let codec0 = MacPubVideoCodec(codec: Codec_H264, profileLevelId: H264_Profile_Default)
            let codec1 = MacPubVideoCodec(codec: Codec_H264, profileLevelId: H264_Profile_ConstrainedBaseline)

            let videoConfig = MacPubVideoConfig(codecList: [codec0!, codec1!])

            peerConnectionStateCallback = PeerConnectionStateCallback(owner: self)

            peerConnection = MacPeerConnection()
            peerConnection?.setStateCallback(peerConnectionStateCallback)

            let offer = try? peerConnection?.createOffer(offerConfig, videoConfig: videoConfig)
            if offer == nil {
                peerConnection?.close()
                peerConnection = nil
                showError("The SDP offer is null")
                return
            }

            sender.title = "Disconnect"
            inputGridView.isHidden = true

            isConnecting = true

            startSdpExchange(url: url, token: token, offer: offer!)
        } else {
            disconnect()
        }
    }

    private func disconnect() {
        peerConnection?.close()
        peerConnection = nil

        videoEncoderWrapperLock.lock()
        defer { videoEncoderWrapperLock.unlock() }

        for encoder in videoEncoderWrapperList {
            encoder.stop()
        }
        videoEncoderWrapperList.removeAll()

        isConnecting = false
        inputGridView.isHidden = false
        connectButton.title = "Connect"
    }

    private func startSdpExchange(url: URL, token: String, offer: String) {

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/sdp", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = offer.data(using: .utf8)

        Task {
            do {
                let (data, response) = try await httpSesssion.data(for: request)
                onSdpAnswer(data: data, response: response)
            } catch {
                disconnect()
                showError("Failed to connect to server: \(error.localizedDescription)")
            }
        }
    }

    private func onSdpAnswer(data: Data?, response: URLResponse?) {
        if !isConnecting {
            return
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            disconnect()
            showError("Invalid SDP http response")
            return
        }

        guard httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 else {
            disconnect()
            showError("Invalid SDP http status code: \(httpResponse.statusCode)")
            return
        }

        guard let data = data else {
            disconnect()
            showError("Did not receive any SDP answer")
            return
        }

        if let answer = String(data: data, encoding: .utf8) {
            onSdpAnswer(answer)
        }
    }

    private func onSdpAnswer(_ answer: String) {
        print("SDP answer: \(answer)")
        var error: NSError?
        peerConnection?.setAnswer(answer, outError: &error)
        
        if let error = error {
            disconnect()
            showError("Failed to set SDP answer: \(error.localizedDescription)")
            return
        }

        let videoEncoderWrapper = VideoEncoderWrappper(layer: nil,
                                                       width: 1280,
                                                       height: 720,
                                                       callback: VideoFrameCallback(owner: self))
        videoEncoderWrapperList.append(videoEncoderWrapper)
    }

    private func showStatus(_ message: String) {
        statusLabel.stringValue = message
        statusLabel.textColor = .labelColor
    }

    private func showError(_ message: String) {
        statusLabel.stringValue = message
        statusLabel.textColor = .systemRed
    }

    private func onVideoCompressedFrame(layer: String?, csd: [NSData]?, nalus: [NSData]) {
        if layer == nil {
            if let csd = csd {
                let list = csd.map({ Data($0) })
                peerConnection?.setVideoSingleCodecSpecificData(list)
            }
            for nalu in nalus {
                peerConnection?.publishVideoSingleFrame(Data(nalu))
            }
        }
    }

    private class PeerConnectionStateCallback: NSObject, MacPeerConnectionStateCallback {
        private weak var owner: ViewController?

        init(owner: ViewController) {
            self.owner = owner
        }

        func onPeerConnectionStateChanged(_ status: Int) {
            DispatchQueue.main.async { [weak self] in
                self?.owner?.onPeerConnectionStateChanged(status)
            }
        }
    }

    private func onPeerConnectionStateChanged(_ status: Int) {
        let label = switch status {
        case PeerConnectionState_Inactive:
            "inactive"
        case PeerConnectionState_Connecting:
            "connecting"
        case PeerConnectionState_Connected:
            "connected"
        case PeerConnectionState_Failed:
            "failed"
        case PeerConnectionState_Closed:
            "closed"
        default:
            "unknown (\(status))"
        }

        showStatus("PeerConnection state: \(label)")
    }

    private class CameraCaptureCallback: CameraManager.CameraCaptureCallback {
        private weak var owner: ViewController?

        init(owner: ViewController) {
            self.owner = owner
        }
        
        override func onCameraFrame(sampleBuffer: CMSampleBuffer, preview: CGImage?) {
            owner?.onCameraFrame(sampleBuffer: sampleBuffer, preview: preview)
        }
    }

    private class RedirectHandler: NSObject, URLSessionTaskDelegate {
        func urlSession(
            _ session: URLSession,
            task: URLSessionTask,
            willPerformHTTPRedirection response: HTTPURLResponse,
            newRequest request: URLRequest,
            completionHandler: @escaping (URLRequest?) -> Void
        ) {
            // Create a mutable copy of the redirected request
            var redirectedRequest = request

            // Copy the Authorization header from the original request if available
            if let originalRequest = task.originalRequest,
               let authorizationHeader = originalRequest.value(forHTTPHeaderField: "Authorization") {
                redirectedRequest.setValue(authorizationHeader, forHTTPHeaderField: "Authorization")
            }

            // Complete with the modified request
            completionHandler(redirectedRequest)
        }
    }

    private let httpSesssion = URLSession(
        configuration: .default,
        delegate: RedirectHandler(),
        delegateQueue: nil
    )

    private let cameraManager = CameraManager.shared
    private var cameraCaptureCallback: CameraCaptureCallback!
    
    private func onCameraFrame(sampleBuffer: CMSampleBuffer, preview: CGImage?) {
        videoEncoderWrapperLock.lock()
        defer { videoEncoderWrapperLock.unlock() }

        for encoder in videoEncoderWrapperList {
            encoder.submitFrameForCompression(sampleBuffer: sampleBuffer)
        }

        if let preview = preview {
            cameraPreviewView.displayPreview(preview)
        }
    }

    private class VideoFrameCallback: NSObject, VideoEncodedFrameCallback {
        private weak var owner: ViewController?
        
        init(owner: ViewController) {
            self.owner = owner
        }
        
        func onCompressedFrame(layer: String?, frame: VideoEncodedFrame) {
            owner?.onVideoCompressedFrame(layer: layer, csd: frame.csd, nalus: frame.nalus)
        }
    }
}

