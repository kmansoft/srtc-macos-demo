//
//  ViewController.swift
//  srtc-macos-demo
//
//  Created by Kostya Vasilyev on 4/25/25.
//

import Cocoa

class ViewController: NSViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        connectButton.action = #selector(connectButtonAction)

        serverTextField.stringValue = sharedPrefs.string(forKey: kPrefsKeyServer) ?? ""
        tokenTextField.stringValue = sharedPrefs.string(forKey: kPrefsKeyToken) ?? ""
    }
    
    override func viewDidDisappear() {
        super.viewDidDisappear()
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
    
    @IBAction private func connectButtonAction(_ sender: NSButton) {
        isConnecting = !isConnecting
        
        if isConnecting {
            sharedPrefs.set(serverTextField.stringValue, forKey: kPrefsKeyServer)
            sharedPrefs.set(tokenTextField.stringValue, forKey: kPrefsKeyToken)

            sender.title = "Disconnect"
            inputGridView.isHidden = true
        } else {
            sender.title = "Connect"
            inputGridView.isHidden = false
        }
    }

}

