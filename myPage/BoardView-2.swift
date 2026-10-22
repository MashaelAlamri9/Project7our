import SwiftUI
import UIKit
import AVFoundation
import CoreImage.CIFilterBuiltins

// MARK: - Theme

extension Color {
    static let seaTeal   = Color(red: 0.36, green: 0.52, blue: 0.51)
    static let deepBrown = Color(red: 0.29, green: 0.17, blue: 0.06)
    static let parchment = Color(red: 0.91, green: 0.87, blue: 0.71)
    static let sand      = Color(red: 0.83, green: 0.77, blue: 0.60)
    static let gold      = Color(red: 0.83, green: 0.68, blue: 0.29)
    static let mist      = Color(red: 0.80, green: 0.85, blue: 0.82)
    static let inkBrown  = Color(red: 0.55, green: 0.43, blue: 0.18)
}

protocol Scaled {
    var s: CGFloat { get }
}
extension Scaled {
    /// Scaled length (padding, frames, corner radius)
    func u(_ v: CGFloat) -> CGFloat { v * s }
    /// Scaled font size (slightly boosted for readability)
    func f(_ v: CGFloat) -> CGFloat { v * s * 1.2 }
}

// MARK: - Models

struct Achievement: Identifiable, Codable {
    var id = UUID()
    let name: String
    let text: String
    let points: Int
}

struct FriendNote: Identifiable, Codable {
    var id = UUID()
    let text: String
}

struct PlayerProfile: Codable {
    let id: String
    let name: String
    let achievements: [Achievement]
    let notes: [FriendNote]
}

/// Tiny version of the profile so the QR code stays simple and easy to scan
private struct CompactProfile: Codable {
    let n: String        // name
    let a: [[String]]    // achievements: [name, text, points]
    let t: [String]      // notes
}

extension PlayerProfile {
    /// Must match the URL scheme you add in Xcode (Info > URL Types)
    static let scheme = "pirateboard"

    /// What goes inside the QR code: a link the iPhone Camera app can open in your app
    var shareLink: String? {
        let compact = CompactProfile(
            n: name,
            a: achievements.map { [$0.name, $0.text, String($0.points)] },
            t: notes.map { $0.text }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = .withoutEscapingSlashes
        guard let data = try? encoder.encode(compact) else { return nil }
        let b64 = data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return "\(Self.scheme)://connect?d=\(b64)"
    }

    /// Reads either a pirateboard:// link or raw JSON
    static func from(_ string: String) -> PlayerProfile? {
        if let url = URL(string: string),
           url.scheme == scheme,
           let d = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "d" })?.value {
            var b64 = d
                .replacingOccurrences(of: "-", with: "+")
                .replacingOccurrences(of: "_", with: "/")
            while b64.count % 4 != 0 { b64 += "=" }
            guard let data = Data(base64Encoded: b64),
                  let c = try? JSONDecoder().decode(CompactProfile.self, from: data)
            else { return nil }
            let achievements: [Achievement] = c.a.compactMap { row in
                guard row.count == 3 else { return nil }
                return Achievement(name: row[0], text: row[1], points: Int(row[2]) ?? 0)
            }
            return PlayerProfile(
                id: UUID().uuidString,
                name: c.n,
                achievements: achievements,
                notes: c.t.map { FriendNote(text: $0) }
            )
        }
        guard let data = string.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(PlayerProfile.self, from: data)
    }
}

// MARK: - Entry point

