//
//  CameraController.swift
//  In The Park
//
//  Created by Zac Stewart on 9/16/18.
//  Copyright © 2018 Zac Stewart. All rights reserved.
//

import AVFoundation
import UIKit

protocol CameraController {
    
    func prepare(completionHandler: @escaping (Error?) -> Void)
    
    func captureImage(completion: @escaping (UIImage?, Error?) -> Void)
    
    func displayPreview(on view: UIView) throws
    
    func switchCameras() throws

}

enum CameraControllerError: Swift.Error {

    case captureSessionAlreadyRunning
    case captureSessionIsMissing
    case inputsAreInvalid
    case invalidOperation
    case noCamerasAvailable
    case unknown

}

public enum CameraPosition {

    case front
    case rear

}

class RealCameraController: NSObject, CameraController {

    var captureSession: AVCaptureSession?
    var currentCameraPosition: CameraPosition?
    var frontCamera: AVCaptureDevice?
    var frontCameraInput: AVCaptureDeviceInput?
    var rearCamera: AVCaptureDevice?
    var rearCameraInput: AVCaptureDeviceInput?
    var photoOutput: AVCapturePhotoOutput?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var photoCaptureCompletionBlock: ((UIImage?, Error?) -> Void)?

    func prepare(completionHandler: @escaping (Error?) -> Void) {
        func createCaptureSession() {
            self.captureSession = AVCaptureSession()
        }

        func configureCaptureDevices() throws {
            let session = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInWideAngleCamera],
                mediaType: AVMediaType.video,
                position: .unspecified)
            let cameras = (session.devices.compactMap { $0 })

            if (cameras.isEmpty) {
                throw CameraControllerError.noCamerasAvailable
            }

