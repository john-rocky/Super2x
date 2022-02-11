//
//  PreviewModel.swift
//  super8x
//
//  Created by 間嶋大輔 on 2022/02/06.
//

import Foundation
import UIKit

protocol PreviewModelDelegate:NSObjectProtocol {
    func imageSaved()
}

class PreviewModel:NSObject {
    var srImage: SRImage!
    var srUIImage: UIImage!
    var originalUIImage: UIImage!
    var delegate: PreviewModelDelegate?
    
    init(srImage: SRImage){
        self.srImage = srImage
    }
    
    func loadImages() {
        let data = try! Data(contentsOf: srImage.srImageURL!)
        srUIImage = UIImage(data: data)
        let itemProvider = srImage.imageProvider
        if itemProvider.canLoadObject(ofClass: UIImage.self) {
            itemProvider.loadObject(ofClass: UIImage.self) { image, error in
                if let image = image as? UIImage, error == nil {
                    self.originalUIImage = image
                }
            }
        }
    }
    
    func saveImage() {
        UIImageWriteToSavedPhotosAlbum(srUIImage, self, #selector(image), nil)
    }
    
    @objc func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
 
        } else {
            delegate?.imageSaved()
        }
    }
    

}
