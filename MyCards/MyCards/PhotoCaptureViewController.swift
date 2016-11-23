//
//  PhotoCaptureViewController.swift
//  MyCards
//
//  Created by Maciej Piotrowski on 22/11/16.
//  Copyright © 2016 Maciej Piotrowski. All rights reserved.
//

import UIKit
import AVFoundation

protocol PhotoCaptureDelegate: class {
    func photoTaken(_ data: Data)
}


extension UIInterfaceOrientation {
    var videoOrientation: AVCaptureVideoOrientation? {
        switch self {
        case .portrait: return .portrait
        case .portraitUpsideDown: return .portraitUpsideDown
        case .landscapeLeft: return .landscapeLeft
        case .landscapeRight: return .landscapeRight
        default: return nil
        }
    }
}


class PhotoCaptureViewController: UIViewController {
    fileprivate enum SessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
    }

    weak var delegate: PhotoCaptureDelegate?
    fileprivate let output = AVCapturePhotoOutput()
    fileprivate let session = AVCaptureSession()
    fileprivate var input: AVCaptureDeviceInput!
    fileprivate let queue = DispatchQueue(label: "AV Session Queue", attributes: [], target: nil)
    fileprivate var setupResult: SessionSetupResult = .success //TODO: refactor

    override var shouldAutorotate: Bool { return false }
    fileprivate var statusBarHidden: Bool = false {
        didSet {
            setNeedsStatusBarAppearanceUpdate()
        }
    }
    override var prefersStatusBarHidden: Bool { return statusBarHidden }
    //swiftlint:disable variable_name
    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation { return .fade }
    //swiftlint:enable variable_name


    fileprivate let previewView = PreviewView()


    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(previewView)

        previewView.session = session
        previewView.captureButton.tapped = { [unowned self] in self.takePhoto()}
        previewView.closeButton.tapped = { [unowned self] in self.dismiss()}

        configureConstraints()
        checkAuthorizationStatus()

        queue.async { self.configureSession() }
    }


    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startSession()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        statusBarHidden = true
    }

    override func viewWillDisappear(_ animated: Bool) {
        stopSession()
        super.viewWillDisappear(animated)
    }

}

extension PhotoCaptureViewController {

    fileprivate func configureConstraints() {

        view.subviews.forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

        var constraints: [NSLayoutConstraint] = NSLayoutConstraint.filledInSuperview(previewView)

        NSLayoutConstraint.activate(constraints)
    }

    func checkAuthorizationStatus() {
        switch AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo) {
        case .denied, .restricted:
            //TODO: alert
            print("disallowed")
            break
        case .notDetermined:
            queue.suspend()
            AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeVideo, completionHandler: { [unowned self] granted in
                self.queue.resume()
            })
        default:
            break
        }
    }

    fileprivate func configureSession() {
        if setupResult != .success {
            return
        }

        session.beginConfiguration()
        session.sessionPreset = AVCaptureSessionPresetPhoto

        // Add video input.
        do {
            var defaultVideoDevice: AVCaptureDevice?

            // Choose the back dual camera if available, otherwise default to a wide angle camera.
            if let dualCameraDevice = AVCaptureDevice.defaultDevice(withDeviceType: .builtInDuoCamera, mediaType: AVMediaTypeVideo, position: .back) {
                defaultVideoDevice = dualCameraDevice
            } else if let backCameraDevice = AVCaptureDevice.defaultDevice(withDeviceType: .builtInWideAngleCamera, mediaType: AVMediaTypeVideo, position: .back) {
                // If the back dual camera is not available, default to the back wide angle camera.
                defaultVideoDevice = backCameraDevice
            } else if let frontCameraDevice = AVCaptureDevice.defaultDevice(withDeviceType: .builtInWideAngleCamera, mediaType: AVMediaTypeVideo, position: .front) {
                // In some cases where users break their phones, the back wide angle camera is not available. In this case, we should default to the front wide angle camera.
                defaultVideoDevice = frontCameraDevice
            }

            let videoDeviceInput = try AVCaptureDeviceInput(device: defaultVideoDevice)

            if session.canAddInput(videoDeviceInput) {
                session.addInput(videoDeviceInput)
                self.input = videoDeviceInput

                DispatchQueue.main.async {
                    /*
                     Why are we dispatching this to the main queue?
                     Because AVCaptureVideoPreviewLayer is the backing layer for PreviewView and UIView
                     can only be manipulated on the main thread.
                     Note: As an exception to the above rule, it is not necessary to serialize video orientation changes
                     on the AVCaptureVideoPreviewLayer’s connection with other session manipulation.

                     Use the status bar orientation as the initial video orientation. Subsequent orientation changes are
                     handled by CameraViewController.viewWillTransition(to:with:).
                     */
                    let statusBarOrientation = UIApplication.shared.statusBarOrientation
                    var initialVideoOrientation: AVCaptureVideoOrientation = .portrait
                    if statusBarOrientation != .unknown {
                        if let videoOrientation = statusBarOrientation.videoOrientation {
                            initialVideoOrientation = videoOrientation
                        }
                    }


                    self.previewView.videoPreviewLayer.connection.videoOrientation = initialVideoOrientation
                }
            } else {
                print("Could not add video device input to the session")
                setupResult = .configurationFailed
                session.commitConfiguration()
                return
            }
        } catch {
            print("Could not create video device input: \(error)")
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }



        // Add photo output.
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.isHighResolutionCaptureEnabled = true
            output.isLivePhotoCaptureEnabled = false
        } else {
            print("Could not add photo output to the session")
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }

        session.commitConfiguration()
    }

    func takePhoto() {

        let videoPreviewLayerOrientation = previewView.videoPreviewLayer.connection.videoOrientation

        queue.async {
            // Update the photo output's connection to match the video orientation of the video preview layer.
            if let photoOutputConnection = self.output.connection(withMediaType: AVMediaTypeVideo) {
                photoOutputConnection.videoOrientation = videoPreviewLayerOrientation
            }

            // Capture a JPEG photo with flash set to auto and high resolution photo enabled.
            let photoSettings = AVCapturePhotoSettings()
            photoSettings.flashMode = .auto
            photoSettings.isHighResolutionPhotoEnabled = true


            self.output.capturePhoto(with: photoSettings, delegate: self)
        }
    }

    func dismiss() {
        dismiss(animated: true, completion: nil)
    }

    func startSession() {
        queue.async {
            switch self.setupResult {
            case .success:
                // Only setup observers and start the session running if setup succeeded.
                //                self.addObservers()
                self.session.startRunning()
                //                self.isSessionRunning = self.session.isRunning

            default: break
            }}
    }

    func stopSession() {
        queue.async { [unowned self] in
            if self.setupResult == .success {
                self.session.stopRunning()
                //                self.isSessionRunning = self.session.isRunning
                //                self.removeObservers()
            }
        }

    }

}
extension PhotoCaptureViewController: AVCapturePhotoCaptureDelegate {

    func capture(_ captureOutput: AVCapturePhotoOutput, didFinishProcessingPhotoSampleBuffer photoSampleBuffer: CMSampleBuffer?, previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {
        if let photoSampleBuffer = photoSampleBuffer {
            let photoData = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: photoSampleBuffer, previewPhotoSampleBuffer: previewPhotoSampleBuffer)
            //TODO: delegate
            delegate?.photoTaken(photoData!)
        } else {
            print("Error capturing photo: \(error)")
            return
        }
    }
}