//
// Copyright (c) Microsoft. All rights reserved.
// Licensed under the MIT license. See LICENSE.md file in the project root for full license information.
//

import Foundation
import SwiftUI
import AVFoundation
import AzureAIVisionFace

public enum PixelFormat
{
    case abgr
    case argb
    case bgra
    case rgba
    
    func getFourCCString()-> String {
        switch self {
        case .abgr:
            return "ABGR"
        case .argb:
            return "ARGB"
        case .bgra:
            return "BGRA"
        case .rgba:
            return "RGBA"
        }
    }
}

extension CGBitmapInfo
{
    public static var byteOrder16Host: CGBitmapInfo {
        return CFByteOrderGetCurrent() == Int(CFByteOrderLittleEndian.rawValue) ? .byteOrder16Little : .byteOrder16Big
    }
    
    public static var byteOrder32Host: CGBitmapInfo {
        return CFByteOrderGetCurrent() == Int(CFByteOrderLittleEndian.rawValue) ? .byteOrder32Little : .byteOrder32Big
    }
}

extension CGBitmapInfo
{
    public var pixelFormat: PixelFormat? {
        
        // AlphaFirst – the alpha channel is next to the red channel, argb and bgra are both alpha first formats.
        // AlphaLast – the alpha channel is next to the blue channel, rgba and abgr are both alpha last formats.
        // LittleEndian – blue comes before red, bgra and abgr are little endian formats.
        // Little endian ordered pixels are BGR (BGRX, XBGR, BGRA, ABGR, BGR).
        // BigEndian – red comes before blue, argb and rgba are big endian formats.
        // Big endian ordered pixels are RGB (XRGB, RGBX, ARGB, RGBA, RGB).
        
        let alphaInfo: CGImageAlphaInfo? = CGImageAlphaInfo(rawValue: self.rawValue & type(of: self).alphaInfoMask.rawValue)
        let alphaFirst: Bool = alphaInfo == .premultipliedFirst || alphaInfo == .first || alphaInfo == .noneSkipFirst
        let alphaLast: Bool = alphaInfo == .premultipliedLast || alphaInfo == .last || alphaInfo == .noneSkipLast
        let endianLittle: Bool = self.contains(.byteOrder32Little)
        
        // This is slippery… while byte order host returns little endian, default bytes are stored in big endian
        // format. Here we just assume if no byte order is given, then simple RGB is used, aka big endian, though…
        
        if alphaFirst && endianLittle {
            return .bgra
        } else if alphaFirst {
            return .argb
        } else if alphaLast && endianLittle {
            return .abgr
        } else if alphaLast {
            return .rgba
        } else {
            return nil
        }
    }
}

extension NSMutableData {
    func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            self.append(data)
        }
    }
}

func getSourceFromImage(image: UIImage) ->VisionFrameSource {
    let width = image.size.width
    let height = image.size.height
    let stride = image.cgImage?.bytesPerRow
    let bitmatpinfo = image.cgImage?.bitmapInfo
    let fourcc = image.cgImage?.bitmapInfo.pixelFormat?.getFourCCString()
    let format = try! VisionFrameFormat(fourCCFormat: fourcc!, width: Int(width), height: Int(height), stride: Int(stride!))
    let source = try! VisionFrameSource(format: format)
    
    return source
}

func getFrameFromImage(image: UIImage) ->VisionFrame {
    let width = image.size.width
    let height = image.size.height
    let stride = image.cgImage?.bytesPerRow
    let rawData = image.cgImage?.dataProvider?.data
    let frame = try! VisionFrame(data: rawData! as Data)
    let fourcc = image.cgImage?.bitmapInfo.pixelFormat?.getFourCCString()
    let data = Data(fourcc!.utf8)
    let hexString = data.map{ String(format:"%x", $0) }.joined()
    let decimal = UInt32(hexString, radix:16)!
    
    // the property values are subject to change, will moved to the internal Vision Source SDK.
    frame.properties?.setPropertyValue(String(decimal), forKey: "frame.format.pixel_format")
    frame.properties?.setPropertyValue(String(Int(height)), forKey: "frame.format.height")
    frame.properties?.setPropertyValue(String(Int(width)), forKey: "frame.format.width")
    frame.properties?.setPropertyValue(String(stride!), forKey: "frame.format.stride")
    frame.properties?.setPropertyValue("SourceKind_Color", forKey: "frame.format.source_kind")
    
    return frame
}

