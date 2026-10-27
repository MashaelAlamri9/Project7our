
import SwiftUI
import Combine
import UIKit
import AVFoundation
import CoreImage.CIFilterBuiltins
import CoreBluetooth

// MARK: - Colors
extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
    static let boardBg = Color(hex: 0x688582)
    static let boardGold = Color(hex: 0xCDAB5A)
    static let boardCream = Color(hex: 0xE8DDB5)
    static let boardBrown = Color(hex: 0x4A3410)
}

// MARK: - Models
struct Note: Codable, Identifiable, Hashable {
    let id: String
    let text: String
    let ts: Int
    var shared: Bool
}

struct Friend: Codable, Identifiable {
    let id: String
    var name: String
    var token: String                         // secret from his QR (proves we scanned him)
    var notes: [String: Note] = [:]           // last synced shared notes
    var sortedNotes: [Note] { notes.values.sorted { $0.ts > $1.ts } }
}

/// Inside the QR (identity only)
private struct QRPayload: Codable {
    let id: String
    let n: String
    let k: String
}

/// Sent over Bluetooth between friends
struct PNote: Codable { let i: String; let t: String; let ts: Int }
struct Wire: Codable {
    let id: String          // sender id
    let n: String           // sender name
    let k: String           // proof: the receiver's own secret token
    let m: [PNote]          // sender's shared notes
}

private struct Saved: Codable {
    var myId: String
    var myName: String
    var myToken: String
    var myNotes: [Note]
    var friends: [Friend]
}

enum ImportResult { case ok, own, invalid }

// MARK: - Store
@MainActor
final class BoardStore: ObservableObject {
    static let shared = BoardStore()

    private let prefix = "board2:"
    private let key = "board.saved2"

    @Published var myId: String
    @Published var myName: String
    @Published var myToken: String
    @Published var myNotes: [Note]
    @Published var friends: [String: Friend]

    /// Called whenever MY shared data changed -> BluetoothManager pushes it to friends
    var onChange: (() -> Void)?

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let s = try? JSONDecoder().decode(Saved.self, from: data) {
            myId = s.myId; myName = s.myName; myToken = s.myToken; myNotes = s.myNotes
            friends = Dictionary(s.friends.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        } else {
            myId = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(16)).lowercased()
            myToken = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(16)).lowercased()
            myName = "Player"; myNotes = []; friends = [:]
        }
        save()
    }

    private func save() {
        let s = Saved(myId: myId, myName: myName, myToken: myToken,
                      myNotes: myNotes, friends: Array(friends.values))
        if let data = try? JSONEncoder().encode(s) { UserDefaults.standard.set(data, forKey: key) }
    }

    func setName(_ name: String) {
        let t = name.trimmingCharacters(in: .whitespaces)
        myName = t.isEmpty ? "Player" : t
        save()
        onChange?()
    }

    func addNote(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        let ts = Int(Date().timeIntervalSince1970 * 1_000_000)
        myNotes.append(Note(id: "\(myId)-\(ts)", text: t, ts: ts, shared: true))
        save()
        onChange?()                              // -> appears on friends' boards live
    }

    func toggleShare(_ note: Note) {
        guard let i = myNotes.firstIndex(where: { $0.id == note.id }) else { return }
        myNotes[i].shared.toggle()
        save()
        onChange?()
    }

    // MARK: QR (identity only)
    func buildQR() -> String {
        let p = QRPayload(id: myId, n: myName, k: myToken)
        guard let json = try? JSONEncoder().encode(p),
              let s = String(data: json, encoding: .utf8) else { return prefix }
        return prefix + s
    }

    /// Called after scanning someone's QR -> saves him as a friend (pairing).
    func importQR(_ raw: String) -> ImportResult {
        guard raw.hasPrefix(prefix),
              let data = String(raw.dropFirst(prefix.count)).data(using: .utf8),
              let p = try? JSONDecoder().decode(QRPayload.self, from: data) else { return .invalid }
        if p.id == myId { return .own }

        var f = friends[p.id] ?? Friend(id: p.id, name: p.n, token: p.k)
        f.name = p.n
        f.token = p.k
        friends[p.id] = f
        save()
        return .ok
    }

    // MARK: Live sync
    /// My name + all my shared notes. `proof` = the friend's secret token (from his QR).
    func wireData(proof: String) -> Data? {
        let shared = myNotes.filter(\.shared).sorted { $0.ts > $1.ts }
            .map { PNote(i: $0.id, t: $0.text, ts: $0.ts) }
        return try? JSONEncoder().encode(Wire(id: myId, n: myName, k: proof, m: shared))
    }

    /// A connected friend sent his current shared notes -> replace what we have.
    func applyRemote(_ w: Wire) {
        guard var f = friends[w.id] else { return }          // only saved friends
        f.name = w.n
        f.notes = Dictionary(w.m.map { ($0.i, Note(id: $0.i, text: $0.t, ts: $0.ts, shared: true)) },
                             uniquingKeysWith: { a, _ in a })
        friends[w.id] = f
        save()
    }
}

