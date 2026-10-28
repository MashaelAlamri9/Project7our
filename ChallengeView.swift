import SwiftUI
import Combine

// MARK: - Model

struct Challenge: Identifiable, Equatable {
    let id: Int
    let name: String
    let description: String
}

enum ChallengeStore {
    // عدّل / زوّد التحديات هنا (لازم كل واحد يكون له id مختلف)
    static let all: [Challenge] = [
        Challenge(id: 1, name: "Smile", description: "Smile to your nurse"),
        Challenge(id: 2, name: "Window Explorer ", description: "notice 3 interesting things around you"),
        Challenge(id: 3, name: "Happy playlist ", description: "Music Moment"),
        Challenge(id: 4, name: "Mini Walk", description: "walk a doctor-approved distance"),
        Challenge(id: 5, name: "Guess the Nurse’s Favorite", description: "ask nurses about their fav color"),
        Challenge(id: 6, name: "Reading Quest", description: "read a page of a book or a short story"),
        Challenge(id: 7, name: "Warm & Uplifting", description: "Leave an encouraging message for another patient"),
        Challenge(id: 8, name: "Healing", description: "Tell a joke to someone after each meds you take")
    ]
}


// MARK: - ViewModel

final class ChallengeViewModel: ObservableObject {
    @Published var current: Challenge? = nil
    @Published var isOpen: Bool = false
    @Published private(set) var isBusy: Bool = false
    @Published var showPoints: Bool = false     // "+5" popup

    private let key = "completedChallengeIDs"
    // التحديات المنجزة (✓) ما ترجع أبداً
    private var completed: Set<Int> {
        didSet { UserDefaults.standard.set(Array(completed), forKey: key) }
    }

    init() {
        let saved = UserDefaults.standard.array(forKey: key) as? [Int] ?? []
        completed = Set(saved)
        pickNext()
    }

    /// يختار تحدي عشوائي من غير المنجزة (ويتجنب نفس التحدي الحالي لو فيه غيره)
    private var seenThisRound: Set<Int> = []

    private func pickNext() {
        let remaining = ChallengeStore.all.filter { !completed.contains($0.id) }
        var fresh = remaining.filter { !seenThisRound.contains($0.id) }

        if fresh.isEmpty {                       // شاف كل المتبقي، يبدأ دورة جديدة
            seenThisRound = []
            fresh = remaining.filter { $0 != current }
            if fresh.isEmpty { fresh = remaining }
        }

        current = fresh.randomElement()
        if let c = current { seenThisRound.insert(c.id) }
    }

    func openChest() {
        guard current != nil, !isOpen, !isBusy else { return }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.65)) { isOpen = true }
    }

    /// الزر الأوسط: تحدي عشوائي جديد
    func shuffle() { swapChallenge(markDone: false, reopen: true) }

    /// زر ✓: يعتبر التحدي منجز وما يطلع مرة ثانية
    /// (لازم يكون الصندوق مفتوح، يعني شاف التحدي)
    func done() {
        guard isOpen else { return }
        swapChallenge(markDone: true, reopen: false)
    }

    private func swapChallenge(markDone: Bool, reopen: Bool) {
        guard !isBusy else { return }
        isBusy = true
        let wasOpen = isOpen
        withAnimation(.easeIn(duration: 0.3)) { isOpen = false }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [self] in
            if markDone, let c = current {
                completed.insert(c.id)
                // +5 نقاط + إشعار على الـ Board ("Yay! ... did the ...")
                let name = c.name
                Task { @MainActor in BoardStore.shared.completeChallenge(name) }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { showPoints = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [self] in
                    withAnimation(.easeOut(duration: 0.3)) { showPoints = false }
                }
            }
            pickNext()
            if wasOpen && reopen && current != nil {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.65)) { isOpen = true }
            }
            isBusy = false
        }
    }
}

// MARK: - Main Screen