struct BoardView: View {
    var body: some View {
        GeometryReader { geo in
            BoardScreen(s: geo.size.width / 777)
                .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

// MARK: - Main Screen

struct BoardScreen: View, Scaled {
    let s: CGFloat
    @Environment(\.dismiss) private var dismiss

    // My own data (this is what my QR code shares)
    @State private var me = PlayerProfile(
        id: "player-\(UUID().uuidString.prefix(8))",
        name: "Me",   // replace with the real player name
        achievements: [
            Achievement(name: "Noor", text: "Ask a nurse their favorite color", points: 5),
            Achievement(name: "Sami", text: "Say good morning to someone new", points: 5),
            Achievement(name: "Layla", text: "Draw something for your friend", points: 5)
        ],
        notes: [
            FriendNote(text: "Hope today goes easy on you!"),
            FriendNote(text: "Your drawing made me smile."),
            FriendNote(text: "Thinking of you today.")
        ]
    )

    // Friend's data: nil until we scan their code
    @State private var friend: PlayerProfile?
    @State private var selectedNote: UUID?
    @State private var showQRSheet = false
    @State private var message: String?

    private var myCode: String {
        me.shareLink ?? me.id
    }

    private func handleScanned(_ text: String) {
        showQRSheet = false
        if let profile = PlayerProfile.from(text) {
            friend = profile
            selectedNote = profile.notes.first?.id
            message = "Connected with \(profile.name)"
        } else {
            message = "That's not a valid friend code."
        }
    }

    var body: some View {
        ZStack {
            Color.seaTeal.ignoresSafeArea()

            VStack(spacing: u(20)) {
                topBar
                title

                if let friend {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: u(24)) {
                            achievementsCard(friend)
                            notesHeader(friend)
                            notesList(friend)
                        }
                        .padding(.bottom, u(10))
                    }
                } else {
                    lockedView
                }

                qrButton   // always pinned at the bottom, no scrolling needed
            }
            .padding(.horizontal, u(32))
            .padding(.bottom, u(16))
        }
        .sheet(isPresented: $showQRSheet) {
            QRConnectSheet(myCode: myCode) { scanned in
                handleScanned(scanned)
            }
        }
        // Opens when the iPhone Camera app scans a friend's code
        .onOpenURL { url in
            handleScanned(url.absoluteString)
        }
        .alert(message ?? "", isPresented: Binding(
            get: { message != nil },
            set: { if !$0 { message = nil } }
        )) { Button("OK", role: .cancel) {} }
    }

    // MARK: Pieces

    private var topBar: some View {
        HStack(spacing: u(20)) {
            CoinButton(s: s, systemName: "house") { /* go home */ }
            CoinButton(s: s, systemName: "chevron.left") { dismiss() }
            Spacer()
        }
    }

    private var title: some View {
        Text("The Board")
            .font(.custom("PirataOne-Regular", size: u(90)))
            .foregroundColor(.parchment)
            .shadow(color: .black.opacity(0.25), radius: 2, y: 2)
            .minimumScaleFactor(0.6)
            .lineLimit(1)
    }

    private var lockedView: some View {
        VStack(spacing: u(20)) {
            Spacer()
            Image(systemName: "lock.fill")
                .font(.system(size: f(60)))
                .foregroundColor(.gold)
            Text("Scan a friend's code to see\ntheir achievements and notes")
                .font(.system(size: f(26), design: .rounded))
                .foregroundColor(.parchment)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func achievementsCard(_ friend: PlayerProfile) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(friend.name)'s achievements")
                    .font(.system(size: f(30), weight: .regular, design: .rounded))
                    .foregroundColor(.parchment)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Spacer()
                Image(systemName: "star.fill")
                    .font(.system(size: f(22)))
                    .foregroundColor(.deepBrown)
                    .frame(width: u(70), height: u(70))
                    .background(Circle().fill(Color.gold.opacity(0.9)))
            }
            .padding(.horizontal, u(40))
            .padding(.vertical, u(18))

            Rectangle().fill(Color.gold).frame(height: max(2, u(4)))

            VStack(spacing: u(18)) {
                ForEach(friend.achievements) { item in
                    AchievementRow(s: s, item: item)
                }
            }
            .padding(u(22))
        }
        .background(Color.deepBrown)
        .clipShape(RoundedRectangle(cornerRadius: u(60), style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: u(60), style: .continuous)
                .stroke(Color.gold, lineWidth: max(2, u(5)))
        )
        .shadow(color: .black.opacity(0.25), radius: 0, y: u(12))
    }

    private func notesHeader(_ friend: PlayerProfile) -> some View {
        HStack {
            Text("🌴").font(.system(size: u(70)))
            Spacer()
            Text("Notes from \(friend.name)")
                .font(.system(size: f(26), weight: .regular, design: .rounded))
                .foregroundColor(.deepBrown.opacity(0.8))
                .padding(.horizontal, u(44))
                .padding(.vertical, u(22))
                .background(Capsule().fill(Color.sand))
                .overlay(Capsule().stroke(Color.inkBrown.opacity(0.6), lineWidth: max(2, u(5))))
                .shadow(color: .black.opacity(0.25), radius: 0, y: u(8))
            Spacer()
            Text("🌴").font(.system(size: u(70)))
        }
    }

