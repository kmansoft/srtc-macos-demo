//
//  VideoEncoderWrappper.swift
//  srtc-macos-demo
//
//  Created by Kostya Vasilyev on 4/26/25.
//

import Foundation
import AVFoundation
import CoreImage
import VideoToolbox

class VideoEncodedFrame {
    let csd: [NSData]?
    let data: NSData

    init (csd: [NSData]?, data: NSData) {
        self.csd = csd
        self.data = data
    }
}

protocol VideoEncodedFrameCallback {
    func onCompressedFrame(layer: String?, frame: VideoEncodedFrame)
}

class VideoEncoderWrappper {

    private let codec: CMVideoCodecType
    private let layer: String?
    private let queue: DispatchQueue
    private let width: Int
    private let height: Int
    private var callback: VideoEncodedFrameCallback?

    private var compressionSession: VTCompressionSession?
    private var frameCount: Int = 0

    private let kAnnexBHeader: [UInt8] = [0x00, 0x00, 0x00, 0x01]

    init(layer: String?, width: Int, height: Int,
         codecType: CMVideoCodecType,
         profileLevelId: CFString,
         framesPerSecond: Int,
         bitrate: Int,
         callback: VideoEncodedFrameCallback) {
        self.codec = codecType
        self.layer = layer
        self.queue = DispatchQueue(label: "encoder \(layer ?? "default")")
        self.width = width
        self.height = height
        self.callback = callback

        var session: VTCompressionSession?
        let status = VTCompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            width: Int32(width),
            height: Int32(height),
            codecType: codecType,
            encoderSpecification: nil,
            imageBufferAttributes: nil,
            compressedDataAllocator: nil,
            outputCallback: nil,
            refcon: Unmanaged.passUnretained(self).toOpaque(),
            compressionSessionOut: &session
        )

        guard status == noErr, let session = session else {
            NSLog("Failed to create compression session: \(status)")
            return
        }

        self.compressionSession = session

        // Configure the session
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ProfileLevel, value: profileLevelId)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AverageBitRate, value: NSNumber(value: bitrate))
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ExpectedFrameRate, value: NSNumber(value: framesPerSecond))
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AllowFrameReordering, value: kCFBooleanFalse)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_MaxKeyFrameInterval, value: NSNumber(value: 2 * framesPerSecond))

        // Prepare the session
        VTCompressionSessionPrepareToEncodeFrames(session)
    }

    deinit {
        stop()
    }

    func stop() {
        if let session = compressionSession {
            VTCompressionSessionCompleteFrames(session, untilPresentationTimeStamp: .invalid)
            VTCompressionSessionInvalidate(session)
        }
        compressionSession = nil
        callback = nil
    }

    func submitFrameForCompression(sampleBuffer: CMSampleBuffer) {
        guard let compressionSession = compressionSession,
              let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        let presentationTimeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let duration = CMSampleBufferGetDuration(sampleBuffer)

        let frameProperties = [
            kVTEncodeFrameOptionKey_ForceKeyFrame: frameCount == 0 ? kCFBooleanTrue : kCFBooleanFalse
        ] as CFDictionary

        frameCount += 1

        // Encode the frame
        let status = VTCompressionSessionEncodeFrame(
            compressionSession,
            imageBuffer: imageBuffer,
            presentationTimeStamp: presentationTimeStamp,
            duration: duration,
            frameProperties: frameProperties,
            infoFlagsOut: nil,
            outputHandler: { [weak self] status, flags, sampleBuffer in
                guard let self = self,
                      status == noErr,
                      let sampleBuffer = sampleBuffer else { return }

                self.onCompressedFrame(sampleBuffer)
            }
        )

        if status != noErr {
            NSLog("Failed to encode frame: \(status)")
        }
    }

    private func onCompressedFrame(_ sampleBuffer: CMSampleBuffer) {
        if codec == kCMVideoCodecType_H264 || codec == kCMVideoCodecType_HEVC {
            if let naluList = extractNALUnits(from: sampleBuffer) {
                let data = NSMutableData()
                for nalu in naluList {
                    data.append(Data(kAnnexBHeader))
                    data.append(nalu as Data)
                }

                var csd: [NSData]?
                for data in naluList {
                    if codec == kCMVideoCodecType_H264 {
                        let type = data[0] & 0x1F
                        if type == 5 {
                            let csdDataList = getH264ParameterSets(from: sampleBuffer)
                            csd = convertCSDList(csdDataList)
                        }
                    } else if codec == kCMVideoCodecType_HEVC {
                        let type = (data[0] >> 1) & 0x3F
                        if type >= 19 && type <= 21 {
                            let csdDataList = getH265ParameterSets(from: sampleBuffer)
                            csd = convertCSDList(csdDataList)
                        }
                    }
                }

                let frame = VideoEncodedFrame(csd: csd, data: data)
                callback?.onCompressedFrame(layer: layer, frame: frame)
            }
        }
    }

    private func convertCSDList(_ csdDataList: [NSData]?) -> [NSData]? {
        guard let csdDataList = csdDataList else {
            return nil
        }

        var list: [NSData] = []
        for csdDataItem in csdDataList {
            list.append(preprendAnnexB(what: csdDataItem))
        }

        return list
    }

    private func preprendAnnexB(what: NSData) -> NSData {
        let data = NSMutableData()
        data.append(Data(kAnnexBHeader))
        data.append(what as Data)
        return data
    }
}