struct ChallengeView: View {
    @StateObject private var vm = ChallengeViewModel()
    @Environment(\.dismiss) private var dismiss   // زر X يقفل الصفحة
    /// Optional: pass this if ChallengeView is NOT presented as a sheet / pushed screen
    /// (e.g. you switch screens with a @State), so the Back button can return to the Board.
    var onBack: (() -> Void)? = nil
    @State private var float = false

    private let gold = Color(red: 0.93, green: 0.76, blue: 0.30)

    // مواضع ثابتة: الصندوق ينزل 8 نقاط تحت منتصف سطح الرمل فيبان واقف عليه
    private let chestBottomY: CGFloat = 410
    private var sandY: CGFloat { chestBottomY - 90 }

    private func goBack() {
        if let onBack { onBack() } else { dismiss() }
    }

    private var titleText: String {
        guard let c = vm.current else { return "The challenges are over🎉" }
        return vm.isOpen ? c.name : "Click on the treasure"
    }

    var body: some View {
        ZStack {
            Color(red: 0.43, green: 0.65, blue: 0.65).ignoresSafeArea()
            CloudsView()   // الغيوم تتحرك

            VStack(spacing: 0) {
                // اسم التحدي (بدل challenge name)
                Text(titleText)
                    .font(.system(size: 36, weight: .bold, design: .serif).italic())
                    .foregroundColor(gold)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .padding(.horizontal, 24)
                    .padding(.top, 70)
                    .id(titleText)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: titleText)

                Spacer(minLength: 10)

                // الجزيرة + الصندوق + الورقة (تتحرك مع بعض بحركة خفيفة)
                // كل شي مركّب بإحداثيات ثابتة عشان الصندوق يثبت على الرمل بالضبط
                ZStack(alignment: .top) {
                    // الجزيرة (كبّرتها: غيّر 1.12 لو تبيها أكبر أو أصغر)
                    ChallengeIslandView()
                        .scaleEffect(1.12)
                        .offset(y: sandY - 75)

                    // ظل الصندوق على الرمل (يخليه ملزوق بالأرض)
                    Ellipse()
                        .fill(Color.black.opacity(0.22))
                        .frame(width: 190, height: 28)
                        .blur(radius: 4)
                        .offset(x: 0, y: chestBottomY - 20 - 15)

                    ZStack(alignment: .bottom) {
                        // الورقة تطلع من الصندوق
                        ScrollPaper(text: vm.current?.description ?? "")
                            .scaleEffect(vm.isOpen ? 1.1 : 0.3, anchor: .bottom)
                            .offset(y: vm.isOpen ? -150 : 0)
                            .opacity(vm.isOpen ? 1 : 0)

                        // حجم الصندوق: غيّر الرقم 1.35 لو تبيه أكبر أو أصغر
                        ChestView(isOpen: vm.isOpen)
                            .scaleEffect(1.35, anchor: .bottom)
                            .onTapGesture { vm.openChest() }
                    }
                    .frame(height: chestBottomY)   // الصندوق بالنص بالضبط
                }
                .frame(height: chestBottomY + 70)
                .offset(y: float ? -6 : 6)
                .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: float)

                Spacer(minLength: 90)
            }

            // الأزرار
            VStack {
                Spacer()
                HStack(spacing: 0) {
                    RoundIconButton(systemName: "checkmark") { vm.done() }
                    Spacer()
                    RoundIconButton(systemName: "shuffle") { vm.shuffle() }
                    Spacer()
                    RoundIconButton(systemName: "xmark") { goBack() }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 36)
            }
        }
        // زر الرجوع للـ Board (أعلى اليسار)
        .overlay(alignment: .topLeading) {
            Button { goBack() } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left").font(.system(size: 16, weight: .bold))
                    Text("Board").font(.system(size: 17, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Capsule().fill(Color(red: 0.55, green: 0.33, blue: 0.25)))
                .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 2))
                .shadow(color: .black.opacity(0.25), radius: 4, y: 3)
            }
            .padding(.leading, 16)
            .padding(.top, 8)
        }
        .overlay {
            if vm.showPoints {
                Text("+\(Points.perChallenge) ⭐")
                    .font(.system(size: 54, weight: .heavy, design: .rounded))
                    .foregroundColor(gold)
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 3)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .onAppear { float = true }
    }
}

