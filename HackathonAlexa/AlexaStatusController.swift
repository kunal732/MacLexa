//
//  AlexaStatusController.swift
//  HackathonAlexa
//
//  Created by KUNAL BATRA on 5/17/16.
//  Copyright © 2016 Kunal Batra. All rights reserved.
//

import Cocoa
import AVFoundation
import GCDWebServers

class AlexaStatusController: NSObject, AVAudioPlayerDelegate, SimpleWebServerDelegate {

    let statusItem = NSStatusBar.systemStatusBar().statusItemWithLength(NSVariableStatusItemLength)
    
    private var webServerURL: NSURL?
    private var currentAccessToken: String?
    private var tokenExpirationTime: NSDate?
    private var simplePCMRecorder: SimplePCMRecorder
    private let tempFilename = "\(NSTemporaryDirectory())hacker.wav"
    private var player: AVAudioPlayer?
    
    
    internal override init() {
        self.simplePCMRecorder = SimplePCMRecorder(numberBuffers: 1)
        
    }
    
    override func awakeFromNib() {
     
        NSAppleEventManager.sharedAppleEventManager().setEventHandler(self, andSelector: "handleURLEvent", forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))
        
        SimpleWebServer.instance.delegate = self
        SimpleWebServer.instance.startWebServer()
        
