//
//  ViewController.swift
//  Example-Mock-iSight-Camera-Simulator
//
//  Created by Zac Stewart on 10/3/18.
//  Copyright © 2018 Zac Stewart. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    let cameraController: CameraController = Platform.isSimulator ? MockCameraController() : RealCameraController()
    
    @IBOutlet weak var previewView: UIView!
    @IBOutlet weak var previewCanvas: UIView!
    @IBOutlet weak var captureView: UIView!
    @IBOutlet weak var captureImage: UIImageView!
    
    @IBAction func discardCapture(_ sender: Any) {
        self.captureImage.image = nil
        self.captureView.isHidden = true
        self.previewView.isHidden = false
    }
    
    @IBAction func snapPhoto(_ sender: Any) {
        self.cameraController.captureImage() { image, error in
            guard let image = image else {
                debugPrint("Couldn't capture image: \(error!)")
                return
            }
            self.captureImage.image = image
            self.captureView.isHidden = false
            self.previewView.isHidden = true
        }
    }
    
    @IBAction func switchCameras(_ sender: Any) {
        do {
            try self.cameraController.switchCameras()
        } catch {
            debugPrint("Failed to switch cameras: \(error)")
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.cameraController.prepare {(error) in
            if let error = error {
                debugPrint("Failed to start CameraController: \(error)")
            }
            
            do {
                try self.cameraController.displayPreview(on: self.previewCanvas)
            } catch {
                debugPrint("Couldn't preview camera: \(error)")
            }
        }
    }

}