    private func notesList(_ friend: PlayerProfile) -> some View {
        VStack(spacing: u(20)) {
            ForEach(friend.notes) { note in
                NoteRow(s: s, note: note, isSelected: selectedNote == note.id)
                    .onTapGesture { selectedNote = note.id }
            }
        }
    }

    private var qrButton: some View {
        Button { showQRSheet = true } label: {
            HStack(spacing: u(24)) {
                Image(systemName: "qrcode")
                    .font(.system(size: f(36)))
                    .foregroundColor(.deepBrown)
                    .frame(width: u(100), height: u(100))
                    .background(Circle().fill(Color.parchment))

                VStack(alignment: .leading, spacing: u(4)) {
                    Text(friend == nil ? "Scan QR to connect" : "Scan another friend")
                        .font(.system(size: f(30), weight: .regular, design: .rounded))
                    Text("Connect with a friend nearby")
                        .font(.system(size: f(20), design: .rounded))
                        .lineLimit(2)
                }
                .foregroundColor(.deepBrown)
                .multilineTextAlignment(.leading)

                Spacer(minLength: 0)
                Image(systemName: "wave.3.right")
                    .font(.system(size: f(28)))
                    .foregroundColor(.deepBrown)
            }
            .padding(u(20))
            .background(
                Capsule().fill(Color.gold)
                    .shadow(color: .black.opacity(0.3), radius: 0, y: u(10))
            )
            .overlay(Capsule().stroke(Color.inkBrown.opacity(0.6), lineWidth: max(2, u(5))))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Components

struct CoinButton: View, Scaled {
    let s: CGFloat
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: f(32), weight: .medium))
                .foregroundColor(.deepBrown)
                .frame(width: u(88), height: u(88))
                .background(Circle().fill(Color.sand))
                .overlay(Circle().stroke(Color.inkBrown.opacity(0.7), lineWidth: max(2, u(5))))
                .shadow(color: Color.inkBrown.opacity(0.8), radius: 0, y: u(10))
        }
    }
}

struct AchievementRow: View, Scaled {
    let s: CGFloat
    let item: Achievement

    var body: some View {
        HStack(spacing: u(24)) {
            Text(String(item.name.prefix(1)))
                .font(.system(size: f(36), design: .rounded))
                .foregroundColor(.deepBrown.opacity(0.8))
                .frame(width: u(92), height: u(92))
                .background(Circle().fill(Color.sand))
                .padding(u(8))
                .background(Circle().fill(Color.parchment.opacity(0.6)))

            VStack(alignment: .leading, spacing: u(4)) {
                Text(item.name)
                Text("“\(item.text)”")
            }
            .font(.system(size: f(24), design: .rounded))
            .foregroundColor(.deepBrown.opacity(0.85))
            .lineLimit(3)
            .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: u(8))

            Text("+\(item.points)")
                .font(.system(size: f(26), weight: .medium, design: .rounded))
                .foregroundColor(.deepBrown)
                .padding(.horizontal, u(24))
                .padding(.vertical, u(12))
                .background(Capsule().fill(Color.gold))
                .shadow(color: Color.inkBrown, radius: 0, y: u(5))
        }
        .padding(u(20))
        .background(RoundedRectangle(cornerRadius: u(36), style: .continuous).fill(Color.parchment))
        .shadow(color: Color.sand, radius: 0, y: u(7))
    }
}

struct NoteRow: View, Scaled {
    let s: CGFloat
    let note: FriendNote
    let isSelected: Bool

