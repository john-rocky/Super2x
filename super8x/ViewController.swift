//
//  ViewController.swift
//  super8x
//
//  Created by 間嶋大輔 on 2022/01/29.
//

import UIKit
import PhotosUI

class ViewController: UIViewController {
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var addButton: UIButton!
    @IBOutlet weak var runButton: UIButton!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var shareButton: UIButton!
    @IBOutlet weak var resetButton: UIButton!
    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var addLabel: UILabel!
    @IBOutlet weak var nextLabel: UILabel!
    @IBOutlet weak var saveLabel: UILabel!
    @IBOutlet weak var shareLabel: UILabel!
    @IBOutlet weak var resetLabel: UILabel!
    @IBOutlet weak var backLabel: UILabel!
    @IBOutlet weak var backStackView: UIStackView!
    @IBOutlet weak var resetStackView: UIStackView!
    @IBOutlet weak var shareStackView: UIStackView!
    @IBOutlet weak var saveStackView: UIStackView!
    @IBOutlet weak var runStackView: UIStackView!
    @IBOutlet weak var addStackView: UIStackView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var stopStackView: UIStackView!
    @IBOutlet weak var stopButton: UIButton!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    
    enum ViewMode {
        case noImage
        case imageAdded
        case processing
        case processed
    }
    
    var viewMode:ViewMode = .noImage
    
    var viewWidth: CGFloat!
    
    var model = SRModel()
    
    var selectedIndexPath:IndexPath?
    
    let haptics = Haptics()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        viewWidth = view.bounds.width - 4
        model.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(removeFiles), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }
    
    @objc func removeFiles() {
        collectionView.performBatchUpdates {
//            var indexPaths:[IndexPath] = []
//            for index in model.srImages.indices {
//                indexPaths.append(IndexPath(item: index, section: 0))
//            }
//            collectionView.deleteItems(at: indexPaths)
            collectionView.reloadData()
            model.removeALLSrImageURLAndThumbnails()
                
        } completion: { _ in
            
        }
        updateMenu()

    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        activityIndicator.stopAnimating()
        activityIndicator.isHidden = true
        updateMenu()
    }
    
    @IBAction func addButtonTapped(_ sender: UIButton) {
        haptics.playHapticsFile("Tap")
        add()
    }
    
    @IBAction func runButtonTapped(_ sender: UIButton) {
        haptics.playHapticsFile("Tap")
        next()
    }
    
    @IBAction func saveButtonTapped(_ sender: UIButton) {
        haptics.playHapticsFile("Tap")
        save()
    }
    
    
    @IBAction func shareButtonTapped(_ sender: UIButton) {
        haptics.playHapticsFile("Tap")
        share()
    }
    
    
    @IBAction func resetButtonTapped(_ sender: UIButton) {
        haptics.playHapticsFile("Tap")
        reset()
    }
    
    @IBAction func backButtonTapped(_ sender: UIButton) {
        back()
    }
    
    @IBAction func stopButtonTapped(_ sender: UIButton) {
        haptics.playHapticsFile("Tap")
        model.stopProcess()
    }
    
    @objc func add(){
        presentPhPicker()
    }
    
    @objc func next(){
        model.runSR()
    }
    
    @objc func save(){
        model.saveImages()
    }
    
    @objc func share(){
        var shareImages:[URL] = []
        for srImage in model.srImages {
            shareImages.append(srImage.srImageURL!)
        }
        let activityViewController = UIActivityViewController(activityItems: shareImages, applicationActivities: nil)
        DispatchQueue.main.async {
            self.present(activityViewController,animated: true,completion: nil)
        }
    }
    
    @objc func reset(){
        collectionView.performBatchUpdates { 
            var indexPaths:[IndexPath] = []
            for index in model.srImages.indices {
                let index = IndexPath(item: index, section: 0)
                indexPaths.append(index)
            }
            model.removeAllSrImages()
            collectionView.deleteItems(at: indexPaths)
        } completion: { _ in
        }
    }
    
    @objc func back(){
        collectionView.performBatchUpdates {
            model.removeALLSrImageURLAndThumbnails()
        }
    }
    
    func deleteCell(indexPath:IndexPath) {
        collectionView.performBatchUpdates {
            model.deleteSRImage(index: indexPath.row)
            collectionView.deleteItems(at: [indexPath])
        } completion: { _ in
            
        }

    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if let previewVC = segue.destination as? PreviewViewController,
           let index = sender as? Int {
            previewVC.model = PreviewModel(srImage: model.srImages[index])
        }
    }
}

