// Sana — BarcodeScannerView.swift
import SwiftUI
import AVFoundation

// MARK: - SwiftUI wrapper

struct BarcodeScannerView: UIViewControllerRepresentable {
    let onScan: (String) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> BarcodeScannerController {
        let vc = BarcodeScannerController()
        vc.onScan = onScan
        vc.onCancel = onCancel
        return vc
    }

    func updateUIViewController(_ uiViewController: BarcodeScannerController, context: Context) {}
}

// MARK: - UIKit controller

final class BarcodeScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {

    var onScan: ((String) -> Void)?
    var onCancel: (() -> Void)?

    private var session: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasScanned = false

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupSession()
        addOverlay()
        addCancelButton()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        hasScanned = false
        DispatchQueue.global(qos: .userInitiated).async { self.session?.startRunning() }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        session?.stopRunning()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    // MARK: - Camera setup

    private func setupSession() {
        let s = AVCaptureSession()
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              s.canAddInput(input) else { return }
        s.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard s.canAddOutput(output) else { return }
        s.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.ean8, .ean13, .upce, .code128, .code39, .code93]

        let preview = AVCaptureVideoPreviewLayer(session: s)
        preview.frame = view.bounds
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)
        previewLayer = preview
        session = s
    }

    // MARK: - Overlay UI

    private func addOverlay() {
        let scanRect = CGRect(
            x: 32, y: view.bounds.midY - 90,
            width: view.bounds.width - 64, height: 160
        )

        let dim = UIView(frame: view.bounds)
        dim.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        let mask = CAShapeLayer()
        let path = UIBezierPath(rect: dim.bounds)
        path.append(UIBezierPath(roundedRect: scanRect, cornerRadius: 14))
        mask.path = path.cgPath
        mask.fillRule = .evenOdd
        dim.layer.mask = mask
        view.addSubview(dim)

        let border = UIView(frame: scanRect)
        border.layer.borderColor = UIColor.systemGreen.cgColor
        border.layer.borderWidth = 2.5
        border.layer.cornerRadius = 14
        view.addSubview(border)

        let hint = UILabel()
        hint.text = "Point at a barcode"
        hint.textColor = .white
        hint.font = .systemFont(ofSize: 15, weight: .medium)
        hint.textAlignment = .center
        hint.frame = CGRect(x: 0, y: scanRect.maxY + 20, width: view.bounds.width, height: 28)
        view.addSubview(hint)
    }

    private func addCancelButton() {
        let btn = UIButton(type: .system)
        btn.setTitle("Cancel", for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 17, weight: .regular)
        btn.frame = CGRect(x: 0, y: view.bounds.height - 80, width: view.bounds.width, height: 44)
        btn.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        view.addSubview(btn)
    }

    @objc private func cancelTapped() { onCancel?() }

    // MARK: - Scan delegate

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard !hasScanned,
              let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let code = obj.stringValue else { return }
        hasScanned = true
        session?.stopRunning()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onScan?(code)
    }
}