func RecognitionStatusToString(status: FaceRecognitionStatus) -> String {
    switch status {
    case .notComputed: return LocalizationStrings.recognitionStatusNotComputed
    case .failed: return LocalizationStrings.recognitionStatusFailed
    case .notRecognized: return LocalizationStrings.recognitionStatusNotRecognized
    case .recognized: return LocalizationStrings.recognitionStatusRecognized
    default: return LocalizationStrings.recognitionStatusUnknown
    }
}

func RecognitionFailureToString(reason: FaceRecognitionFailureReason) -> String {
    switch reason {
        case .excessiveFaceBrightness: return LocalizationStrings.recognitionFailureExcessiveFaceBrightness
        case .excessiveImageBlurDetected: return LocalizationStrings.recognitionFailureExcessiveImageBlurDetected
        case .faceEyeRegionNotVisible: return LocalizationStrings.recognitionFailureFaceEyeRegionNotVisible
        case .faceNotFrontal: return LocalizationStrings.recognitionFailureFaceNotFrontal
        case .none: return LocalizationStrings.recognitionFailureNone
        case .faceNotFound: return LocalizationStrings.recognitionFailureFaceNotFound
        case .multipleFaceFound: return LocalizationStrings.recognitionFailureMultipleFaceFound
        case .contentDecodingError: return LocalizationStrings.recognitionFailureContentDecodingError
        case .imageSizeIsTooLarge: return LocalizationStrings.recognitionFailureImageSizeIsTooLarge
        case .imageSizeIsTooSmall: return LocalizationStrings.recognitionFailureImageSizeIsTooSmall
        default: return LocalizationStrings.recognitionFailureGenericFailure
    }
}

func LivenessStatusToString(status: FaceLivenessStatus) -> String {
    switch status {
        case .notComputed: return LocalizationStrings.livenessStatusNotComputed
        case .failed: return LocalizationStrings.livenessStatusFailed
        case .live: return LocalizationStrings.livenessStatusLive
        case .spoof: return LocalizationStrings.livenessStatusSpoof
        default: return LocalizationStrings.livenessStatusUnknown
    }
}

func LivenessFailureReasonToString(reason: FaceLivenessFailureReason) -> String {
    switch reason {
        case .none: return LocalizationStrings.livenessFailureNone
        case .faceMouthRegionNotVisible: return LocalizationStrings.livenessFailureFaceMouthRegionNotVisible
        case .faceEyeRegionNotVisible: return LocalizationStrings.livenessFailureFaceEyeRegionNotVisible
        case .excessiveImageBlurDetected: return LocalizationStrings.livenessFailureExcessiveImageBlurDetected
        case .excessiveFaceBrightness: return LocalizationStrings.livenessFailureExcessiveFaceBrightness
        case .faceWithMaskDetected: return LocalizationStrings.livenessFailureFaceWithMaskDetected
        case .actionNotPerformed: return LocalizationStrings.livenessFailureActionNotPerformed
        case .timedOut: return LocalizationStrings.livenessFailureTimedOut
        case .environmentNotSupported: return LocalizationStrings.livenessFailureEnvironmentNotSupported
        default: return LocalizationStrings.livenessFailureUnknown
    }
}

func FaceActionToString(action: FaceActionRequiredFromApplication) -> String {
    switch action {
        case .none: return LocalizationStrings.faceActionNone
        case .brightenDisplay: return LocalizationStrings.faceActionBrightenDisplay
        case .darkenDisplay: return LocalizationStrings.faceActionDarkenDisplay
        default: return LocalizationStrings.faceActionNone
    }
}

func FaceFeedbackToString(feedback: FaceAnalyzingFeedbackForFace) -> String {
    switch feedback {
        case .faceNotCentered: return LocalizationStrings.faceFeedbackFaceNotCentered
        case .lookAtCamera: return LocalizationStrings.faceFeedbackLookAtCamera
        case .moveBack: return LocalizationStrings.faceFeedbackMoveBack
        case .moveCloser: return LocalizationStrings.faceFeedbackMoveCloser
        case .tooMuchMovement: return LocalizationStrings.faceFeedbackTooMuchMovement
        case .attentionNotNeeded: return LocalizationStrings.faceFeedbackAttentionNotNeeded
        default: return LocalizationStrings.faceFeedbackHoldStill
    }
}