// MARK: - Bluetooth plumbing
private enum BLE {
    static let service        = CBUUID(string: "6B0A7E10-5C2D-4E8B-9A41-0B0A4D000001")
    static let toPeripheral   = CBUUID(string: "6B0A7E10-5C2D-4E8B-9A41-0B0A4D000002") // central WRITES here
    static let fromPeripheral = CBUUID(string: "6B0A7E10-5C2D-4E8B-9A41-0B0A4D000003") // peripheral NOTIFIES here
}

/// BLE packets are tiny, so every message is: [4 bytes length][payload] cut into chunks.
private enum Framer {
    static func frame(_ d: Data) -> Data {
        let n = UInt32(d.count)
        var out = Data([UInt8((n >> 24) & 0xFF), UInt8((n >> 16) & 0xFF), UInt8((n >> 8) & 0xFF), UInt8(n & 0xFF)])
        out.append(d)
        return out
    }
    static func chunks(_ d: Data, size: Int) -> [Data] {
        let framed = frame(d)
        let step = max(20, size)
        var res: [Data] = []
        var off = 0
        while off < framed.count {
            res.append(framed.subdata(in: off..<min(off + step, framed.count)))
            off += step
        }
        return res
    }
}

private struct Reassembler {
    private var buf = Data()
    mutating func feed(_ d: Data) -> [Data] {
        buf.append(d)
        var out: [Data] = []
        while buf.count >= 4 {
            let len = (Int(buf[0]) << 24) | (Int(buf[1]) << 16) | (Int(buf[2]) << 8) | Int(buf[3])
            if len > 500_000 { buf.removeAll(); break }                  // garbage protection
            guard buf.count >= 4 + len else { break }
            out.append(buf.subdata(in: 4..<(4 + len)))
            buf.removeSubrange(0..<(4 + len))
        }
        return out
    }
}

/// I am the CENTRAL, the friend is the peripheral.
private final class OutLink {
    let friendId: String
    let peripheral: CBPeripheral
    var writeChar: CBCharacteristic?
    var notifyChar: CBCharacteristic?
    var rx = Reassembler()
    var queue: [Data] = []
    var sending = false
    var ready = false          // notifications enabled -> hello sent
    var authed = false         // friend proved he scanned us too
    init(friendId: String, peripheral: CBPeripheral) {
        self.friendId = friendId; self.peripheral = peripheral
    }
}

/// I am the PERIPHERAL, the friend is the central.
private final class InLink {
    let central: CBCentral
    var rx = Reassembler()
    var queue: [Data] = []
    var friendId: String?      // set once he proves he scanned us
    init(central: CBCentral) { self.central = central }
}

// MARK: - Bluetooth manager
@MainActor
final class BluetoothManager: NSObject, ObservableObject {
    static let shared = BluetoothManager()

    @Published private(set) var online: Set<String> = []     // ids of connected friends
    @Published private(set) var problem: String?             // shown if Bluetooth is off / denied

    private let store: BoardStore
    private var central: CBCentralManager!
    private var peripheralManager: CBPeripheralManager!
    private var writeChar: CBMutableCharacteristic!
    private var notifyChar: CBMutableCharacteristic!
    private var serviceAdded = false