extension ViewController: SRModelDelegate {
    func startSR(index: Int) {
        DispatchQueue.main.async { [weak self] in
            let cell = self?.collectionView.cellForItem(at: IndexPath(row: index, section: 0))
            let indicator = cell!.contentView.viewWithTag(9) as! UIActivityIndicatorView
            indicator.isHidden = false
            indicator.startAnimating()
            let completeLabel = cell!.contentView.viewWithTag(6) as! UILabel
            completeLabel.isHidden = false
            completeLabel.text = "Processing"
            self?.updateMenu()
        }
    }
    
    func endSR(index: Int, time: Double) {
        DispatchQueue.main.async { [weak self] in
            self?.collectionView.scrollToItem(at: IndexPath(item: index, section: 0), at: .top, animated: true)
            let cell = self?.collectionView.cellForItem(at: IndexPath(row: index, section: 0))
            let completeLabel = cell!.contentView.viewWithTag(6) as! UILabel
            let completeImageView = cell!.contentView.viewWithTag(7) as! UIImageView
            let indicator = cell!.contentView.viewWithTag(9) as! UIActivityIndicatorView
            indicator.isHidden = true
            indicator.stopAnimating()
            completeImageView.isHidden = false
            completeImageView.image = UIImage(systemName: "checkmark.circle")
            completeLabel.text = "\(floor(time*10)/10)s"
            let imageView = cell!.contentView.viewWithTag(1) as! UIImageView
            imageView.image = self?.model.srImages[index].srThumbnailImage
            imageView.isHidden = false
            
            let pointSizeLabel = cell!.contentView.viewWithTag(3) as! UILabel
            guard let width = self?.model.srImages[index].pointSize.width,
                  let height = self?.model.srImages[index].pointSize.height,
                  let srWidth = self?.model.srImages[index].srPointSize!.width,
                  let srHeight = self?.model.srImages[index].srPointSize!.height else {return}
            
            pointSizeLabel.text = "\(Int(width))x\(Int(height)) -> \(Int(srWidth))x\(Int(srHeight))"
        }
        updateMenu()
    }

    func processingEnded() {
        DispatchQueue.main.async { [weak self] in
            guard let safeSelf = self else {return}
            for index in safeSelf.model.srImages.indices {
                if let cell = safeSelf.collectionView.cellForItem(at: IndexPath(item: index, section: 0)),
                   let imageView = cell.contentView.viewWithTag(1) as? UIImageView,
                   let completeLabel = cell.contentView.viewWithTag(6) as? UILabel,
                   let completeImageView = cell.contentView.viewWithTag(7) as? UIImageView,
                   let pointSizeLabel = cell.contentView.viewWithTag(3) as? UILabel,
                   let indicator = cell.contentView.viewWithTag(9) as? UIActivityIndicatorView
                {
                    if safeSelf.model.srImages[index].srImageURL == nil {
                        imageView.image = safeSelf.model.srImages[index].thumbnailImage
                        completeLabel.text = " "
                        completeImageView.isHidden = true
                        let width = safeSelf.model.srImages[index].pointSize.width
                        let height = safeSelf.model.srImages[index].pointSize.height
                        pointSizeLabel.text = "\(Int(width))x\(Int(height))"
                    }
                    indicator.stopAnimating()
                    indicator.isHidden = true
                }
            }
        }
        updateMenu()
    }
    
    func endAllProcess() {
        updateMenu()
    }
    
    func srImagesUpdated() {
        updateMenu()
        DispatchQueue.main.async { [weak self] in
            self?.activityIndicator.isHidden = true
            self?.activityIndicator.stopAnimating()
            guard let itemCount = self?.model.srImages.count  else { return }
            let lastIndexPath = IndexPath(item: itemCount - 1, section: 0)
            self?.collectionView.performBatchUpdates({
                self?.collectionView.insertItems(at: [lastIndexPath])
                self?.collectionView.reloadItems(at: [lastIndexPath])
            }, completion: nil)
        }
    }
    
    func srImageDeleted() {
        updateMenu()
    }
    
