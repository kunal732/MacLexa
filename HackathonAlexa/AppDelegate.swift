//
//  AppDelegate.swift
//  HackathonAlexa
//
//  Created by KUNAL BATRA on 5/16/16.
//  Copyright © 2016 Kunal Batra. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!
    let statusItem = NSStatusBar.systemStatusBar().statusItemWithLength(-2)
    let popover = NSPopover()
    var eventMonitor: EventMonitor?
    var recordbool = false


    func applicationDidFinishLaunching(aNotification: NSNotification) {
        if let button = statusItem.button {
            button.image = NSImage(named: "StatusBarButtonImage")
            button.action = #selector(self.togglePopover(_:))
        }
        
        
        popover.contentViewController = AlexaViewController()
        let alexa = AlexaStatusController()
        alexa.awakeFromNib()
        
        eventMonitor = EventMonitor(mask: .FlagsChangedMask ) { [unowned self] event in
            if (event?.keyCode == 58 && !self.recordbool){
        
                print("recording")
                self.recordbool = true
                alexa.toggleRecord()
            }
            else if (event?.keyCode == 58 && self.recordbool){
                
                print ("stopped recording")
                self.recordbool = false
                alexa.toggleRecord()
            }
            
            
        }
        eventMonitor?.start()
        
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }
    
    func showPopover(sender: AnyObject?) {
        if let button = statusItem.button {
            popover.showRelativeToRect(button.bounds, ofView: button, preferredEdge: NSRectEdge.MinY)
        }
    }
    
    func closePopover(sender: AnyObject?) {
        popover.performClose(sender)
    }
    
    func togglePopover(sender: AnyObject?) {
        if popover.shown {
            closePopover(sender)
        } else {
            showPopover(sender)
        }
    }
    
    

}