    private var outByPeripheral: [UUID: OutLink] = [:]
    private var outByFriend: [String: OutLink] = [:]
    private var inLinks: [UUID: InLink] = [:]
    private var cooldown: [String: Date] = [:]

    override init() {
        store = BoardStore.shared
        super.init()
        store.onChange = { [weak self] in self?.broadcast() }
        central = CBCentralManager(delegate: self, queue: .main)
        peripheralManager = CBPeripheralManager(delegate: self, queue: .main)
    }

    // MARK: Public
    /// Safe to call many times (app appears / returns to foreground).
    func start() {
        startScanning()
        startAdvertisingIfReady()
    }

    /// Call after a new friend was saved (QR scan) to connect right away.
    func refresh() {
        cooldown.removeAll()
        start()
    }

    func broadcast() {
        for l in outByFriend.values { sendOut(l) }
        for l in inLinks.values where l.friendId != nil { sendIn(l) }
    }

    // MARK: State
    private func updateProblem() {
        let states = [central.state, peripheralManager.state]
        if states.contains(.unauthorized) {
            problem = "Bluetooth permission is off.\nSettings > your app > Bluetooth."
        } else if states.contains(.poweredOff) {
            problem = "Bluetooth is off. Turn it on to connect with friends."
        } else if states.contains(.unsupported) {
            problem = "This device doesn't support Bluetooth LE."
        } else {
            problem = nil
        }
    }

    private func startScanning() {
        guard central.state == .poweredOn else { return }
        central.stopScan()
        central.scanForPeripherals(withServices: [BLE.service],
                                   options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
    }

    private func setupService() {
        guard !serviceAdded, peripheralManager.state == .poweredOn else { return }
        writeChar = CBMutableCharacteristic(type: BLE.toPeripheral, properties: [.write],
                                            value: nil, permissions: [.writeable])
        notifyChar = CBMutableCharacteristic(type: BLE.fromPeripheral, properties: [.notify],
                                             value: nil, permissions: [.readable])
        let svc = CBMutableService(type: BLE.service, primary: true)
        svc.characteristics = [writeChar, notifyChar]
        peripheralManager.add(svc)
    }

    private func startAdvertisingIfReady() {
        guard peripheralManager.state == .poweredOn, serviceAdded, !peripheralManager.isAdvertising else { return }
        peripheralManager.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [BLE.service],
            CBAdvertisementDataLocalNameKey: String(store.myId.prefix(8))   // lets friends recognise me
        ])
    }

    // MARK: Central side (I connect to a friend)
    fileprivate func handleDiscover(_ peripheral: CBPeripheral, name: String?) {
        guard let name,
              let friend = store.friends.values.first(where: { String($0.id.prefix(8)) == name }),
              store.myId < friend.id,                               // only the smaller id connects
              outByFriend[friend.id] == nil,
              (cooldown[friend.id] ?? .distantPast) < Date() else { return }

        let link = OutLink(friendId: friend.id, peripheral: peripheral)
        peripheral.delegate = self
        outByPeripheral[peripheral.identifier] = link
        outByFriend[friend.id] = link
        central.connect(peripheral, options: nil)

        // give up if the handshake doesn't finish (e.g. he didn't scan me back)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 12_000_000_000)
            if !link.authed, self.outByFriend[friend.id] === link {
                self.cooldown[friend.id] = Date().addingTimeInterval(15)
                self.central.cancelPeripheralConnection(peripheral)
                self.dropOut(link)
            }
        }
    }

    fileprivate func dropOut(_ link: OutLink) {
        if outByPeripheral[link.peripheral.identifier] === link { outByPeripheral[link.peripheral.identifier] = nil }
        if outByFriend[link.friendId] === link { outByFriend[link.friendId] = nil }
        online.remove(link.friendId)
    }

    private func sendOut(_ link: OutLink) {
        guard link.ready, let f = store.friends[link.friendId],
              let data = store.wireData(proof: f.token) else { return }
        let size = link.peripheral.maximumWriteValueLength(for: .withResponse)
        link.queue.append(contentsOf: Framer.chunks(data, size: size))
        pumpOut(link)
    }

    fileprivate func pumpOut(_ link: OutLink) {
        guard !link.sending, let ch = link.writeChar, !link.queue.isEmpty else { return }
        link.sending = true
        link.peripheral.writeValue(link.queue.removeFirst(), for: ch, type: .withResponse)
    }

    fileprivate func handleOutData(_ link: OutLink, data: Data) {
        for msg in link.rx.feed(data) {
            guard let w = try? JSONDecoder().decode(Wire.self, from: msg),
                  w.id == link.friendId,
                  store.friends[w.id] != nil,
                  w.k == store.myToken else { continue }            // he must know MY token
            link.authed = true
            online.insert(w.id)
            store.applyRemote(w)
        }
    }

    // MARK: Peripheral side (a friend connects to me)
    private func sendIn(_ link: InLink) {
        guard let fid = link.friendId, let f = store.friends[fid],
              let data = store.wireData(proof: f.token) else { return }
        link.queue.append(contentsOf: Framer.chunks(data, size: link.central.maximumUpdateValueLength))
        pumpIn(link)
    }

    private func pumpIn(_ link: InLink) {
        guard notifyChar != nil else { return }
        while let first = link.queue.first {
            if peripheralManager.updateValue(first, for: notifyChar, onSubscribedCentrals: [link.central]) {
                link.queue.removeFirst()
            } else { break }                                         // wait for "ready" callback
        }
    }

    fileprivate func handleIncomingWrite(centralId: UUID, central c: CBCentral, value: Data) {
        let link: InLink
        if let existing = inLinks[centralId] { link = existing }
        else { link = InLink(central: c); inLinks[centralId] = link }

        for msg in link.rx.feed(value) {
            guard let w = try? JSONDecoder().decode(Wire.self, from: msg) else { continue }
            if link.friendId == nil {
                // first message = hello: he must be my friend AND know MY token
                guard store.friends[w.id] != nil, w.k == store.myToken else { continue }
                link.friendId = w.id
                online.insert(w.id)
                store.applyRemote(w)
                sendIn(link)                                         // answer with my board
            } else if w.id == link.friendId {
                store.applyRemote(w)
            }
        }
    }
}

