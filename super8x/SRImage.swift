//
//  SRImage.swift
//  super8x
//
//  Created by 間嶋大輔 on 2022/01/30.
//

import Foundation
import UIKit

struct SRImage {
    let imageProvider: NSItemProvider
    let thumbnailImage: UIImage
    let pointSize: CGSize
    let megaByteSize: Double
    var srImageURL: URL?
    var srThumbnailImage: UIImage?
    var srPointSize: CGSize?
}