    var body: some View {
        HStack(spacing: u(28)) {
            Image(systemName: isSelected ? "note.text" : "note")
                .font(.system(size: f(26), weight: .medium))
                .foregroundColor(isSelected ? .parchment : .deepBrown.opacity(0.6))
                .frame(width: u(76), height: u(76))
                .background(Circle().fill(isSelected ? Color.inkBrown : Color.clear))
                .overlay(
                    Circle().stroke(isSelected ? Color.inkBrown : Color.gray.opacity(0.7),
                                    lineWidth: max(2, u(5)))
                )

            Text(note.text)
                .font(.system(size: f(26)))
                .foregroundColor(.deepBrown.opacity(0.85))
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, u(32))
        .padding(.vertical, u(22))
        .background(
            RoundedRectangle(cornerRadius: u(44), style: .continuous)
                .fill(isSelected ? Color.parchment : Color.mist)
        )
        .overlay(
            RoundedRectangle(cornerRadius: u(44), style: .continuous)
                .stroke(isSelected ? Color.gold : .clear, lineWidth: max(2, u(7)))
        )
        .shadow(color: .black.opacity(0.2), radius: 0, y: u(8))
    }
}

// MARK: - QR Sheet (My Code / Scan)

struct QRConnectSheet: View {
    let myCode: String
    let onScanned: (String) -> Void

    enum Mode: String, CaseIterable { case scan = "Scan", mine = "My Code" }
    @State private var mode: Mode = .mine   // start on "My Code" (works everywhere, incl. simulator)

    var body: some View {
        VStack(spacing: 20) {
            Picker("Mode", selection: $mode) {
                ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.top, 24)
            .padding(.horizontal)

            switch mode {
            case .scan:
                QRScannerView(onFound: onScanned)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(Color.gold, lineWidth: 4)
                    )
                    .padding(.horizontal)
                Text("Point your camera at your friend's code")
                    .foregroundColor(.secondary)

            case .mine:
                Spacer()
                if let image = QRGenerator.image(from: myCode) {
                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 300, height: 300)
                        .padding(20)
                        .background(RoundedRectangle(cornerRadius: 28).fill(.white))
                        .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.gold, lineWidth: 4))
                }
                Text("Let a friend scan this to connect")
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding(.bottom, 24)
        .presentationDetents([.large])
    }
}

// MARK: - QR Generator

enum QRGenerator {
    static func image(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "L"

        guard let output = filter.outputImage?
            .transformed(by: CGAffineTransform(scaleX: 10, y: 10)),
              let cg = context.createCGImage(output, from: output.extent)
        else { return nil }
        return UIImage(cgImage: cg)
    }
}

// MARK: - QR Scanner

struct QRScannerView: UIViewControllerRepresentable {
    let onFound: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerController {
        let vc = ScannerController()
        vc.onFound = onFound
        return vc
    }
    func updateUIViewController(_ uiViewController: ScannerController, context: Context) {}
}

final class ScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onFound: ((String) -> Void)?
    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var didFind = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        #if targetEnvironment(simulator)
        showMessage("The simulator has no camera.\nRun the app on a real iPhone to scan.")
        return
        #else
        // Without NSCameraUsageDescription in Info.plist, iOS kills the app right here.
        guard Bundle.main.object(forInfoDictionaryKey: "NSCameraUsageDescription") != nil else {
            showMessage("Missing NSCameraUsageDescription in Info.plist")
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    granted ? self.setupSession()
                            : self.showMessage("Camera access was denied.", withSettingsButton: true)
                }
            }
        default:
            showMessage("Camera access is off.\nEnable it in Settings to scan.", withSettingsButton: true)
        }
        #endif
    }

    private func setupSession() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            showMessage("Camera not available.")
            return
        }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        previewLayer = layer

        DispatchQueue.global(qos: .userInitiated).async { self.session.startRunning() }
    }

    private func showMessage(_ text: String, withSettingsButton: Bool = false) {
        let label = UILabel()
        label.text = text
        label.textColor = .white
        label.numberOfLines = 0
        label.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [label])
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        if withSettingsButton {
            var config = UIButton.Configuration.filled()
            config.title = "Open Settings"
            let button = UIButton(configuration: config, primaryAction: UIAction { _ in
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            })
            stack.addArrangedSubview(button)
        }

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning { session.stopRunning() }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard !didFind,
              let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = obj.stringValue else { return }
        didFind = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        onFound?(value)
    }
}

#Preview {
    BoardView()
}