// MARK: Central manager delegate
extension BluetoothManager: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            self.updateProblem()
            self.startScanning()
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                                    advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        Task { @MainActor in self.handleDiscover(peripheral, name: name) }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([BLE.service])
    }

    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            if let link = self.outByPeripheral[peripheral.identifier] {
                self.cooldown[link.friendId] = Date().addingTimeInterval(10)
                self.dropOut(link)
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            if let link = self.outByPeripheral[peripheral.identifier] {
                self.cooldown[link.friendId] = Date().addingTimeInterval(3)
                self.dropOut(link)
            }
        }
    }
}

// MARK: Peripheral (remote friend) delegate — I am central
extension BluetoothManager: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let svc = peripheral.services?.first(where: { $0.uuid == BLE.service }) else { return }
        peripheral.discoverCharacteristics([BLE.toPeripheral, BLE.fromPeripheral], for: svc)
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        let chars = service.characteristics ?? []
        Task { @MainActor in
            guard let link = self.outByPeripheral[peripheral.identifier] else { return }
            link.writeChar = chars.first { $0.uuid == BLE.toPeripheral }
            link.notifyChar = chars.first { $0.uuid == BLE.fromPeripheral }
            if let n = link.notifyChar { peripheral.setNotifyValue(true, for: n) }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.isNotifying else { return }
        Task { @MainActor in
            guard let link = self.outByPeripheral[peripheral.identifier] else { return }
            link.ready = true
            self.sendOut(link)                                       // hello + my board
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        Task { @MainActor in
            guard let link = self.outByPeripheral[peripheral.identifier] else { return }
            link.sending = false
            if error != nil { link.queue.removeAll(); return }
            self.pumpOut(link)
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == BLE.fromPeripheral, let data = characteristic.value else { return }
        Task { @MainActor in
            guard let link = self.outByPeripheral[peripheral.identifier] else { return }
            self.handleOutData(link, data: data)
        }
    }
}

// MARK: Peripheral manager delegate — I am peripheral
extension BluetoothManager: CBPeripheralManagerDelegate {
    nonisolated func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        Task { @MainActor in
            self.updateProblem()
            self.setupService()
        }
    }

    nonisolated func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        Task { @MainActor in
            if error == nil {
                self.serviceAdded = true
                self.startAdvertisingIfReady()
            }
        }
    }

    nonisolated func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral,
                                       didSubscribeTo characteristic: CBCharacteristic) {
        Task { @MainActor in
            if self.inLinks[central.identifier] == nil {
                self.inLinks[central.identifier] = InLink(central: central)
            }
        }
    }

    nonisolated func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral,
                                       didUnsubscribeFrom characteristic: CBCharacteristic) {
        Task { @MainActor in
            if let link = self.inLinks.removeValue(forKey: central.identifier), let fid = link.friendId {
                self.online.remove(fid)
            }
        }
    }

    nonisolated func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        if let first = requests.first { peripheral.respond(to: first, withResult: .success) }
        let items = requests.compactMap { r -> (UUID, CBCentral, Data)? in
            guard let v = r.value else { return nil }
            return (r.central.identifier, r.central, v)
        }
        Task { @MainActor in
            for (id, c, v) in items { self.handleIncomingWrite(centralId: id, central: c, value: v) }
        }
    }

    nonisolated func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        Task { @MainActor in
            for l in self.inLinks.values { self.pumpIn(l) }
        }
    }
}

