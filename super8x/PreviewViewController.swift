//
//  PreviewViewController.swift
//  super8x
//
//  Created by DaisukeMajima on 2022/02/03.
//

import UIKit

class PreviewViewController: UIViewController, UIScrollViewDelegate{

    var model: PreviewModel!
    var scrollView = UIScrollView()
    var imageView = UIImageView()
    @IBOutlet weak var menuStack: UIStackView!
    
    @IBOutlet weak var headerView: UIView!
    @IBOutlet weak var segmentControl: UISegmentedControl!
    @IBOutlet weak var dismissButton: UIButton!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var shareButton: UIButton!
    @IBOutlet weak var indicator: UIActivityIndicatorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        model.delegate = self
        model.loadImages()
        setupView()
        indicator.isHidden = true
    }
    
    func setupView() {
        view.addSubview(scrollView)
        scrollView.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: view.bounds.height - headerView.frame.height)
        scrollView.addSubview(imageView)
        imageView.frame = scrollView.bounds
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 5.0
        scrollView.delegate = self
        imageView.contentMode = .scaleAspectFit
        imageView.image = model.srUIImage
        view.bringSubviewToFront(segmentControl)
        view.bringSubviewToFront(headerView)
        view.bringSubviewToFront(menuStack)

        segmentControl.addTarget(self, action: #selector(segmentDidChange(_:)), for: .valueChanged)
        dismissButton.setTitle("", for: .normal)
        dismissButton.layer.cornerRadius = dismissButton.bounds.width/2
        shareButton.layer.cornerRadius = shareButton.bounds.height/2
        saveButton.layer.cornerRadius = saveButton.bounds.height/2
        shareButton.addShadow()
        saveButton.addShadow()
    }
    
    @objc func segmentDidChange(_ sender: UISegmentedControl) {
        let index = sender.selectedSegmentIndex
        switch index {
        case 0:
            imageView.image = model.srUIImage
        case 1:
            imageView.image = model.originalUIImage
        default:
            break
        }
    }
    
    @IBAction func saveButtonTapped(_ sender: UIButton) {
        indicator.isHidden = false
        indicator.startAnimating()
        model.saveImage()
    }
    
    @IBAction func shareButtonTapped(_ sender: UIButton) {
        shareImage()
    }
    
    func shareImage() {
        let activityViewController = UIActivityViewController(activityItems: [model.srImage.srImageURL], applicationActivities: nil)
            present(activityViewController,animated: true,completion: nil)
    }
    
    @IBAction func dismissButtonTapped(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }

}

extension PreviewViewController: PreviewModelDelegate {
    func imageSaved() {
        indicator.stopAnimating()
        indicator.isHidden = true
        self.presentAlert("Saved in PhotoLibraty")
    }
}