// MARK: - Paper

struct ScrollPaper: View {
    let text: String
    private let paper = Color(red: 0.85, green: 0.68, blue: 0.45)
    private let roll = Color(red: 0.90, green: 0.80, blue: 0.62)

    var body: some View {
        ZStack {
            Rectangle()
                .fill(paper)
                .frame(width: 150, height: 170)

            Text(text)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 14)
                .frame(width: 150, height: 150)
                .id(text)
                .transition(.opacity)

            VStack {
                Capsule().fill(roll).frame(width: 175, height: 22)
                Spacer()
                Capsule().fill(roll).frame(width: 175, height: 22)
            }
            .frame(height: 188)
        }
        .frame(width: 180, height: 200)
    }
}

// MARK: - Chest

struct ChestView: View {
    var isOpen: Bool

    private let brown = Color(red: 0.45, green: 0.22, blue: 0.08)
    private let goldBand = Color(red: 0.88, green: 0.70, blue: 0.30)
    private let coin = Color(red: 0.99, green: 0.80, blue: 0.20)

    var body: some View {
        // الترتيب: الغطا (ورا) ← العملات ← جسم الصندوق (قدام)
        // عشان العملات تطلع من فتحة الصندوق وتنقص بالجزء السفلي ورا الواجهة
        ZStack(alignment: .top) {
            // الغطا
            RoundedRectangle(cornerRadius: 18)
                .fill(brown)
                .overlay(bands)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(goldBand, lineWidth: 4))
                .frame(width: 150, height: 44)
                // لو الغطا انقلب لقدام بدل ورا، خلّ الزاوية سالبة (-100)
                .rotation3DEffect(.degrees(isOpen ? 100 : 0),
                                  axis: (x: 1, y: 0, z: 0),
                                  anchor: .bottom,
                                  perspective: 0.4)

            // العملات (تظهر لما ينفتح)
            ZStack {
                ForEach(Array(coinSpots.enumerated()), id: \.offset) { i, p in
                    coinView
                        .offset(x: p.x, y: p.y - 11)      // p.y = مركز العملة من أعلى الصندوق
                        .scaleEffect(isOpen ? 1 : 0.1)
                        .animation(.spring(response: 0.5, dampingFraction: 0.5)
                                    .delay(isOpen ? 0.05 * Double(i) : 0), value: isOpen)
                }
            }
            .frame(width: 150, height: 44, alignment: .top)
            .opacity(isOpen ? 1 : 0)
            .animation(.easeOut(duration: 0.2), value: isOpen)
            .allowsHitTesting(false)

            // جسم الصندوق (يغطي نصف العملات السفلي)
            RoundedRectangle(cornerRadius: 6)
                .fill(brown)
                .overlay(bands)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(goldBand, lineWidth: 4))
                .overlay(alignment: .top) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(goldBand)
                        .frame(width: 20, height: 24)
                        .overlay(Circle().fill(brown).frame(width: 6, height: 6))
                        .offset(y: -2)
                }
                .frame(width: 150, height: 80)
                .offset(y: 44)
        }
        .frame(width: 150, height: 124, alignment: .top)
    }

    private var coinView: some View {
        Circle()
            .fill(coin)
            .overlay(Circle().stroke(Color.orange.opacity(0.6), lineWidth: 1.5))
            .overlay(Circle().stroke(Color.orange.opacity(0.35), lineWidth: 1).padding(4))
            .frame(width: 22, height: 22)
    }

    // مراكز العملات (x من منتصف الصندوق، y من أعلى الصندوق). خط الحافة = 44
    // الصف الخلفي أول، بعدين الأمامي فوقه — كومة مرتبة داخل الصندوق
    private var coinSpots: [CGPoint] {
        [CGPoint(x: -30, y: 30), CGPoint(x: -10, y: 25), CGPoint(x: 12, y: 26), CGPoint(x: 32, y: 30),
         CGPoint(x: -46, y: 38), CGPoint(x: -22, y: 36), CGPoint(x: 0, y: 34),
         CGPoint(x: 22, y: 36), CGPoint(x: 46, y: 38)]
    }

    private var bands: some View {
        HStack {
            Rectangle().fill(goldBand).frame(width: 12)
            Spacer()
            Rectangle().fill(goldBand).frame(width: 12)
        }
        .padding(.horizontal, 14)
    }
}

