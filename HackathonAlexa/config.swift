//
//  config.swift

import Foundation

struct Config {

    struct Debug {
        static let General = true
        static let Errors = true
        static let HTTPRequest = true
        static let HTTPResponse = true
    }
    
    struct Error {
        static let ErrorDomain = "net.ioncannon.SimplePCMRecorderError"
        
        static let PCMSetupIncompleteErrorCode = 1
        
        static let AVSUploaderSetupIncompleteErrorCode = 2
        static let AVSAPICallErrorCode = 3
        static let AVSResponseBorderParseErrorCode = 4
    }
    
}