func FaceWarningToString(warning: FaceAnalyzingWarning) -> String {
    switch warning {
        case .faceTooBright: return LocalizationStrings.faceWarningFaceTooBright
        case .faceTooDark: return LocalizationStrings.faceWarningFaceTooDark
        case .tooBlurry: return LocalizationStrings.faceWarningTooBlurry
        case .lowFidelityFaceRegion: return LocalizationStrings.faceWarningLowFidelityFaceRegion
        default: return LocalizationStrings.faceWarningNone
    }
}

func FaceTrackingStateToString(state: FaceTrackingState) -> String {
    switch state {
        case .none: return LocalizationStrings.faceTrackingStateNone
        case .new: return LocalizationStrings.faceTrackingStateNew
        case .tracked: return LocalizationStrings.faceTrackingStateTracked
        case .lost: return LocalizationStrings.faceTrackingStateLost
        default: return LocalizationStrings.faceTrackingStateUnknown
    }
}

func loadDataFromFile(sessionData: SessionData) {
    let fileManager = FileManager.default
    guard let directory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
        return
    }

    let fileURL = directory.appendingPathComponent("endpoint_key.txt")

    if let data = try? Data(contentsOf: fileURL),
        let content = String(data: data, encoding: .utf8) {
        let components = content.split(separator: "\n")
        if components.count == 2 {
            sessionData.endpoint = String(components[0])
            sessionData.key = String(components[1])
        }
    }
}

func saveDataToFile(sessionData: SessionData) {
    let fileManager = FileManager.default
    guard let directory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
        return
    }

    let fileURL = directory.appendingPathComponent("endpoint_key.txt")
    
    let data = "\(sessionData.endpoint)\n\(sessionData.key)".data(using: .utf8)
    try? data?.write(to: fileURL)
}

func obtainToken(usingEndpoint endpoint: String,
                 key: String, withVerify: Bool) -> String? {
    var createSessionUri = URL(string: endpoint + "/face/v1.1-preview.1/detectLiveness/singleModal/sessions")!
    if (withVerify)
    {
        createSessionUri = URL(string: endpoint + "/face/v1.1-preview.1/detectLivenessWithVerify/singleModal/sessions")!
    }
    var request = URLRequest(url: createSessionUri)
    request.httpMethod = "POST"

    request.setValue(key, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")

    let parameters: [String: Any] = [
        "livenessOperationMode": "Passive",
        "deviceCorrelationId": UUID().uuidString
    ]

    do {
        let jsonData = try JSONSerialization.data(withJSONObject: parameters, options: [])
        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    } catch {
        print("Error encoding parameters: \(error)")
        return nil
    }

    let session = URLSession.shared
    let group = DispatchGroup()
    var result: String?

    group.enter()
    var authToken: String?

    let task: URLSessionTask = session.dataTask(with: request) { data, response, error in
        defer {
            group.leave()
        }

        if let error = error {
            print("Error: \(error)")
            return
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("Invalid response")
            return
        }

        if (200..<300).contains(httpResponse.statusCode) {
            if let data = data {
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                        if let authTokenValue = json["authToken"] as? String {
                            authToken = authTokenValue
                            print(authToken)
                        }
                    }
                } catch {
                    print("Error parsing JSON: \(error)")
                }
            }
        } else {
            print("Error status code: \(httpResponse.statusCode)")
        }
    }

    task.resume()
    group.wait()

    return authToken
}

func convertToRGBImage(inputImage: CGImage) -> CGImage? {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let width = inputImage.width
    let height = inputImage.height

    // Create a bitmap context with RGB format
    guard let context = CGContext(data: nil,
                                  width: width,
                                  height: height,
                                  bitsPerComponent: 8,
                                  bytesPerRow: width * 4,
                                  space: colorSpace,
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
    else {
        return nil
    }

    // Draw the original image onto the context
    context.draw(inputImage, in: CGRect(x: 0, y: 0, width: width, height: height))

    // Retrieve the converted image from the context
    let outputImage = context.makeImage()

    return outputImage
}