extension NSData {
    func hexEncodedString() -> String {
        let alphabet = Array("0123456789abcdef")
        var res = ""
        res.reserveCapacity(count * 2 + count - 1)
        for i in 0 ..< count {
            if i != 0 {
                res += ":"
            }
            let b = self[i]
            res.append(alphabet[Int(b >> 4)])
            res.append(alphabet[Int(b & 0x0f)])
        }
        return res
    }
}

func extractNALUnits(from sampleBuffer: CMSampleBuffer) -> [NSData]? {
    guard let dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
        return nil
    }

    var lengthAtOffset: Int = 0
    var totalLength: Int = 0
    var dataPointer: UnsafeMutablePointer<Int8>?

    let status = CMBlockBufferGetDataPointer(
        dataBuffer,
        atOffset: 0,
        lengthAtOffsetOut: &lengthAtOffset,
        totalLengthOut: &totalLength,
        dataPointerOut: &dataPointer
    )

    guard status == noErr, let dataPointer = dataPointer else {
        return nil
    }

    let data = Data(bytes: dataPointer, count: totalLength)

    // Parse NAL units (assuming AVCC format with 4-byte length prefixes)
    var nalUnits: [NSData] = []
    var index = 0

    while index < totalLength {
        // Read NAL unit size (4 bytes)
        guard index + 4 <= totalLength else { break }

        let nalSizeData = data.subdata(in: index..<index+4)
        var nalSize: UInt32 = 0
        (nalSizeData as NSData).getBytes(&nalSize, length: 4)

        // Convert from big-endian to host byte order
        nalSize = CFSwapInt32BigToHost(nalSize)

        index += 4

        // Ensure we have enough data for the NAL unit
        guard index + Int(nalSize) <= totalLength else { break }

        // Extract NAL unit
        let nalData = data.subdata(in: index..<index+Int(nalSize)) as NSData

        // Append to output
        nalUnits.append(nalData)

        index += Int(nalSize)
    }

    return nalUnits
}

func getH264ParameterSets(from sampleBuffer: CMSampleBuffer) -> [NSData]? {
    guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else {
        return nil
    }

    var parameterSetCount = 0
    CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
        formatDescription,
        parameterSetIndex: 0,
        parameterSetPointerOut: nil,
        parameterSetSizeOut: nil,
        parameterSetCountOut: &parameterSetCount,
        nalUnitHeaderLengthOut: nil
    )

    guard parameterSetCount >= 2 else {
        return nil
    }

    var parameterSetPointer: UnsafePointer<UInt8>?
    var parameterSetSize: Int = 0
    var csdList: [NSData] = []

    for i in 0..<parameterSetCount {
        CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
            formatDescription,
            parameterSetIndex: i,
            parameterSetPointerOut: &parameterSetPointer,
            parameterSetSizeOut: &parameterSetSize,
            parameterSetCountOut: nil,
            nalUnitHeaderLengthOut: nil
        )

        if let pointer = parameterSetPointer, parameterSetSize > 0 {
            let csdItemData = NSData(bytes: pointer, length: parameterSetSize)
            csdList.append(csdItemData)
        }
    }

    return csdList
}

func getH265ParameterSets(from sampleBuffer: CMSampleBuffer) -> [NSData]? {
    guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else {
        return nil
    }

    var parameterSetCount = 0
    CMVideoFormatDescriptionGetHEVCParameterSetAtIndex(
        formatDescription,
        parameterSetIndex: 0,
        parameterSetPointerOut: nil,
        parameterSetSizeOut: nil,
        parameterSetCountOut: &parameterSetCount,
        nalUnitHeaderLengthOut: nil
    )

    guard parameterSetCount >= 3 else {
        return nil
    }

    var parameterSetPointer: UnsafePointer<UInt8>?
    var parameterSetSize: Int = 0
    var csdList: [NSData] = []

    for i in 0..<parameterSetCount {
        CMVideoFormatDescriptionGetHEVCParameterSetAtIndex(
            formatDescription,
            parameterSetIndex: i,
            parameterSetPointerOut: &parameterSetPointer,
            parameterSetSizeOut: &parameterSetSize,
            parameterSetCountOut: nil,
            nalUnitHeaderLengthOut: nil
        )

        if let pointer = parameterSetPointer, parameterSetSize > 0 {
            let csdData = NSData(bytes: pointer, length: parameterSetSize)
            csdList.append(csdData)
        }

    }

    return csdList
}

