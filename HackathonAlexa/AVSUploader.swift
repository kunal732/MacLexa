//
//  AVSUploader.swift

import Foundation

struct PartData {
    var headers: [String:String]
    var data: NSData
}

class AVSUploader: NSObject, NSURLSessionTaskDelegate {
    
    var authToken:String?
    var jsonData:String?
    var audioData:NSData?
    
    var errorHandler: ((error:NSError) -> Void)?
    var progressHandler: ((progress:Double) -> Void)?
    var successHandler: ((data:NSData, parts:[PartData]) -> Void)?
    
    private var session: NSURLSession!
    
    func start() throws {
        if self.authToken == nil || self.jsonData == nil || self.audioData == nil {
            throw NSError(domain: Config.Error.ErrorDomain, code: Config.Error.AVSUploaderSetupIncompleteErrorCode, userInfo: [NSLocalizedDescriptionKey : "AVS upload options not set"])
        }
        
        if self.session == nil {
            self.session = NSURLSession(configuration: NSURLSession.sharedSession().configuration, delegate: self, delegateQueue: nil)
        }
        
        self.postRecording(self.authToken!, jsonData: self.jsonData!, audioData: self.audioData!)
    }
    
    private func parseResponse(data:NSData, boundry:String) -> [PartData] {
        
        let innerBoundry = "\(boundry)\r\n".dataUsingEncoding(NSUTF8StringEncoding)!
        let endBoundry = "\r\n\(boundry)--\r\n".dataUsingEncoding(NSUTF8StringEncoding)!
        
        var innerRanges = [NSRange]()
        var lastStartingLocation = 0
        
        var boundryRange = data.rangeOfData(innerBoundry, options: NSDataSearchOptions(), range: NSMakeRange(lastStartingLocation, data.length))
        while(boundryRange.location != NSNotFound) {
            
            lastStartingLocation = boundryRange.location + boundryRange.length
            boundryRange = data.rangeOfData(innerBoundry, options: NSDataSearchOptions(), range: NSMakeRange(lastStartingLocation, data.length - lastStartingLocation))
            
            if boundryRange.location != NSNotFound {
                innerRanges.append(NSMakeRange(lastStartingLocation, boundryRange.location - innerBoundry.length))
            } else {
                innerRanges.append(NSMakeRange(lastStartingLocation, data.length - lastStartingLocation))
            }
        }
        
        var partData = [PartData]()
        
        for innerRange in innerRanges {
            let innerData = data.subdataWithRange(innerRange)
            
            let headerRange = innerData.rangeOfData("\r\n\r\n".dataUsingEncoding(NSUTF8StringEncoding)!, options: NSDataSearchOptions(), range: NSMakeRange(0, innerRange.length))
            
            var headers = [String:String]()
            if let headerData = NSString(data: innerData.subdataWithRange(NSMakeRange(0, headerRange.location)), encoding: NSUTF8StringEncoding) as? String {
                let headerLines = headerData.characters.split{$0 == "\r\n"}.map{String($0)}
                for headerLine in headerLines {
                    let headerSplit = headerLine.characters.split{ $0 == ":" }.map{String($0)}
                    headers[headerSplit[0]] = headerSplit[1].stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
                }
            }
            
            let startLocation = headerRange.location + headerRange.length
            let contentData = innerData.subdataWithRange(NSMakeRange(startLocation, innerRange.length - startLocation))
            
            let endContentRange = contentData.rangeOfData(endBoundry, options: NSDataSearchOptions(), range: NSMakeRange(0, contentData.length))
            if endContentRange.location != NSNotFound {
                partData.append(PartData(headers: headers, data: contentData.subdataWithRange(NSMakeRange(0, endContentRange.location))))
            } else {
                partData.append(PartData(headers: headers, data: contentData))
            }
        }
        
        return partData
    }
    