    func srImageURLRemoved() {
        DispatchQueue.main.async { [weak self] in
            guard let safeSelf = self else {return}
            for index in safeSelf.model.srImages.indices {
                if let cell = safeSelf.collectionView.cellForItem(at: IndexPath(item: index, section: 0)),
                   let imageView = cell.contentView.viewWithTag(1) as? UIImageView,
                   let completeLabel = cell.contentView.viewWithTag(6) as? UILabel,
                   let completeImageView = cell.contentView.viewWithTag(7) as? UIImageView,
                   let pointSizeLabel = cell.contentView.viewWithTag(3) as? UILabel
                {
                    imageView.image = safeSelf.model.srImages[index].thumbnailImage
                    completeLabel.text = " "
                    completeImageView.isHidden = true
                    let width = safeSelf.model.srImages[index].pointSize.width
                    let height = safeSelf.model.srImages[index].pointSize.height
                    pointSizeLabel.text = "\(Int(width))x\(Int(height))"
                }
            }
            safeSelf.updateMenu()
        }
    }
    
    func gotError() {
        presentAlert("Error")
        DispatchQueue.main.async { [weak self] in
            guard let safeSelf = self else {return}
            safeSelf.updateMenu()
        }
    }
    
    func srImageSavingStart(index: Int) {
        DispatchQueue.main.async { [weak self] in
            let cell = self?.collectionView.cellForItem(at: IndexPath(row: index, section: 0))
            let completeLabel = cell!.contentView.viewWithTag(6) as! UILabel
            let completeImageView = cell!.contentView.viewWithTag(7) as! UIImageView
            let activityIndicator = cell!.contentView.viewWithTag(9) as! UIActivityIndicatorView
            activityIndicator.isHidden = false
            activityIndicator.startAnimating()
            completeImageView.isHidden = true
            completeLabel.text = "Saving..."
        }
        
    }
    
    func srImageSaved(index: Int) {
        DispatchQueue.main.async { [weak self] in
            let cell = self?.collectionView.cellForItem(at: IndexPath(row: index, section: 0))
            let completeLabel = cell!.contentView.viewWithTag(6) as! UILabel
            let completeImageView = cell!.contentView.viewWithTag(7) as! UIImageView
            completeImageView.isHidden = false
            completeLabel.text = "Saved"
        }
    }
}

extension ViewController: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout,  PHPickerViewControllerDelegate {
    
    func updateMenu(){
        
        if model.isProcessing {
            viewMode = .processing
        } else if model.srImages.isEmpty {
            viewMode = .noImage
        } else if model.srImages[0].srImageURL == nil {
            viewMode = .imageAdded
        } else {
            viewMode = .processed
        }
        DispatchQueue.main.async { [weak self] in
            guard let safeSelf = self else {return}
            switch safeSelf.viewMode {
            case .noImage:
                safeSelf.addStackView.isHidden = false
                safeSelf.runStackView.isHidden = true
                safeSelf.stopStackView.isHidden = true
                safeSelf.saveStackView.isHidden = true
                safeSelf.shareStackView.isHidden = true
                safeSelf.backStackView.isHidden = true
                safeSelf.resetStackView.isHidden = true
            case .imageAdded:
                safeSelf.addStackView.isHidden = false
                safeSelf.runStackView.isHidden = false
                safeSelf.stopStackView.isHidden = true
                safeSelf.saveStackView.isHidden = true
                safeSelf.shareStackView.isHidden = true
                safeSelf.backStackView.isHidden = true
                safeSelf.resetStackView.isHidden = true
            case .processing:
                safeSelf.addStackView.isHidden = true
                safeSelf.runStackView.isHidden = true
                safeSelf.stopStackView.isHidden = false
                safeSelf.saveStackView.isHidden = true
                safeSelf.shareStackView.isHidden = true
                safeSelf.backStackView.isHidden = true
                safeSelf.resetStackView.isHidden = true
            case .processed:
                safeSelf.addStackView.isHidden = true
                safeSelf.runStackView.isHidden = true
                safeSelf.stopStackView.isHidden = true
                safeSelf.saveStackView.isHidden = false
                safeSelf.shareStackView.isHidden = false
                safeSelf.backStackView.isHidden = false
                safeSelf.resetStackView.isHidden = false
            }

        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard model.srImages[indexPath.row].srImageURL != nil else { return }
        performSegue(withIdentifier: "showPreview", sender: indexPath.row)
    }
    
    func setupView() {
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.alwaysBounceVertical = true
        let layout = UICollectionViewFlowLayout()
        layout.sectionInset = UIEdgeInsets(top: 10, left: 8, bottom: 10, right: 8)
        collectionView.collectionViewLayout = layout
        stopButton.setTitle("", for: .normal)
        
        addButton.layer.cornerRadius = addButton.bounds.height/2
        runButton.layer.cornerRadius = runButton.bounds.height/2
        backButton.layer.cornerRadius = backButton.bounds.height/2
        resetButton.layer.cornerRadius = resetButton.bounds.height/2
        shareButton.layer.cornerRadius = shareButton.bounds.height/2
        saveButton.layer.cornerRadius = saveButton.bounds.height/2
        stopButton.layer.cornerRadius = saveButton.bounds.height/2

        addButton.addShadow()
        runButton.addShadow()
        backButton.addShadow()
        resetButton.addShadow()
        shareButton.addShadow()
        saveButton.addShadow()
        stopButton.addShadow()
    }
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return model.srImages.count
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath)
        cell.layer.shadowColor = UIColor.black.cgColor
        cell.layer.shadowOffset = CGSize(width: 2.0, height: 2.0)
        cell.layer.shadowRadius = 2.0
        cell.layer.shadowOpacity = 0.75
        cell.layer.masksToBounds = false
        cell.layer.shadowPath = UIBezierPath(roundedRect:cell.bounds, cornerRadius:cell.contentView.layer.cornerRadius).cgPath
        
