//
//  SRModel.swift
//  super8x
//
//  Created by 間嶋大輔 on 2022/01/30.
//

import Foundation
import UIKit
import Vision
import VideoToolbox

protocol SRModelDelegate:NSObjectProtocol {
    func startSR(index:Int)
    func endSR(index:Int,time:Double)
    func processingEnded()
    func endAllProcess()
    func srImagesUpdated()
    func srImageDeleted()
    func srImageURLRemoved()
    func srImageSavingStart(index:Int)
    func srImageSaved(index:Int)
    func gotError()
}

class SRModel: NSObject {
    
    enum SRMode {
        case simple
        case tile
    }
    
    var srMode: SRMode = .tile
    
    var isProcessing = false
    var proccessingIndex = 0
    var savingIndex = 0
    
    var date:Date?
    
    var srImages:[SRImage] = []
    weak var delegate: SRModelDelegate?
    var scale:CGFloat = 2
    var tileSize:Int = 960
    var padding:Int = 0
    var resizedForTileWidth:CGFloat = .zero
    var resizedForTileHeight:CGFloat = .zero
    var tileCountX:CGFloat = 0
    var tileCountY:CGFloat = 0
    var totalTileCount:Int = 0
    let ciContext = CIContext()
    let imageContext = CIContext()
    