    private func postRecording(authToken:String, jsonData:String, audioData:NSData) {
        let request = NSMutableURLRequest(URL: NSURL(string: "https://access-alexa-na.amazon.com/v1/avs/speechrecognizer/recognize")!)
        request.cachePolicy = NSURLRequestCachePolicy.ReloadIgnoringCacheData
        request.HTTPShouldHandleCookies = false
        request.timeoutInterval = 60
        request.HTTPMethod = "POST"
        
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        
        let boundry = NSUUID().UUIDString
        let contentType = "multipart/form-data; boundary=\(boundry)"
        
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        
        let bodyData = NSMutableData()
        
        bodyData.appendData("--\(boundry)\r\n".dataUsingEncoding(NSUTF8StringEncoding)!)
        bodyData.appendData("Content-Disposition: form-data; name=\"metadata\"\r\n".dataUsingEncoding(NSUTF8StringEncoding)!)
        bodyData.appendData("Content-Type: application/json; charset=UTF-8\r\n\r\n".dataUsingEncoding(NSUTF8StringEncoding)!)
        bodyData.appendData(jsonData.dataUsingEncoding(NSUTF8StringEncoding)!)
        bodyData.appendData("\r\n".dataUsingEncoding(NSUTF8StringEncoding)!)
        
        bodyData.appendData("--\(boundry)\r\n".dataUsingEncoding(NSUTF8StringEncoding)!)
        bodyData.appendData("Content-Disposition: form-data; name=\"audio\"\r\n".dataUsingEncoding(NSUTF8StringEncoding)!)
        bodyData.appendData("Content-Type: audio/L16; rate=16000; channels=1\r\n\r\n".dataUsingEncoding(NSUTF8StringEncoding)!)
        bodyData.appendData(audioData)
        bodyData.appendData("\r\n".dataUsingEncoding(NSUTF8StringEncoding)!)
        
        bodyData.appendData("--\(boundry)--\r\n".dataUsingEncoding(NSUTF8StringEncoding)!)
        
        let uploadTask = self.session.uploadTaskWithRequest(request, fromData: bodyData) { (data:NSData?, response:NSURLResponse?, error:NSError?) -> Void in
            
            self.progressHandler?(progress: 100.0)
            
            if let e = error {
                self.errorHandler?(error: e)
            } else {
                if let httpResponse = response as? NSHTTPURLResponse {
                    
                    if httpResponse.statusCode >= 200 && httpResponse.statusCode <= 299 {
                        if let responseData = data, let contentTypeHeader = httpResponse.allHeaderFields["Content-Type"] {
                            var boundry: String?
                            let ctbRange = contentTypeHeader.rangeOfString("boundary=.*?;", options: .RegularExpressionSearch)
                            if ctbRange.location != NSNotFound {
                                let boundryNSS = contentTypeHeader.substringWithRange(ctbRange) as NSString
                                boundry = boundryNSS.substringWithRange(NSRange(location: 9, length: boundryNSS.length - 10))
                            }
                            
                            if let b = boundry {
                                self.successHandler?(data: responseData, parts:self.parseResponse(responseData, boundry: b))
                            } else {
                                self.errorHandler?(error: NSError(domain: Config.Error.ErrorDomain, code: Config.Error.AVSResponseBorderParseErrorCode, userInfo: [NSLocalizedDescriptionKey : "Could not find boundry in AVS response"]))
                            }
                        }
                    } else {
                        var message: NSString?
                        if data != nil {
                            do {
                                if let errorDictionary = try NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions(rawValue: 0)) as? [String:AnyObject], let errorValue = errorDictionary["error"] as? [String:String], let errorMessage = errorValue["message"] {
                                    
                                    message = errorMessage
                                    
                                } else {
                                    message = NSString(data: data!, encoding: NSUTF8StringEncoding)
                                }
                            } catch {
                                message = NSString(data: data!, encoding: NSUTF8StringEncoding)
                            }
                        }
                        let finalMessage = message == nil ? "" : message!
                        self.errorHandler?(error: NSError(domain: Config.Error.ErrorDomain, code: Config.Error.AVSAPICallErrorCode, userInfo: [NSLocalizedDescriptionKey : "AVS error: \(httpResponse.statusCode) - \(finalMessage)"]))
                    }
                    
                }
            }
        }
        
        uploadTask.resume()
    }
    
    func URLSession(session: NSURLSession, task: NSURLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        
        self.progressHandler?(progress:Double(Double(totalBytesSent) / Double(totalBytesExpectedToSend)) * 100.0)
        
    }
}