// MARK: - Board screen
struct BoardView: View {
    @StateObject private var store = BoardStore.shared
    @StateObject private var peers = BluetoothManager.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var scanning = false
    @State private var showMyCode = false
    @State private var toast: String?
    @State private var message = ""

    var body: some View {
        ZStack {
            Color.boardBg.ignoresSafeArea()

            VStack(spacing: 8) {
                HStack {
                    Spacer()
                    RoundButton(systemName: "qrcode") { showMyCode = true }
                }
                .padding(.horizontal)

                Text("The Board")
                    .font(.system(size: 48, weight: .light))
                    .foregroundColor(.boardCream)

                if let p = peers.problem {
                    Text(p)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.boardCream)
                        .padding(.horizontal)
                }

                if store.friends.isEmpty {
                    Spacer()
                    VStack(spacing: 10) {
                        Image(systemName: "lock.fill").font(.system(size: 36)).foregroundColor(.boardGold)
                        Text("Scan a friend's code (and let him scan yours)\nto see their messages live")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.boardCream)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(store.friends.values.sorted { $0.name < $1.name }) { f in
                                FriendCard(friend: f, online: peers.online.contains(f.id))
                            }
                        }
                        .padding()
                    }
                }

                // Write a message: goes straight to every connected friend's board
                HStack {
                    TextField("Write a message...", text: $message)
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.send)
                        .onSubmit(send)
                    Button(action: send) {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(.boardBrown)
                            .frame(width: 44, height: 44)
                            .background(Color.boardGold)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal)

                ScanPill { scanning = true }
                    .padding(.horizontal)
            }
        }
        .onAppear { peers.start() }
        .onChange(of: scenePhase) { phase in
            if phase == .active { peers.start() }
        }
        .sheet(isPresented: $showMyCode) { MyCodeView(store: store) }
        .sheet(isPresented: $scanning) {
            ZStack(alignment: .topTrailing) {
                QRScanner { code in
                    let result = store.importQR(code)
                    scanning = false
                    if result == .ok { peers.refresh() }       // try to connect right away
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        switch result {
                        case .ok: toast = "Friend saved! You'll connect automatically when nearby."
                        case .own: toast = "That's your own code."
                        case .invalid: toast = "Not a valid Board code."
                        }
                    }
                }
                .ignoresSafeArea()
                RoundButton(systemName: "xmark") { scanning = false }.padding()
            }
        }
        .alert("The Board", isPresented: Binding(get: { toast != nil }, set: { if !$0 { toast = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(toast ?? "") }
    }

    private func send() {
        store.addNote(message)
        message = ""
    }
}

struct FriendCard: View {
    let friend: Friend
    let online: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(friend.name).font(.title3.bold()).foregroundColor(.boardBrown)
                Circle()
                    .fill(online ? Color.green : Color.gray)
                    .frame(width: 10, height: 10)
                Text(online ? "Connected" : "Out of range")
                    .font(.caption)
                    .foregroundColor(.boardBrown)
                Spacer()
            }
            Divider()
            if friend.notes.isEmpty {
                Text("No shared messages yet").foregroundColor(.boardBrown)
            }
            ForEach(friend.sortedNotes) { n in
                Text("• \(n.text)").foregroundColor(.boardBrown)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.boardCream)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct ScanPill: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: "qrcode.viewfinder")
                    .foregroundColor(.boardBrown)
                    .frame(width: 52, height: 52)
                    .background(Color.boardCream)
                    .clipShape(Circle())
                VStack(alignment: .leading) {
                    Text("Scan QR to add a friend").font(.title3)
                    Text("Only needed once").font(.footnote)
                }
                .foregroundColor(.boardBrown)
                Spacer()
            }
            .padding(10)
            .background(Color.boardGold)
            .clipShape(Capsule())
        }
    }
}