        // Have the recorder create a first recording that will get tossed so it starts faster later
        try! self.simplePCMRecorder.setupForRecording(tempFilename, sampleRate:16000, channels:1, bitsPerChannel:16, errorHandler: nil)
        try! self.simplePCMRecorder.startRecording()
        try! self.simplePCMRecorder.stopRecording()
        self.simplePCMRecorder = SimplePCMRecorder(numberBuffers: 1)
        
    }
    
    
    func toggleRecord() {
        //loads token received from amazon
        let defaults = NSUserDefaults.standardUserDefaults()
        if let atoken = defaults.stringForKey("token") {
            self.currentAccessToken = atoken
        }//end if
        
        let icon = NSImage(named: "mechoRecord")
        if (statusItem.image == icon){
            //**Uploading Commands to Amazon**
            //********************************
            
            statusItem.image = nil;
            if tokenValid() {
               try! self.simplePCMRecorder.stopRecording()
            self.upload()
            }
            
        }//endif
        else if (statusItem.image == nil) {
            //**Recording Voice Commands**
            //****************************
            
            statusItem.image = icon;
          
            if !(tokenValid()){
                self.webServerURL = NSURL(string: "http://localhost:8777/")
                NSWorkspace.sharedWorkspace().openURL(self.webServerURL!);
                
            }
            else if tokenValid(){
                print("expired time is greater than current Time")
                statusItem.image = icon;
                self.simplePCMRecorder = SimplePCMRecorder(numberBuffers: 1)
                
                try! self.simplePCMRecorder.setupForRecording(tempFilename, sampleRate:16000, channels:1, bitsPerChannel:16, errorHandler: { (error:NSError) -> Void in
                    print(error)
                    try! self.simplePCMRecorder.stopRecording()
                })
                try! self.simplePCMRecorder.startRecording()
                
                print("recording")
            }
        
        }
        
    }
    private func tokenValid() -> Bool {
        //Returns a Bool stating whether the current amazon token is valid
        let currentTime = NSDate()
        var expTokenDate: NSDate?
        var validCheck:Bool = false
        
        expTokenDate = currentTime //initialize with current time
        
        //Get token expiration date from userdefaults if exists
        let defaults = NSUserDefaults.standardUserDefaults()
        if let expiredTime = defaults.objectForKey("expiresIn") {
            expTokenDate = (expiredTime as! NSDate)
        }
        
        //compare token expiration date with current time
        if (expTokenDate!.isLessThanOrEqualTo(currentTime)) || (self.currentAccessToken == nil) {
           validCheck = false
            print("token not valid")
        }
        else if (expTokenDate!.isGreaterThan(currentTime)){
            validCheck = true
            print("token IS valid")
        }

        return validCheck
    }
    
    private func upload() {
        let uploader = AVSUploader()
        
        let defaults = NSUserDefaults.standardUserDefaults()
        if let atoken = defaults.stringForKey("token") {
            uploader.authToken = atoken
        }
        
        //uploader.authToken = atoken
        //uploader.authToken = self.currentAccessToken
        print("auth token: \(uploader.authToken)")
        
        uploader.jsonData = self.createMeatadata()
        
        uploader.audioData = NSData(contentsOfFile: tempFilename)!
        
        uploader.errorHandler = { (error:NSError) in
            if Config.Debug.Errors {
                print("Upload error: \(error)")
            }
            
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                // self.statusLabel.stringValue = "Upload error: \(error.localizedDescription)"
                //self.recordButton.enabled = true
            })
        }
        
        uploader.progressHandler = { (progress:Double) in
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                if progress < 100.0 {
                    // self.statusLabel.stringValue = String(format: "Upload progress: %d", progress)
                } else {
                    //self.statusLabel.stringValue = "Waiting for response"
                }
            })
        }
        
        uploader.successHandler = { (data:NSData, parts:[PartData]) -> Void in
            
            for part in parts {
                if part.headers["Content-Type"] == "application/json" {
                    if Config.Debug.General {
                        print(NSString(data: part.data, encoding: NSUTF8StringEncoding))
                    }
                } else if part.headers["Content-Type"] == "audio/mpeg" {
                    do {
                        
                        /* .responseString { response in
                         print("Response String: \(response.result.value)")
                         }*/
                        
                        self.player = try AVAudioPlayer(data: part.data)
                        self.player?.delegate = self
                        self.player?.play()
                        
                        dispatch_async(dispatch_get_main_queue(), { () -> Void in
                            // self.statusLabel.stringValue = "Playing response"
                        })
                    } catch let error {
                        dispatch_async(dispatch_get_main_queue(), { () -> Void in
                            //self.statusLabel.stringValue = "Playing error: \(error)"
                            //self.recordButton.enabled = true
                        })
                    }
                }
            }
            
        }
        
        try! uploader.start()
    }
    
    private func createMeatadata() -> String? {
        var rootElement = [String:AnyObject]()
        
        let deviceContextPayload = ["streamId":"", "offsetInMilliseconds":"0", "playerActivity":"IDLE"]
        let deviceContext = ["name":"playbackState", "namespace":"AudioPlayer", "payload":deviceContextPayload]
        rootElement["messageHeader"] = ["deviceContext":[deviceContext]]
        
        let deviceProfile = ["profile":"doppler-scone", "locale":"en-us", "format":"audio/L16; rate=16000; channels=1"]
        rootElement["messageBody"] = deviceProfile
        
        let data = try! NSJSONSerialization.dataWithJSONObject(rootElement, options: NSJSONWritingOptions(rawValue: 0))
        
        return NSString(data: data, encoding: NSUTF8StringEncoding) as String?
    }
    
    //
    // SimpleWebServerDelegate Impl
    //
    
    func startupComplete(webServerURL: NSURL) {
        // Always force localhost as the host
        self.webServerURL = NSURL(scheme: webServerURL.scheme, host: "localhost:\(webServerURL.port!)", path: webServerURL.path!)
        
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
            //self.statusLabel.stringValue = "Configuration needed"
            //self.configureButton.enabled = true
        })
    }
    
    func configurationComplete(tokenExpirationTime: NSDate, currentAccessToken: String) {
        self.currentAccessToken = currentAccessToken
        self.tokenExpirationTime = tokenExpirationTime
        
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
            // self.statusLabel.stringValue = "Ready"
            // self.recordButton.enabled = true
        })
    }
    
    //
    // AVAudioPlayerDelegate Impl
    //
    
    func audioPlayerDidFinishPlaying(player: AVAudioPlayer, successfully flag: Bool) {
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
            //self.statusLabel.stringValue = "Ready"
            //self.recordButton.enabled = true
        })
    }
    
    func audioPlayerDecodeErrorDidOccur(player: AVAudioPlayer, error: NSError?) {
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
            //self.statusLabel.stringValue = "Player error: \(error)"
            // self.recordButton.enabled = true
        })
    }
    
    //
    // Handle app URL
    //
    
    func handleURLEvent() {
        if self.currentAccessToken != nil && self.tokenExpirationTime != nil {
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                // self.statusLabel.stringValue = "Ready"
                //self.recordButton.enabled = true
            })
        } else {
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                //self.statusLabel.stringValue = "Configuration error"
                // self.recordButton.enabled = false
            })
        }
    }


}
