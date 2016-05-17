//
//  SimplePCMRecorder.swift

import Foundation

import Foundation
import CoreAudio
import AudioToolbox

struct RecorderState {
    var setupComplete: Bool
    var dataFormat: AudioStreamBasicDescription
    var queue: UnsafeMutablePointer<AudioQueueRef>
    var buffers: [AudioQueueBufferRef]
    var recordFile: AudioFileID
    var bufferByteSize: UInt32
    var currentPacket: Int64
    var isRunning: Bool
    var recordPacket: Int64
    var errorHandler: ((error:NSError) -> Void)?
}

class SimplePCMRecorder {
    
    private var recorderState: RecorderState
    
    init(numberBuffers:Int) {
        self.recorderState = RecorderState(
            setupComplete: false,
            dataFormat: AudioStreamBasicDescription(),
            queue: UnsafeMutablePointer<AudioQueueRef>.alloc(1),
            buffers: Array<AudioQueueBufferRef>(count: numberBuffers, repeatedValue: nil),
            recordFile:AudioFileID(),
            bufferByteSize: 0,
            currentPacket: 0,
            isRunning: false,
            recordPacket: 0,
            errorHandler: nil)
    }
    
    deinit {
        self.recorderState.queue.dealloc(1)
    }
    
    func setupForRecording(outputFileName:String, sampleRate:Float64, channels:UInt32, bitsPerChannel:UInt32, errorHandler: ((error:NSError) -> Void)?) throws {
        self.recorderState.dataFormat.mFormatID = kAudioFormatLinearPCM
        self.recorderState.dataFormat.mSampleRate = sampleRate
        self.recorderState.dataFormat.mChannelsPerFrame = channels
        self.recorderState.dataFormat.mBitsPerChannel = bitsPerChannel
        self.recorderState.dataFormat.mFramesPerPacket = 1
        self.recorderState.dataFormat.mBytesPerFrame = self.recorderState.dataFormat.mChannelsPerFrame * (self.recorderState.dataFormat.mBitsPerChannel / 8)
        self.recorderState.dataFormat.mBytesPerPacket = self.recorderState.dataFormat.mBytesPerFrame * self.recorderState.dataFormat.mFramesPerPacket
        
        self.recorderState.dataFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked
        
        self.recorderState.errorHandler = errorHandler
        
        try osReturningCall { AudioFileCreateWithURL(NSURL(fileURLWithPath: outputFileName), kAudioFileWAVEType, &self.recorderState.dataFormat, AudioFileFlags.DontPageAlignAudioData.union(.EraseFile), &self.recorderState.recordFile) }
        
        self.recorderState.setupComplete = true
    }
    
    func startRecording() throws {
        
        guard self.recorderState.setupComplete else { throw NSError(domain: Config.Error.ErrorDomain, code: Config.Error.PCMSetupIncompleteErrorCode, userInfo: [NSLocalizedDescriptionKey : "Setup needs to be called before starting"]) }
        
        let osAQNI = AudioQueueNewInput(&self.recorderState.dataFormat, { (inUserData:UnsafeMutablePointer<Void>, inAQ:AudioQueueRef, inBuffer:AudioQueueBufferRef, inStartTime:UnsafePointer<AudioTimeStamp>, inNumPackets:UInt32, inPacketDesc:UnsafePointer<AudioStreamPacketDescription>) -> Void in
            
            let internalRSP = unsafeBitCast(inUserData, UnsafeMutablePointer<RecorderState>.self)
            
            if inNumPackets > 0 {
                var packets = inNumPackets
                
                let os = AudioFileWritePackets(internalRSP.memory.recordFile, false, inBuffer.memory.mAudioDataByteSize, inPacketDesc, internalRSP.memory.recordPacket, &packets, inBuffer.memory.mAudioData)
                if os != 0 && internalRSP.memory.errorHandler != nil {
                    internalRSP.memory.errorHandler!(error:NSError(domain: NSOSStatusErrorDomain, code: Int(os), userInfo: nil))
                }
                
                internalRSP.memory.recordPacket += Int64(packets)
            }
            
            if internalRSP.memory.isRunning {
                let os = AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, nil)
                if os != 0 && internalRSP.memory.errorHandler != nil {
                    internalRSP.memory.errorHandler!(error:NSError(domain: NSOSStatusErrorDomain, code: Int(os), userInfo: nil))
                }
            }
            
            }, &self.recorderState, nil, nil, 0, self.recorderState.queue)
        
        guard osAQNI == 0 else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(osAQNI), userInfo: nil) }
        
        let bufferByteSize = try self.computeRecordBufferSize(self.recorderState.dataFormat, seconds: 0.5)
        for (var i = 0; i < self.recorderState.buffers.count; ++i) {
            try osReturningCall { AudioQueueAllocateBuffer(self.recorderState.queue.memory, UInt32(bufferByteSize), &self.recorderState.buffers[i]) }
            
            try osReturningCall { AudioQueueEnqueueBuffer(self.recorderState.queue.memory, self.recorderState.buffers[i], 0, nil) }
        }
        
        try osReturningCall { AudioQueueStart(self.recorderState.queue.memory, nil) }
        
        self.recorderState.isRunning = true
    }
    
    func stopRecording() throws {
        self.recorderState.isRunning = false
        
        try osReturningCall { AudioQueueStop(self.recorderState.queue.memory, true) }
        try osReturningCall { AudioQueueDispose(self.recorderState.queue.memory, true) }
        try osReturningCall { AudioFileClose(self.recorderState.recordFile) }
    }
    
    private func computeRecordBufferSize(format:AudioStreamBasicDescription, seconds:Double) throws -> Int {
        
        let framesNeededForBufferTime = Int(ceil(seconds * format.mSampleRate))
        
        if format.mBytesPerFrame > 0 {
            return framesNeededForBufferTime * Int(format.mBytesPerFrame)
        } else {
            var maxPacketSize = UInt32(0)
            
            if format.mBytesPerPacket > 0 {
                maxPacketSize = format.mBytesPerPacket
            } else {
                try self.getAudioQueueProperty(kAudioQueueProperty_MaximumOutputPacketSize, value: &maxPacketSize)
            }
            
            var packets = 0
            if format.mFramesPerPacket > 0 {
                packets = framesNeededForBufferTime / Int(format.mFramesPerPacket)
            } else {
                packets = framesNeededForBufferTime
            }
            
            if packets == 0 {
                packets = 1
            }
            
            return packets * Int(maxPacketSize)
        }
        
    }
    
    private func osReturningCall(osCall: () -> OSStatus) throws {
        let os = osCall()
        if os != 0 {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(os), userInfo: nil)
        }
    }
    
    private func getAudioQueueProperty<T>(propertyId:AudioQueuePropertyID, inout value:T) throws {
        
        let propertySize = UnsafeMutablePointer<UInt32>.alloc(1)
        propertySize.memory = UInt32(sizeof(T))
        
        let os = AudioQueueGetProperty(self.recorderState.queue.memory,
                                       propertyId,
                                       &value,
                                       propertySize)
        
        propertySize.dealloc(1)
        
        guard os == 0 else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(os), userInfo: nil) }
        
    }
}