    var srTile:[UIImage?] = []
    var dimmentionalSRTile:[[UIImage?]] = []
    var request: VNCoreMLRequest!
    
    
    override init() {
        super.init()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let model = try! realesrgan960x2(configuration: MLModelConfiguration()).model
            let vnModel = try! VNCoreMLModel(for: model)
            let request = VNCoreMLRequest(model: vnModel, completionHandler: self?.srCompletionHandler)
            request.imageCropAndScaleOption = .scaleFill
            self?.request = request
        }
    }
    
    func addImage(selectedImages:[NSItemProvider], viewWidth:CGFloat) {
        var uiImage:UIImage!
        for itemProvider in selectedImages {
            if itemProvider.canLoadObject(ofClass: UIImage.self) {
                itemProvider.loadObject(ofClass: UIImage.self) { image, error in
                    if let image = image as? UIImage, error == nil {
                        let newImage = self.getCorrectOrientationUIImage(uiImage: image)
                        uiImage = newImage
                        guard let data = uiImage.pngData(),
                              let thumbnailImage = uiImage.thumbnail(width: viewWidth) else { return }
                        
                        let pointSize = uiImage.size
                        print(data.count)
                        let megaByteSize = round(Double(data.count/100000))/10
                        let srImage = SRImage(imageProvider: itemProvider, thumbnailImage: thumbnailImage, pointSize: pointSize, megaByteSize: megaByteSize)
                        self.srImages.append(srImage)
                        self.delegate?.srImagesUpdated()
                    }
                }
            }
        }
    }
    
    func runSR() {
        isProcessing = true
        checkStartProcessingIndex()
        
        switch srMode {
        case .simple:
            simpleSR(srImage: srImages[proccessingIndex])
        case .tile:
            tileSR(srImage: srImages[proccessingIndex])
        }
    }
    
    func checkStartProcessingIndex(){
        for index in srImages.indices {
            if srImages[index].srImageURL == nil {
                proccessingIndex = index
                return
            }
        }
    }
    
    func simpleSR(srImage:SRImage) {
        if date == nil {
            date = Date()
        }
        guard request != nil else {
            Timer.scheduledTimer(withTimeInterval: 1, repeats: false) { [weak self] _ in
                self?.runSR()
            }
            return
        }
        srImage.imageProvider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
            if let image = image as? UIImage,
               error == nil,
               let safeSelf = self {
                let newImage = safeSelf.getCorrectOrientationUIImage(uiImage: image)
                guard let ciImage = CIImage(image: newImage) else {safeSelf.delegate?.gotError();return}
                
                let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
                do {
                    try handler.perform([safeSelf.request])
                } catch {
                    safeSelf.delegate?.gotError()
                }
            }
        }
    }
    
    func srCompletionHandler(request:VNRequest?,error:Error?) {
        guard isProcessing else {return}
        guard let result = request?.results?.first as? VNPixelBufferObservation else { return }
        
        let ciImage = CIImage(cvPixelBuffer: result.pixelBuffer)
        
        
        switch srMode {
        case .simple:
            let resizedCIImage = ciImage.resize(as: srImages[proccessingIndex].pointSize)
            let safeCGImage = ciContext.createCGImage(resizedCIImage, from: resizedCIImage.extent)!
            let uiImage = UIImage(cgImage: safeCGImage)
            let time = Date().timeIntervalSince(date!)
            print(time)
            let url = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent(UUID().uuidString+".png")
            let png = uiImage.pngData()
            try! png?.write(to: url)
            srImages[proccessingIndex].srImageURL = url
            srImages[proccessingIndex].srThumbnailImage = uiImage.thumbnail(width: srImages[proccessingIndex].thumbnailImage.size.width)
            delegate?.endSR(index: proccessingIndex,time: time)
            date = nil
            
            if proccessingIndex < srImages.count - 1 {
                proccessingIndex += 1
                simpleSR(srImage: srImages[proccessingIndex])
            }
            
        case .tile:
            let safeCGImage = ciContext.createCGImage(ciImage, from: ciImage.extent)!
            let uiImage = UIImage(cgImage: safeCGImage)
            srTile.append(uiImage)
            if srTile.count == totalTileCount {
                guard isProcessing else {return}
                assembleTile()
            }
        }
    }
    
    func assembleTile() {
        makeTileDimmentional()
        guard isProcessing else {return}
        let outputImage = assembleTileImages()
        guard isProcessing else {return}

        srImages[proccessingIndex].srThumbnailImage = outputImage!.thumbnail(width: srImages[proccessingIndex].thumbnailImage.size.width)
        saveSRTile(uiImage: outputImage!)
    }
    
    func saveSRTile(uiImage:UIImage) {
        guard isProcessing else {return}
        let time = Date().timeIntervalSince(date!)
        print(time)
        let data = uiImage.pngData()
        let url = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent(UUID().uuidString+".png")
        try! data!.write(to: url)
        srImages[proccessingIndex].srImageURL = url
        srImages[proccessingIndex].srPointSize = uiImage.size
        delegate?.endSR(index: proccessingIndex,time: time)
        date = nil
        if proccessingIndex < srImages.count - 1 {
            guard isProcessing else {return}
            proccessingIndex += 1
            resetPropertiesForNextImage()
            tileSR(srImage: srImages[proccessingIndex])
        } else {
            isProcessing = false
            resetPropertiesForNextImage()
            proccessingIndex = 0
            delegate?.endAllProcess()
        }
    }
    
    func resetPropertiesForNextImage(){
        totalTileCount = 0
        dimmentionalSRTile = []
    }
    
    
    func tileSR(srImage:SRImage) {
        delegate?.startSR(index: proccessingIndex)
        
        if date == nil {
            date = Date()
        }
        guard request != nil else {
            Timer.scheduledTimer(withTimeInterval: 1, repeats: false) { [weak self] _ in
                guard let isProcessing = self?.isProcessing,
                isProcessing else {return}
                self?.runSR()
            }
            return
        }
        guard isProcessing else {return}
        srImage.imageProvider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
            if let image = image as? UIImage,
               error == nil,
               let safeSelf = self {
                let newImage = safeSelf.getCorrectOrientationUIImage(uiImage: image)
                guard safeSelf.isProcessing else {return}
                let resizedForTile = safeSelf.resizeForTile(uiImage: newImage)
                guard safeSelf.isProcessing else {return}
                let tiles = safeSelf.tileImage(uiImage: resizedForTile)
                guard safeSelf.isProcessing else {return}
                for tilesY in tiles {
                    for tile in tilesY {
                        guard safeSelf.isProcessing else {return}
                        let tileCI = CIImage(image: tile)
                        let handler = VNImageRequestHandler(ciImage: tileCI!, options: [:])
                        do {
                            try handler.perform([safeSelf.request])
                        } catch {
                            safeSelf.delegate?.gotError()
                        }
                    }
                }
            }
        }
    }
    
    func makeTileDimmentional() {
        guard isProcessing else {return}
        for Y in 0...Int(tileCountY-1) {
            dimmentionalSRTile.append([])
            for X in 0...Int(tileCountX-1) {
                dimmentionalSRTile[Y].append(srTile[Int(tileCountX)*Y+X])
                srTile[Int(tileCountX)*Y+X] = nil
            }
        }
        srTile = []
    }
    
    func resizeForTile(uiImage:UIImage) -> UIImage {
        tileCountX = ceil(uiImage.size.width/CGFloat(tileSize))
        tileCountY = ceil(uiImage.size.height/CGFloat(tileSize))
        
        let resizedWidth = CGFloat(tileSize) * tileCountX
        let resizedHeight = CGFloat(tileSize) * tileCountY
        let resizedSize = CGSize(width: resizedWidth, height: resizedHeight)
        let ciImage = CIImage(image: uiImage)!
        let resizedCIImage = ciImage.resize(as: resizedSize)
        let safeCGImage = ciContext.createCGImage(resizedCIImage, from: resizedCIImage.extent)
        let resizedUIImage = UIImage(cgImage: safeCGImage!)
        resizedForTileWidth = resizedWidth
        resizedForTileHeight = resizedHeight
        print(resizedWidth)
        print(resizedHeight)

        return resizedUIImage
    }
    
    func tileImage(uiImage:UIImage) -> [[UIImage]] {
        var tileImages:[[UIImage]] = []
        
        let width = uiImage.size.width
        let height = uiImage.size.height
        
        let tilesXCount = Int(ceil(width / CGFloat(tileSize)))
        let tilesYCount = Int(ceil(height / CGFloat(tileSize)))
        
        let ciImage = CIImage(image: uiImage)
        
        
        for tileYNumber in 0...tilesYCount-1 {
            var tileXImages:[UIImage] = []
            for tileXNumber  in 0...tilesXCount-1 {
                let ofsetX = tileXNumber * tileSize
                let ofsetY = tileYNumber * tileSize
                let startXPad = ofsetX - padding
                let startYPad = ofsetY - padding
                let padSize = tileSize + padding * 2
                let tileRect = CGRect(x: startXPad, y: startYPad, width: padSize, height: padSize)
                let inputTile = ciImage!.cropped(to: tileRect)
                let safeCGImage = ciContext.createCGImage(inputTile, from: inputTile.extent)
                let tileUIImage = UIImage(cgImage: safeCGImage!)
                tileXImages.append(tileUIImage)
                totalTileCount += 1
            }
            tileImages.append(tileXImages)
        }
        return tileImages
    }
    
    func assembleTileImages() -> UIImage? {
        let scaledPadding = CGFloat(padding) * scale
        let unpaddingTileSize = dimmentionalSRTile[0][0]!.size.width - scaledPadding * 2
        
        let outputWidth = srImages[proccessingIndex].pointSize.width * scale
        let outputHeight = srImages[proccessingIndex].pointSize.height * scale
        
        guard let cgContext = CGContext(data: nil,
                                        width: Int(resizedForTileWidth * scale),
                                        height: Int(resizedForTileHeight * scale),
                                        bitsPerComponent: 8,
                                        bytesPerRow: 4 * Int(resizedForTileWidth * scale),
                                        space: CGColorSpaceCreateDeviceRGB(),
                                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return nil
        }
        var yIndex:CGFloat = 0
        var xIndex:CGFloat = 0
        for tileImagesY in dimmentionalSRTile.indices {
            
            for tileImage in dimmentionalSRTile[tileImagesY].indices {
                autoreleasepool {
                    let cgImage = dimmentionalSRTile[tileImagesY][tileImage]!.cgImage!
                    let outputStartX = xIndex * unpaddingTileSize
                    let outputStartY = yIndex * unpaddingTileSize
                    cgContext.draw(cgImage, in: CGRect(origin: CGPoint(x: outputStartX, y: outputStartY), size: CGSize(width: unpaddingTileSize, height: unpaddingTileSize)))
                    
                    dimmentionalSRTile[tileImagesY][tileImage] = nil
                    xIndex += 1
                }
                
            }
            xIndex = 0
            yIndex += 1
        }
        guard let image = cgContext.makeImage(),
              let resizedImage = image.resize(size: CGSize(width: outputWidth, height: outputHeight)) else { return nil }
        
        let assembledImage = UIImage(cgImage: resizedImage)
        return assembledImage
    }
    
    func stopProcess(){
        isProcessing = false
        Timer.scheduledTimer(withTimeInterval: 1, repeats: false) { timer in
            self.proccessingIndex = 0
            self.totalTileCount = 0
            self.srTile = []
            self.dimmentionalSRTile = []
            self.delegate?.processingEnded()
        }
    }
    
    func getCorrectOrientationUIImage(uiImage:UIImage) -> UIImage {
        var newImage = UIImage()
        switch uiImage.imageOrientation.rawValue {
        case 1:
            guard let orientedCIImage = CIImage(image: uiImage)?.oriented(CGImagePropertyOrientation.down),
                  let cgImage = ciContext.createCGImage(orientedCIImage, from: orientedCIImage.extent) else { print("Image rotation failed."); return uiImage}
            newImage = UIImage(cgImage: cgImage)
        case 3:
            guard let orientedCIImage = CIImage(image: uiImage)?.oriented(CGImagePropertyOrientation.right),
                  let cgImage = ciContext.createCGImage(orientedCIImage, from: orientedCIImage.extent) else { print("Image rotation failed."); return uiImage}
            newImage = UIImage(cgImage: cgImage)
        default:
            newImage = uiImage
        }
        return newImage
    }
    
    func saveImages(){
        for srImage in srImages {
            autoreleasepool {
                guard let url = srImage.srImageURL else {return}
                let data = try! Data(contentsOf: url)
                let image = UIImage(data: data)
                UIImageWriteToSavedPhotosAlbum(image!, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
            }
        }
    }
    
    @objc func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
         } else {
             delegate?.srImageSaved(index: savingIndex)
             savingIndex += 1
        }
    }
    
    func deleteSRImage(index:Int) {
        srImages.remove(at: index)
        checkStartProcessingIndex()
        delegate?.srImageDeleted()
    }
    
    func removeAllSrImages(){
        srImages.removeAll()
        checkStartProcessingIndex()
        delegate?.srImageDeleted()
    }
    
    func removeALLSrImageURLAndThumbnails() {
        for index in srImages.indices {
            srImages[index].srImageURL = nil
            srImages[index].srThumbnailImage = nil
            srImages[index].srPointSize = nil
        }
        checkStartProcessingIndex()
        delegate?.srImageURLRemoved()
    }
    
    func deleteLocalSRImageFiles(){
        for srImage in srImages {
            if let srURL = srImage.srImageURL {
                do {
                    try FileManager.default.removeItem(at: srURL)
                } catch let error {
                    print(error)
                }
            }
        }
    }
}