// MARK: - Island (رمل في البحر + نخلة)

struct ChallengeIslandView: View {
    @State private var pulse = false

    private let sandSide = Color(red: 0.79, green: 0.65, blue: 0.35)
    private let sandTop = Color(red: 0.97, green: 0.86, blue: 0.51)
    private let sandHi = Color(red: 0.98, green: 0.91, blue: 0.61)

    var body: some View {
        ZStack {
            // حلقات الماي
            Ellipse().fill(Color(red: 0.42, green: 0.60, blue: 0.60))
                .frame(width: 340, height: 84).offset(y: 16)
            Ellipse().fill(Color(red: 0.55, green: 0.72, blue: 0.68))
                .frame(width: 316, height: 72).offset(y: 15)
                .scaleEffect(pulse ? 1.03 : 1)
            Ellipse().fill(Color(red: 0.70, green: 0.78, blue: 0.75))
                .frame(width: 296, height: 64).offset(y: 14)

            // موج صغير
            WaveLine().stroke(Color(red: 0.66, green: 0.81, blue: 0.78),
                              style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: 40, height: 8).offset(x: -140, y: 52)
            WaveLine().stroke(Color(red: 0.66, green: 0.81, blue: 0.78),
                              style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: 40, height: 8).offset(x: 125, y: 56)

            // الرمل (أسطوانة)
            Ellipse().fill(sandSide).frame(width: 280, height: 56).offset(y: 16)
            Rectangle().fill(sandSide).frame(width: 280, height: 16).offset(y: 8)
            Ellipse().fill(sandTop).frame(width: 280, height: 56)
            Ellipse().fill(sandHi).frame(width: 220, height: 38).offset(y: -1)

            // تفاصيل صغيرة
            Ellipse().fill(Color(red: 0.72, green: 0.60, blue: 0.35))
                .frame(width: 16, height: 7).offset(x: -55, y: 14)
            Ellipse().fill(Color(red: 0.95, green: 0.72, blue: 0.64))
                .frame(width: 11, height: 7).offset(x: 95, y: 14)
            GrassTuft().fill(Color(red: 0.31, green: 0.64, blue: 0.37))
                .frame(width: 16, height: 12).offset(x: -25, y: 8)

            // النخلة
            ChallengePalmTree()
                .scaleEffect(1.3, anchor: UnitPoint(x: 45.0 / 120.0, y: 100.0 / 110.0))
                .offset(x: -112, y: -43)   // النخلة على طرف الجزيرة عشان الصندوق يكون بالنص
        }
        .frame(width: 340, height: 150)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
}

struct ChallengePalmTree: View {
    private func leaf(_ c1: CGPoint, _ tip: CGPoint, _ c2: CGPoint, _ color: Color) -> some View {
        Path { p in
            p.move(to: CGPoint(x: 57, y: 46))
            p.addQuadCurve(to: tip, control: c1)
            p.addQuadCurve(to: CGPoint(x: 57, y: 46), control: c2)
        }
        .fill(color)
    }