            for camera in cameras {
                if camera.position == .front {
                    self.frontCamera = camera
                } else if (camera.position == .back) {
                    self.rearCamera = camera

                    try camera.lockForConfiguration()
                    camera.focusMode = .continuousAutoFocus
                    camera.unlockForConfiguration()
                }
            }
        }

        func configureDeviceInputs() throws {
            guard let captureSession = self.captureSession else {
                throw CameraControllerError.captureSessionIsMissing
            }

            if let frontCamera = self.frontCamera {
                self.frontCameraInput = try AVCaptureDeviceInput(device: frontCamera)
                if captureSession.canAddInput(self.frontCameraInput!) {
                    captureSession.addInput(self.frontCameraInput!)
                } else {
                    throw CameraControllerError.inputsAreInvalid
                }
                self.currentCameraPosition = .front

            } else if let rearCamera = self.rearCamera {
                self.rearCameraInput = try AVCaptureDeviceInput(device: rearCamera)
                if captureSession.canAddInput(self.rearCameraInput!) {
                    captureSession.addInput(self.rearCameraInput!)
                } else {
                    throw CameraControllerError.inputsAreInvalid
                }
                self.currentCameraPosition = .rear

            } else {
                throw CameraControllerError.noCamerasAvailable
            }
        }

        func configurePhotoOutput() throws {
            guard let captureSession = self.captureSession else {
                throw CameraControllerError.captureSessionIsMissing
            }
            self.photoOutput = AVCapturePhotoOutput()
            self.photoOutput!.setPreparedPhotoSettingsArray([
                AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
                ], completionHandler: nil)

            if captureSession.canAddOutput(self.photoOutput!) {
                captureSession.addOutput(self.photoOutput!)
            }
        }

        func startCaptureSession() throws {
            guard let captureSession = self.captureSession else {
                throw CameraControllerError.captureSessionIsMissing
            }
            captureSession.startRunning()
        }

        DispatchQueue(label: "prepare").async {
            do {
                createCaptureSession()
                try configureCaptureDevices()
                try configureDeviceInputs()
                try configurePhotoOutput()
                try startCaptureSession()
            } catch {
                DispatchQueue.main.async {
                    completionHandler(error)
                }

                return
            }

            DispatchQueue.main.async {
                completionHandler(nil)
            }
        }
    }

    func captureImage(completion: @escaping (UIImage?, Error?) -> Void) {
        guard let captureSession = self.captureSession,
            captureSession.isRunning else {
                completion(nil, CameraControllerError.captureSessionIsMissing)
                return
        }

        let settings = AVCapturePhotoSettings()

        self.photoCaptureCompletionBlock = completion
        self.photoOutput?.capturePhoto(with: settings, delegate: self)
    }

    func displayPreview(on view: UIView) throws {
        guard let captureSession = self.captureSession else {
            throw CameraControllerError.captureSessionIsMissing
        }

        self.previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        self.previewLayer?.videoGravity = .resizeAspectFill
        self.previewLayer?.connection?.videoOrientation = .portrait

        view.layer.insertSublayer(self.previewLayer!, at: 0)
        self.previewLayer?.frame = view.frame
    }

    func switchCameras() throws {
        guard let currentCameraPosition = currentCameraPosition,
            let captureSession = self.captureSession,
            captureSession.isRunning else {
                throw CameraControllerError.captureSessionIsMissing
        }

        captureSession.beginConfiguration()

        func switchToFrontCamera() throws {
            let inputs = captureSession.inputs as [AVCaptureInput]
            guard let rearCameraInput = self.rearCameraInput,
                inputs.contains(rearCameraInput),
                let frontCamera = self.frontCamera else {
                    throw CameraControllerError.invalidOperation
            }

            self.frontCameraInput = try AVCaptureDeviceInput(device: frontCamera)
            captureSession.removeInput(rearCameraInput)
            if captureSession.canAddInput(self.frontCameraInput!) {
                captureSession.addInput(self.frontCameraInput!)
            }
            self.currentCameraPosition = .front
        }

        func switchToRearCamera() throws {
            let inputs = captureSession.inputs as [AVCaptureInput]
            guard let frontCameraInput = self.frontCameraInput,
                inputs.contains(frontCameraInput),
                let rearCamera = self.rearCamera else {
                    throw CameraControllerError.invalidOperation
            }

            self.rearCameraInput = try AVCaptureDeviceInput(device: rearCamera)
            captureSession.removeInput(frontCameraInput)
            if captureSession.canAddInput(rearCameraInput!) {
                captureSession.addInput(rearCameraInput!)
            }
            self.currentCameraPosition = .rear
        }

        switch currentCameraPosition {
        case .front:
            try switchToRearCamera()
        case .rear:
            try switchToFrontCamera()
        }

        captureSession.commitConfiguration()
    }

}

extension RealCameraController: AVCapturePhotoCaptureDelegate {

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error{
            self.photoCaptureCompletionBlock?(nil, error)
        } else if let data = photo.fileDataRepresentation(),
            let image = UIImage(data: data) {
            self.photoCaptureCompletionBlock?(image, nil)
        } else {
            self.photoCaptureCompletionBlock?(nil, CameraControllerError.unknown)
        }
    }

}

class MockCameraController: NSObject, CameraController {

    var frontImage = UIImage(named: "Front Camera")!
    var rearImage = UIImage(named: "Rear Camera")!
    var cameraPosition = CameraPosition.rear
    var previewLayer = CALayer()

    func prepare(completionHandler: @escaping (Error?) -> Void) {
        setPreviewFrame(image: self.rearImage)
        completionHandler(nil)
    }

    func captureImage(completion: @escaping (UIImage?, Error?) -> Void) {
        if self.cameraPosition == CameraPosition.rear {
            completion(self.rearImage, nil)
        } else {
            completion(self.frontImage, nil)
        }
    }

    func displayPreview(on view: UIView) throws {
        self.previewLayer.frame = view.bounds
        view.layer.insertSublayer(self.previewLayer, at: 0)
    }

    func switchCameras() throws {
        if self.cameraPosition == CameraPosition.rear {
            self.cameraPosition = CameraPosition.front
            setPreviewFrame(image: self.frontImage)
        } else {
            self.cameraPosition = CameraPosition.rear
            setPreviewFrame(image: self.rearImage)
        }
    }

    private func setPreviewFrame(image: UIImage) {
        self.previewLayer.contents = image.cgImage!
    }

}
