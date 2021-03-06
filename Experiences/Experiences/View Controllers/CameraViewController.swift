//
//  CameraViewController.swift
//  Experiences
//
//  Created by Dillon P on 3/22/20.
//  Copyright © 2020 Lambda iOSPT3. All rights reserved.
//

import UIKit
import AVFoundation
import CoreLocation

protocol MapViewReloadDelegate {
    func refreshMap()
}

class CameraViewController: UIViewController {
    
    @IBOutlet weak var cameraView: CameraView!
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var saveButton: UIButton!
    
    
    lazy private var captureSession = AVCaptureSession()
    lazy private var fileOutput = AVCaptureMovieFileOutput()
    lazy private var playerLayer = AVPlayerLayer()
    var camera: AVCaptureDevice?
    var microphone: AVCaptureDevice?
    
    var player: AVPlayer!
    var videoURL: URL? {
        didSet {
            do {
                videoData = try Data(contentsOf: videoURL!)
            } catch {
                print("Error converting video to data: \(error)")
            }
        }
    }
    
    
    //MARK: - Model Controller Properties & Delegate Methods
    
    var experienceController: ExperienceController?
    var delegate: MapViewReloadDelegate?
    
    
    // MARK: - Model Object Properties
    
    var experienceName: String?
    var imageData: Data?
    var audioData: Data?
    var videoData: Data?
    var locationManager = CLLocationManager()
    
    
    //MARK: - View Set-Up
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpCamera()
        
        let noCameraAlert = UIAlertController(title: "No Camera", message: "A camera could not be prepared for this device. Don't worry - you can still create an experience without video.", preferredStyle: .alert)
               noCameraAlert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
               
               let noMicAlert = UIAlertController(title: "No Microphone", message: "A microphone could not be prepared for this device. Don't worry - you can still create an experience without video.", preferredStyle: .alert)
               noMicAlert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        
        if camera == nil {
            self.present(noCameraAlert, animated: true)
            recordButton.isEnabled = false
            recordButton.tintColor = .gray
            return
        }
        
        if microphone == nil {
            self.present(noMicAlert, animated: true)
        }
        cameraView.videoPlayerLayer.videoGravity = .resizeAspectFill
        
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapGesture(_:)))
        view.addGestureRecognizer(tapGesture)
        
        
    }
    
    @objc func handleTapGesture(_ tapGesture: UITapGestureRecognizer) {
        if tapGesture.state == .ended {
            replayRecording()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        captureSession.startRunning()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        captureSession.stopRunning()
    }
    
    private func updateViews() {
        recordButton.isSelected = fileOutput.isRecording
    }
    
    
    // MARK: - Camera & Microphone Set-Up
    
    private func setUpCamera() {
        guard let camera = camera, let microphone = microphone else { return }
        
        captureSession.beginConfiguration()
        
        guard let cameraInput = try? AVCaptureDeviceInput(device: camera) else {
            preconditionFailure("Cannot get camera input")
        }
        
        guard let microphoneInput = try? AVCaptureDeviceInput(device: microphone) else {
            preconditionFailure("Cannot get microphone input")
        }
        
        // Add Video input
        guard captureSession.canAddInput(cameraInput) else {
            preconditionFailure("Unable to add camera input")
        }
        captureSession.addInput(cameraInput)
        
        // Add audio input
        guard captureSession.canAddInput(microphoneInput) else {
            preconditionFailure("Unable to add microphone input")
        }
        captureSession.addInput(microphoneInput)
        
        // Set video present
        if captureSession.canSetSessionPreset(.hd1920x1080) {
            captureSession.sessionPreset = .hd1920x1080
        }
        
        // Check if can output & add output
        guard captureSession.canAddOutput(fileOutput) else {
            preconditionFailure("Cannot write to disk")
        }
        captureSession.addOutput(fileOutput)
        
        captureSession.commitConfiguration()
        cameraView.session = captureSession
    }
    
    private func bestCamera() {
        if let device = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back) {
            camera = device
        }
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            camera = device
        }
    }
    
    private func bestMicrophone() {
        if let device = AVCaptureDevice.default(for: .audio) {
            microphone = device
        }
    }
    
    
    //MARK: - Video Recording Functions
       
       private func toggleRecording() {
           if fileOutput.isRecording {
               fileOutput.stopRecording()
           } else {
               fileOutput.startRecording(to: newRecordingURL(), recordingDelegate: self)
           }
       }
       
       private func newRecordingURL() -> URL {
           let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

           let formatter = ISO8601DateFormatter()
           formatter.formatOptions = [.withInternetDateTime]

           let name = formatter.string(from: Date())
           let fileURL = documentsDirectory.appendingPathComponent(name).appendingPathExtension("mov")
           return fileURL
       }
    
    
    // MARK: - Video Playback Functions
        
        private func replayRecording() {
            if let player = player {
                player.seek(to: CMTime.zero)
                player.play()
            }
        }
        
        private func playMovie(url: URL) {
            player = AVPlayer(url: url)
            
            playerLayer = AVPlayerLayer(player: player)
            
            var playbackView = view.bounds
            playbackView.size.height /= 3.5
            playbackView.size.width /= 3.5
            playbackView.origin.y = view.layoutMargins.top + 90
            playbackView.origin.x = view.layoutMargins.left

            playerLayer.cornerRadius = 8
            playerLayer.masksToBounds = true
            playerLayer.videoGravity = .resizeAspectFill
            
            playerLayer.frame = playbackView
            view.layer.addSublayer(playerLayer)
            
            player.play()
        }

    
    
    // MARK: - Actions
    
    @IBAction func recordButtonTapped(_ sender: Any) {
        toggleRecording()
    }
    
    @IBAction func saveButtonTapped(_ sender: Any) {
        guard let experienceController = experienceController,
            let name = experienceName,
            let currentLocation = locationManager.location else { return }
        
        experienceController.addNewExperience(name: name, imageData: imageData, audioData: audioData, videoData: videoData, location: currentLocation)
        
        navigationController?.popToRootViewController(animated: true)
        self.delegate?.refreshMap()
        
    }
    
    @IBAction func backButtonTapped(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    


}


extension CameraViewController: AVCaptureFileOutputRecordingDelegate {
    
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        updateViews()
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            print("Error saving video to file output: \(error)")
        }
        
        videoURL = outputFileURL
        updateViews()
        playMovie(url: outputFileURL)
    }
    
}