        let imageView = cell.contentView.viewWithTag(1) as! UIImageView
        imageView.image = model.srImages[indexPath.row].thumbnailImage
        let numberLabel = cell.contentView.viewWithTag(2) as! UILabel
        numberLabel.text = "\(indexPath.row+1)"
        numberLabel.layer.cornerRadius = numberLabel.bounds.width/2
        let pointSizeLabel = cell.contentView.viewWithTag(3) as! UILabel
        pointSizeLabel.text = "\(Int(model.srImages[indexPath.row].pointSize.width))x\(Int(model.srImages[indexPath.row].pointSize.height))"
        let megaByteSizeLabel = cell.contentView.viewWithTag(4) as! UILabel
        megaByteSizeLabel.text = "\(model.srImages[indexPath.row].megaByteSize)MB"
        let indicator = cell.contentView.viewWithTag(9) as! UIActivityIndicatorView
        indicator.stopAnimating()
        indicator.isHidden = true
        let completeLabel = cell.contentView.viewWithTag(6) as! UILabel
        let completeImageView = cell.contentView.viewWithTag(7) as! UIImageView
        completeLabel.text = " "
        completeImageView.isHidden = true
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let horizontalSpace:CGFloat = 16
        let cellSize:CGFloat = collectionView.bounds.width - horizontalSpace
        return CGSize(width: cellSize, height: cellSize)
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        contextMenuConfigurationForItemAt indexPath: IndexPath,
                        point: CGPoint) -> UIContextMenuConfiguration? {
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { suggestedActions in
            let deleteAction = self.deleteAction(indexPath)
            return UIMenu(title: "", children: [deleteAction])
        }
    }
    
    func deleteAction(_ indexPath: IndexPath) -> UIAction {
        return UIAction(title: NSLocalizedString("Delete", comment: ""),
                        image: UIImage(systemName: "trash"),
                        attributes: .destructive) { action in
            self.deleteCell(indexPath:indexPath)
            self.upDateCellNumber()
        }
    }
    
    func upDateCellNumber(){
        for cell in collectionView.visibleCells {
            let numberLabel = cell.contentView.viewWithTag(2) as! UILabel
            numberLabel.text = "\(collectionView.indexPath(for: cell)!.item+1)"
        }
    }
    
    func presentPhPicker(){
        var configuration = PHPickerConfiguration()
        configuration.selectionLimit = 0
        configuration.filter = .images
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }
    
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        haptics.playHapticsFile("Tap")
        titleLabel.isHidden = true
        descriptionLabel.isHidden = true
        picker.dismiss(animated: true)
        guard !results.isEmpty else { return }
        activityIndicator.isHidden = false
        activityIndicator.startAnimating()
        var selectedImages:[NSItemProvider] = []
        for result in results {
            selectedImages.append(result.itemProvider)
        }
        model.addImage(selectedImages: selectedImages, viewWidth: viewWidth)
    }
}

