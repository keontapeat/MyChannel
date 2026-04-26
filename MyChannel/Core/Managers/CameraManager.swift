import SwiftUI
import AVFoundation

class CameraManager: NSObject, ObservableObject {
    @Published var focusPoint: CGPoint?

    let captureSession = AVCaptureSession()
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var photoOutput: AVCapturePhotoOutput?
    private var videoOutput: AVCaptureMovieFileOutput?

    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private var photoCaptureCompletion: ((URL?) -> Void)?
    private var videoRecordingCompletion: ((URL?) -> Void)?

    override init() {
        super.init()
        setupCamera()
    }

    private func setupCamera() {
        sessionQueue.async { [weak self] in
            self?.configureSession()
        }
    }

    private func configureSession() {
        captureSession.beginConfiguration()

        if captureSession.canSetSessionPreset(.photo) {
            captureSession.sessionPreset = .photo
        }

        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice) else {
            captureSession.commitConfiguration()
            return
        }

        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
            videoDeviceInput = videoInput
        }

        let photoOutput = AVCapturePhotoOutput()
        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
            self.photoOutput = photoOutput
        }

        let videoOutput = AVCaptureMovieFileOutput()
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
            self.videoOutput = videoOutput
        }

        captureSession.commitConfiguration()
    }

    func startSession() {
        sessionQueue.async { [weak self] in
            if let session = self?.captureSession, !session.isRunning {
                session.startRunning()
            }
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            if let session = self?.captureSession, session.isRunning {
                session.stopRunning()
            }
        }
    }

    func switchCamera(to position: AVCaptureDevice.Position) {
        sessionQueue.async { [weak self] in
            guard let self else { return }

            self.captureSession.beginConfiguration()
            if let currentInput = self.videoDeviceInput {
                self.captureSession.removeInput(currentInput)
            }

            guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
                  let newInput = try? AVCaptureDeviceInput(device: newDevice) else {
                self.captureSession.commitConfiguration()
                return
            }

            if self.captureSession.canAddInput(newInput) {
                self.captureSession.addInput(newInput)
                self.videoDeviceInput = newInput
            }

            self.captureSession.commitConfiguration()
        }
    }

    func setFlashMode(_ flashMode: CreateStoryViewModel.FlashMode) {
        sessionQueue.async { [weak self] in
            guard let device = self?.videoDeviceInput?.device, device.hasFlash else { return }

            do {
                try device.lockForConfiguration()
                switch flashMode {
                case .off:
                    device.flashMode = .off
                case .on:
                    device.flashMode = .on
                case .auto:
                    device.flashMode = .auto
                }
                device.unlockForConfiguration()
            } catch {
                print("Failed to set flash mode: \(error)")
            }
        }
    }

    func focus(at point: CGPoint) {
        DispatchQueue.main.async { [weak self] in
            self?.focusPoint = point
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self?.focusPoint = nil
            }
        }

        sessionQueue.async { [weak self] in
            guard let device = self?.videoDeviceInput?.device,
                  device.isFocusPointOfInterestSupported else { return }

            do {
                try device.lockForConfiguration()
                device.focusPointOfInterest = point
                device.focusMode = .autoFocus
                device.unlockForConfiguration()
            } catch {
                print("Failed to set focus: \(error)")
            }
        }
    }

    func capturePhoto(completion: @escaping (URL?) -> Void) {
        photoCaptureCompletion = completion
        sessionQueue.async { [weak self] in
            guard let self, let photoOutput = self.photoOutput else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
        }
    }

    func startVideoRecording() {
        sessionQueue.async { [weak self] in
            guard let self, let videoOutput = self.videoOutput, !videoOutput.isRecording else { return }
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mp4")
            videoOutput.startRecording(to: tempURL, recordingDelegate: self)
        }
    }

    func stopVideoRecording(completion: @escaping (URL?) -> Void) {
        videoRecordingCompletion = completion
        sessionQueue.async { [weak self] in
            guard let self, let videoOutput = self.videoOutput, videoOutput.isRecording else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            videoOutput.stopRecording()
        }
    }
}

extension CameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil, let data = photo.fileDataRepresentation() else {
            DispatchQueue.main.async { self.photoCaptureCompletion?(nil) }
            return
        }
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jpg")
        do {
            try data.write(to: tempURL)
            DispatchQueue.main.async { self.photoCaptureCompletion?(tempURL) }
        } catch {
            DispatchQueue.main.async { self.photoCaptureCompletion?(nil) }
        }
    }
}

extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if error != nil {
            DispatchQueue.main.async { self.videoRecordingCompletion?(nil) }
        } else {
            DispatchQueue.main.async { self.videoRecordingCompletion?(outputFileURL) }
        }
    }
}