    var body: some View {
        ZStack {
            Path { p in
                p.move(to: CGPoint(x: 45, y: 100))
                p.addQuadCurve(to: CGPoint(x: 57, y: 46), control: CGPoint(x: 37, y: 72))
            }
            .stroke(Color(red: 0.48, green: 0.32, blue: 0.19),
                    style: StrokeStyle(lineWidth: 7, lineCap: .round))

            leaf(CGPoint(x: 33, y: 24), CGPoint(x: 7, y: 44),  CGPoint(x: 33, y: 38),
                 Color(red: 0.18, green: 0.55, blue: 0.34))
            leaf(CGPoint(x: 39, y: 52), CGPoint(x: 15, y: 66), CGPoint(x: 41, y: 60),
                 Color(red: 0.14, green: 0.46, blue: 0.28))
            leaf(CGPoint(x: 81, y: 22), CGPoint(x: 107, y: 42), CGPoint(x: 81, y: 36),
                 Color(red: 0.25, green: 0.65, blue: 0.40))
            leaf(CGPoint(x: 75, y: 54), CGPoint(x: 97, y: 66), CGPoint(x: 73, y: 60),
                 Color(red: 0.18, green: 0.55, blue: 0.34))
            leaf(CGPoint(x: 51, y: 20), CGPoint(x: 65, y: 14), CGPoint(x: 61, y: 32),
                 Color(red: 0.25, green: 0.65, blue: 0.40))

            Circle().fill(Color(red: 0.35, green: 0.23, blue: 0.12))
                .frame(width: 6, height: 6).position(x: 55, y: 50)
            Circle().fill(Color(red: 0.35, green: 0.23, blue: 0.12))
                .frame(width: 6, height: 6).position(x: 61, y: 51)
        }
        .frame(width: 120, height: 110)
    }
}

struct GrassTuft: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.width * 0.15, y: r.minY))
        p.addLine(to: CGPoint(x: r.width * 0.35, y: r.height * 0.55))
        p.addLine(to: CGPoint(x: r.width * 0.50, y: r.minY))
        p.addLine(to: CGPoint(x: r.width * 0.65, y: r.height * 0.55))
        p.addLine(to: CGPoint(x: r.width * 0.85, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

struct WaveLine: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.midY))
        p.addQuadCurve(to: CGPoint(x: r.midX, y: r.midY), control: CGPoint(x: r.width * 0.25, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.midY), control: CGPoint(x: r.width * 0.75, y: r.maxY))
        return p
    }
}

// MARK: - Clouds (متحركة)

struct CloudsView: View {
    var body: some View {
        GeometryReader { g in
            AnimatedCloud(width: 130, drift: 30, duration: 7).position(x: 30, y: 130)
            AnimatedCloud(width: 110, drift: 35, duration: 9).position(x: g.size.width - 30, y: 110)
            AnimatedCloud(width: 90, drift: 25, duration: 6).position(x: g.size.width / 2, y: 40)
            AnimatedCloud(width: 100, drift: 32, duration: 8).position(x: 25, y: g.size.height * 0.5)
            AnimatedCloud(width: 100, drift: 28, duration: 10).position(x: g.size.width - 20, y: g.size.height * 0.55)
        }
        .allowsHitTesting(false)
    }
}

struct AnimatedCloud: View {
    let width: CGFloat
    let drift: CGFloat      // قد إيش تتحرك يمين ويسار
    let duration: Double    // سرعة الحركة (رقم أكبر = أبطأ)

    @State private var moved = false

    var body: some View {
        ZStack {
            Ellipse().frame(width: width, height: width * 0.38)
            Circle().frame(width: width * 0.42).offset(x: -width * 0.1, y: -width * 0.12)
            Circle().frame(width: width * 0.3).offset(x: width * 0.14, y: -width * 0.1)
        }
        .foregroundColor(.white)
        .offset(x: moved ? drift : -drift)
        .animation(.easeInOut(duration: duration).repeatForever(autoreverses: true), value: moved)
        .onAppear { moved = true }
    }
}

// MARK: - Buttons

struct RoundIconButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 66, height: 66)
                .background(
                    Circle().fill(
                        RadialGradient(colors: [Color(red: 0.88, green: 0.62, blue: 0.52),
                                                Color(red: 0.55, green: 0.33, blue: 0.25)],
                                       center: .topLeading, startRadius: 2, endRadius: 70)
                    )
                )
                .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 2))
                .shadow(color: .black.opacity(0.25), radius: 4, y: 3)
        }
    }
}

#Preview {
    ChallengeView()
}
