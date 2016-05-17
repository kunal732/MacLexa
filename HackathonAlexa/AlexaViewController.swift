//
//  AlexaViewController.swift
//  HackathonAlexa
//
//  Created by KUNAL BATRA on 5/16/16.
//  Copyright © 2016 Kunal Batra. All rights reserved.
//

import Cocoa
import AVFoundation
import GCDWebServers

class AlexaViewController: NSViewController {
   
    
    
    @IBOutlet weak var AppID: NSTextField!
    @IBOutlet weak var ClientID: NSTextField!
    @IBOutlet weak var AppIDLabel: NSTextField!
    @IBOutlet weak var ClientIDLabel: NSTextField!
    @IBOutlet weak var regButton: NSButtonCell!
    

    
    override func viewDidLoad() {
        super.viewDidLoad()
       
        AppIDLabel.stringValue = ""
        ClientIDLabel.stringValue = ""
        let defaults = NSUserDefaults.standardUserDefaults()
        
        if let appidString = defaults.objectForKey("AppID") {
            AppID.stringValue = appidString as! String
        }
        
        if let clientidString = defaults.objectForKey("ClientID") {
            ClientID.stringValue = clientidString as! String
            
        }
        if (AppID.stringValue != "")&&(ClientID.stringValue != ""){
            regButton.title = "Update Credentials"
        }
        
    }

    
    @IBAction func quit(sender: AnyObject) {
        NSApp.terminate(self)
    }
    
    @IBAction func register(sender: NSButton) {
        let defaults = NSUserDefaults.standardUserDefaults()
        if AppID.stringValue == "" {
            AppIDLabel.stringValue = "* Must enter the Application Type ID";
        }
        else {
         AppIDLabel.stringValue = ""
         defaults.setObject(AppID.stringValue, forKey: "AppID")
        }
        if ClientID.stringValue == "" {
            ClientIDLabel.stringValue = "* Must enter the Client ID"
        }
        else {
         ClientIDLabel.stringValue = ""
         defaults.setObject(ClientID.stringValue, forKey: "ClientID")
        }
        
        
        
    }
    
}