struct RoundButton: View {
    let systemName: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .foregroundColor(.boardBrown)
                .frame(width: 52, height: 52)
                .background(Color.boardCream)
                .clipShape(Circle())
        }
    }
}

// MARK: - My code + my messages
struct MyCodeView: View {
    @ObservedObject var store: BoardStore
    @State private var name = ""

    var body: some View {
        ZStack {
            Color.boardBg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    TextField("Your name", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: name) { store.setName($0) }

                    if let img = QRMaker.image(from: store.buildQR()) {
                        Image(uiImage: img)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 260, height: 260)
                            .padding(12)
                            .background(Color.white)
                    }

                    Text("Your friend scans this once, and you scan his.\nAfter that you connect automatically by Bluetooth.")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.boardCream)

                    ForEach(store.myNotes.reversed()) { n in
                        Toggle(isOn: Binding(get: { n.shared }, set: { _ in store.toggleShare(n) })) {
                            VStack(alignment: .leading) {
                                Text(n.text)
                                Text(n.shared ? "Shared on friends' boards" : "Private").font(.caption)
                            }
                            .foregroundColor(.boardCream)
                        }
                        .tint(.boardGold)
                    }
                }
                .padding()
            }
        }
        .onAppear { name = store.myName }
    }
}

// MARK: - QR generation
enum QRMaker {
    static func image(from string: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)),
              let cg = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

// MARK: - QR scanning
struct QRScanner: UIViewControllerRepresentable {
    let onCode: (String) -> Void
    func makeUIViewController(context: Context) -> ScannerVC {
        let vc = ScannerVC(); vc.onCode = onCode; return vc
    }
    func updateUIViewController(_ vc: ScannerVC, context: Context) {}
}

final class ScannerVC: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCode: ((String) -> Void)?
    private let session = AVCaptureSession()
    private var preview: AVCaptureVideoPreviewLayer?
    private var configured = false
    private var done = false
    private let label = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        label.textColor = .white
        label.numberOfLines = 0
        label.textAlignment = .center
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)
        ])

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configure()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted { self?.configure() }
                    else { self?.show("Camera access was denied.\nGo to Settings > your app > Camera and turn it on.") }
                }
            }
        default:
            show("Camera access is off.\nGo to Settings > your app > Camera and turn it on.")
        }
    }

    private func show(_ text: String) {
        label.text = text
        label.isHidden = false
    }

    private func configure() {
        guard !configured else { return }
        guard let device = AVCaptureDevice.default(for: .video) else {
            show("No camera found.\nThe simulator has no camera - run the app on a real iPhone.")
            return
        }
        guard let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else {
            show("Could not open the camera.")
            return
        }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { show("Could not read QR codes."); return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.insertSublayer(layer, at: 0)
        preview = layer

        configured = true
        startSession()
    }

    private func startSession() {
        guard configured, !session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [session] in session.startRunning() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        preview?.frame = view.bounds
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startSession()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning { session.stopRunning() }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput objects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard !done,
              let obj = objects.first as? AVMetadataMachineReadableCodeObject,
              let value = obj.stringValue else { return }
        done = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onCode?(value)
    }
}
