//
//  AvatarCustomizerView.swift
//  Hor
//
//  Created by HANAN ABDALLAH on 15/05/1448 AH.
//

import SwiftUI
import Combine

// ملاحظة: هذا الملف يعتمد على أشياء موجودة في IslandsMapView.swift:
//   Color(hex:)  ،  PalmTree  ،  TreasureChest
// تأكد أن الملفين داخل نفس المشروع (Target).

// MARK: - Data

enum AvatarHairStyle { case long, curly, ponytail, bob, short, bun, pigtails, wavy, spaceBuns, longCurly }
enum AvatarTopKind { case tee, longSleeve, dress, scrubs }
enum AvatarBottomKind { case pants, skirt, shorts }
enum AvatarGender: Hashable { case boy, girl }

/// رقم لبس المستشفى (مجاني ومملوك من البداية)
let avatarHospitalID = 5

struct AvatarHairOption: Identifiable {
    let id: Int
    let style: AvatarHairStyle
    let color: Color
}

struct AvatarTopOption: Identifiable {
    let id: Int
    let kind: AvatarTopKind
    let color: Color
}

struct AvatarBottomOption: Identifiable {
    let id: Int
    let kind: AvatarBottomKind
    let color: Color
}

struct AvatarSelection: Equatable {
    var hair: Int
    var skin: Int
    var top: Int
    var bottom: Int
    var gender: AvatarGender = .girl
    var hairColor: Int = 0
}

let avatarHairOptions: [AvatarHairOption] = [
    .init(id: 0, style: .long,     color: Color(hex: 0x5A3A2B)),
    .init(id: 1, style: .curly,    color: Color(hex: 0x2D2A2B)),
    .init(id: 2, style: .ponytail, color: Color(hex: 0xE2A93F)),
    .init(id: 3, style: .bob,      color: Color(hex: 0xB4503D)),
    .init(id: 4, style: .long,     color: Color(hex: 0x7A4FA3)),
    // أشكال شعر إضافية (اللون يُحدَّد من صف Hair color)
    .init(id: 5, style: .short,     color: Color(hex: 0x5A3A2B)),
    .init(id: 6, style: .bun,       color: Color(hex: 0x5A3A2B)),
    .init(id: 7, style: .pigtails,  color: Color(hex: 0x5A3A2B)),
    .init(id: 8, style: .wavy,      color: Color(hex: 0x5A3A2B)),
    .init(id: 9, style: .spaceBuns, color: Color(hex: 0x5A3A2B)),
    .init(id: 10, style: .longCurly, color: Color(hex: 0x5A3A2B))
]

let avatarSkinTones: [Color] = [
    Color(hex: 0xF6DEC9),
    Color(hex: 0xEFCBA9),
    Color(hex: 0xDDA880),
    Color(hex: 0xC48760),
    Color(hex: 0x96603C),
    Color(hex: 0x6B4129)
]

/// ألوان الشعر القابلة للاختيار
let avatarHairColors: [Color] = [
    Color(hex: 0x5A3A2B),   // بني غامق
    Color(hex: 0x2D2A2B),   // أسود
    Color(hex: 0x8B5E3C),   // بني فاتح
    Color(hex: 0xE2A93F),   // أشقر
    Color(hex: 0xEADFC4),   // بلاتيني
    Color(hex: 0xD9742F),   // زنجبيلي
    Color(hex: 0xB4503D),   // أحمر
    Color(hex: 0xA8A8A8),   // رمادي
    Color(hex: 0x7A4FA3),   // بنفسجي
    Color(hex: 0x4F7FD1),   // أزرق
    Color(hex: 0xE88AB4),   // وردي
    Color(hex: 0x5FAE7A)    // أخضر
]

let avatarTopOptions: [AvatarTopOption] = [
    .init(id: 0, kind: .tee,        color: Color(hex: 0xE9B9A3)),
    .init(id: 1, kind: .longSleeve, color: Color(hex: 0x9DB8A8)),
    .init(id: 2, kind: .longSleeve, color: Color(hex: 0xC8BDEB)),
    .init(id: 3, kind: .dress,      color: Color(hex: 0xE49FB5)),
    .init(id: 4, kind: .tee,        color: Color(hex: 0x8FB7E4)),
    // لبس المستشفى (مجاني)
    .init(id: 5, kind: .scrubs,     color: Color(hex: 0x6FC3C3))
]

let avatarBottomOptions: [AvatarBottomOption] = [
    .init(id: 0, kind: .pants,  color: Color(hex: 0x6F8BDA)),
    .init(id: 1, kind: .skirt,  color: Color(hex: 0xE0997F)),
    .init(id: 2, kind: .shorts, color: Color(hex: 0xB1C4E8)),
    .init(id: 3, kind: .pants,  color: Color(hex: 0x98A062)),
    .init(id: 4, kind: .pants,  color: Color(hex: 0x3F5A92)),
    // بنطلون المستشفى (مجاني)
    .init(id: 5, kind: .pants,  color: Color(hex: 0x6FC3C3))
]

// MARK: - Prices & wardrobe (النقاط والمشتريات)

/// أسعار الملابس بالنقاط (لبس المستشفى مجاني)
let avatarTopPrices: [Int: Int]    = [0: 10, 1: 15, 2: 15, 3: 25, 4: 10]
let avatarBottomPrices: [Int: Int] = [0: 10, 1: 15, 2: 10, 3: 15, 4: 20]

/// يحفظ النقاط والملابس المشتراة (UserDefaults).
/// لإضافة نقاط من أي صفحة:  AvatarWardrobe.shared.addPoints(10)
final class AvatarWardrobe: ObservableObject {
    static let shared = AvatarWardrobe()

    @Published var points: Int {
        didSet { UserDefaults.standard.set(points, forKey: "playerPoints") }
    }
    @Published private(set) var ownedTops: Set<Int> {
        didSet { UserDefaults.standard.set(Array(ownedTops), forKey: "ownedTops") }
    }
    @Published private(set) var ownedBottoms: Set<Int> {
        didSet { UserDefaults.standard.set(Array(ownedBottoms), forKey: "ownedBottoms") }
    }

    private init() {
        let d = UserDefaults.standard
        points = d.object(forKey: "playerPoints") as? Int ?? 5
        ownedTops = Set(d.array(forKey: "ownedTops") as? [Int] ?? []).union([avatarHospitalID])
        ownedBottoms = Set(d.array(forKey: "ownedBottoms") as? [Int] ?? []).union([avatarHospitalID])
    }

    func ownsTop(_ id: Int) -> Bool { ownedTops.contains(id) }
    func ownsBottom(_ id: Int) -> Bool { ownedBottoms.contains(id) }

    func addPoints(_ amount: Int) { points += amount }

    @discardableResult
    func buyTop(_ id: Int, price: Int) -> Bool {
        guard !ownedTops.contains(id), points >= price else { return false }
        points -= price
        ownedTops.insert(id)
        return true
    }

    @discardableResult
    func buyBottom(_ id: Int, price: Int) -> Bool {
        guard !ownedBottoms.contains(id), points >= price else { return false }
        points -= price
        ownedBottoms.insert(id)
        return true
    }
}

enum AvatarShopAlert {
    case confirm(isTop: Bool, id: Int, price: Int)
    case notEnough(price: Int)
}

// MARK: - Helpers

fileprivate extension View {
    /// يضع العنصر بإحداثيات التصميم (عرض 512) ويكبّره/يصغّره حسب الشاشة
    func placed(x: CGFloat, y: CGFloat, scale s: CGFloat) -> some View {
        self.scaleEffect(s).position(x: x * s, y: y * s)
    }
}

fileprivate func filled<S: Shape>(_ shape: S,
                                  color: Color,
                                  line: Color = Color.black.opacity(0.14),
                                  width: CGFloat = 1) -> some View {
    ZStack {
        shape.fill(color)
        shape.stroke(line, style: StrokeStyle(lineWidth: width, lineJoin: .round))
    }
}

// MARK: - Shapes (ملابس)

struct AvatarTopShape: Shape {
    let kind: AvatarTopKind

    func path(in rect: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }
        var path = Path()
        var pts: [(CGFloat, CGFloat)] = []

        switch kind {
        case .tee:
            path.move(to: p(0.34, 0.02))
            path.addQuadCurve(to: p(0.66, 0.02), control: p(0.5, 0.13))
            pts = [(0.98, 0.20), (1.0, 0.40), (0.80, 0.47), (0.80, 1.0),
                   (0.20, 1.0), (0.20, 0.47), (0.0, 0.40), (0.02, 0.20)]
        case .longSleeve:
            path.move(to: p(0.34, 0.02))
            path.addQuadCurve(to: p(0.66, 0.02), control: p(0.5, 0.13))
            pts = [(0.98, 0.16), (1.0, 0.74), (0.86, 0.76), (0.80, 0.42), (0.80, 1.0),
                   (0.20, 1.0), (0.20, 0.42), (0.14, 0.76), (0.0, 0.74), (0.02, 0.16)]
        case .scrubs:
            path.move(to: p(0.34, 0.02))
            path.addLine(to: p(0.50, 0.22))
            path.addLine(to: p(0.66, 0.02))
            pts = [(0.98, 0.20), (1.0, 0.40), (0.80, 0.47), (0.80, 1.0),
                   (0.20, 1.0), (0.20, 0.47), (0.0, 0.40), (0.02, 0.20)]
        case .dress:
            path.move(to: p(0.33, 0.0))
            path.addLine(to: p(0.43, 0.0))
            path.addQuadCurve(to: p(0.57, 0.0), control: p(0.5, 0.14))
            pts = [(0.67, 0.0), (0.80, 0.22), (0.80, 0.42), (0.97, 1.0),
                   (0.03, 1.0), (0.20, 0.42), (0.20, 0.22)]
        }

        for pt in pts { path.addLine(to: p(pt.0, pt.1)) }
        path.closeSubpath()
        return path
    }
}

struct AvatarBottomShape: Shape {
    let kind: AvatarBottomKind

    func path(in rect: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }
        let pts: [(CGFloat, CGFloat)]
        switch kind {
        case .pants:
            pts = [(0.08, 0), (0.92, 0), (0.97, 1), (0.56, 1), (0.50, 0.30), (0.44, 1), (0.03, 1)]
        case .shorts:
            pts = [(0.08, 0), (0.92, 0), (0.97, 1), (0.56, 1), (0.50, 0.35), (0.44, 1), (0.03, 1)]
        case .skirt:
            pts = [(0.18, 0), (0.82, 0), (1.0, 1), (0.0, 1)]
        }
        var path = Path()
        path.move(to: p(pts[0].0, pts[0].1))
        for pt in pts.dropFirst() { path.addLine(to: p(pt.0, pt.1)) }
        path.closeSubpath()
        return path
    }
}

/// غُرّة الشعر (إحداثيات مطلقة داخل لوحة الشخصية 260 × 480)
struct AvatarFringeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 42, y: 108))
        p.addCurve(to: CGPoint(x: 218, y: 108),
                   control1: CGPoint(x: 38, y: -45),
                   control2: CGPoint(x: 222, y: -45))
        p.addCurve(to: CGPoint(x: 42, y: 108),
                   control1: CGPoint(x: 200, y: 60),
                   control2: CGPoint(x: 70, y: 95))
        p.closeSubpath()
        return p
    }
}

/// شعر قصير (إحداثيات مطلقة داخل لوحة الشخصية 260 × 480)
struct AvatarShortFringeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 40, y: 122))
        p.addCurve(to: CGPoint(x: 220, y: 122),
                   control1: CGPoint(x: 30, y: -40),
                   control2: CGPoint(x: 230, y: -40))
        p.addLine(to: CGPoint(x: 205, y: 100))
        p.addCurve(to: CGPoint(x: 55, y: 100),
                   control1: CGPoint(x: 190, y: 55),
                   control2: CGPoint(x: 80, y: 80))
        p.closeSubpath()
        return p
    }
}

// MARK: - Avatar pieces (لوحة 260 × 480)

struct AvatarHairBack: View {
    let option: AvatarHairOption

    var body: some View {
        ZStack {
            switch option.style {
            case .long:
                UnevenRoundedRectangle(topLeadingRadius: 92, bottomLeadingRadius: 22,
                                       bottomTrailingRadius: 22, topTrailingRadius: 92,
                                       style: .continuous)
                    .fill(option.color)
                    .frame(width: 204, height: 262)
                    .position(x: 130, y: 131)
            case .bob:
                UnevenRoundedRectangle(topLeadingRadius: 88, bottomLeadingRadius: 38,
                                       bottomTrailingRadius: 38, topTrailingRadius: 88,
                                       style: .continuous)
                    .fill(option.color)
                    .frame(width: 198, height: 176)
                    .position(x: 130, y: 90)
            case .ponytail:
                Ellipse()
                    .fill(option.color)
                    .frame(width: 186, height: 200)
                    .position(x: 130, y: 100)
                Capsule()
                    .fill(option.color)
                    .frame(width: 38, height: 110)
                    .rotationEffect(.degrees(-18))
                    .position(x: 228, y: 130)
            case .short:
                Ellipse()
                    .fill(option.color)
                    .frame(width: 182, height: 194)
                    .position(x: 130, y: 100)
            case .bun:
                Ellipse()
                    .fill(option.color)
                    .frame(width: 186, height: 198)
                    .position(x: 130, y: 100)
                Circle()
                    .fill(option.color)
                    .frame(width: 56, height: 56)
                    .position(x: 130, y: 2)
            case .pigtails:
                Ellipse()
                    .fill(option.color)
                    .frame(width: 186, height: 198)
                    .position(x: 130, y: 100)
                Capsule()
                    .fill(option.color)
                    .frame(width: 40, height: 110)
                    .rotationEffect(.degrees(20))
                    .position(x: 30, y: 155)
                Capsule()
                    .fill(option.color)
                    .frame(width: 40, height: 110)
                    .rotationEffect(.degrees(-20))
                    .position(x: 230, y: 155)
            case .wavy:
                UnevenRoundedRectangle(topLeadingRadius: 92, bottomLeadingRadius: 22,
                                       bottomTrailingRadius: 22, topTrailingRadius: 92,
                                       style: .continuous)
                    .fill(option.color)
                    .frame(width: 204, height: 250)
                    .position(x: 130, y: 125)
                ForEach([50.0, 90.0, 130.0, 170.0, 210.0], id: \.self) { x in
                    Circle()
                        .fill(option.color)
                        .frame(width: 34, height: 34)
                        .position(x: CGFloat(x), y: 252)
                }
            case .spaceBuns:
                Ellipse()
                    .fill(option.color)
                    .frame(width: 186, height: 198)
                    .position(x: 130, y: 100)
                Circle()
                    .fill(option.color)
                    .frame(width: 52, height: 52)
                    .position(x: 62, y: 8)
                Circle()
                    .fill(option.color)
                    .frame(width: 52, height: 52)
                    .position(x: 198, y: 8)
            case .longCurly:
                UnevenRoundedRectangle(topLeadingRadius: 90, bottomLeadingRadius: 40,
                                       bottomTrailingRadius: 40, topTrailingRadius: 90,
                                       style: .continuous)
                    .fill(option.color)
                    .frame(width: 200, height: 232)
                    .position(x: 130, y: 118)
                ForEach(Array(stride(from: -200.0, through: 20.0, by: 20.0)), id: \.self) { a in
                    let r = a * .pi / 180
                    Circle()
                        .fill(option.color)
                        .frame(width: 48, height: 48)
                        .position(x: 130 + 95 * CGFloat(cos(r)),
                                  y: 105 + 105 * CGFloat(sin(r)))
                }
                ForEach(0..<5, id: \.self) { i in
                    Circle()
                        .fill(option.color)
                        .frame(width: 46, height: 46)
                        .position(x: 36 + CGFloat(i % 2) * 8, y: 150 + CGFloat(i) * 26)
                    Circle()
                        .fill(option.color)
                        .frame(width: 46, height: 46)
                        .position(x: 224 - CGFloat(i % 2) * 8, y: 150 + CGFloat(i) * 26)
                }
            case .curly:
                Ellipse()
                    .fill(option.color)
                    .frame(width: 190, height: 200)
                    .position(x: 130, y: 105)
                ForEach(Array(stride(from: -200.0, through: 20.0, by: 20.0)), id: \.self) { a in
                    let r = a * .pi / 180
                    Circle()
                        .fill(option.color)
                        .frame(width: 48, height: 48)
                        .position(x: 130 + 95 * CGFloat(cos(r)),
                                  y: 105 + 105 * CGFloat(sin(r)))
                }
            }
        }
        .frame(width: 260, height: 480)
    }
}

struct AvatarHairFront: View {
    let option: AvatarHairOption

    var body: some View {
        ZStack {
            if option.style == .curly || option.style == .longCurly {
                ForEach(Array(zip([78.0, 104.0, 130.0, 156.0, 182.0], [22.0, 14.0, 10.0, 14.0, 22.0])), id: \.0) { pair in
                    Circle()
                        .fill(option.color)
                        .frame(width: 44, height: 44)
                        .position(x: CGFloat(pair.0), y: CGFloat(pair.1))
                }
            } else if option.style == .short {
                AvatarShortFringeShape()
                    .fill(option.color)
            } else {
                AvatarFringeShape()
                    .fill(option.color)
            }
        }
        .frame(width: 260, height: 480)
    }
}

struct AvatarFace: View {
    let skin: Color
    var gender: AvatarGender = .girl

    var body: some View {
        ZStack {
            // Ears
            ForEach([42.0, 218.0], id: \.self) { x in
                Circle()
                    .fill(skin)
                    .overlay(Circle().fill(Color.black.opacity(0.06)))
                    .frame(width: 32, height: 32)
                    .position(x: CGFloat(x), y: 116)
            }

            // Face
            Ellipse()
                .fill(skin)
                .frame(width: 170, height: 185)
                .position(x: 130, y: 105)

            // Cheeks
            ForEach([80.0, 182.0], id: \.self) { x in
                Ellipse()
                    .fill(Color(hex: 0xE88F8A).opacity(0.5))
                    .frame(width: 30, height: 20)
                    .position(x: CGFloat(x), y: 152)
            }

            // Eyes
            ForEach([102.0, 160.0], id: \.self) { x in
                ZStack {
                    Ellipse().fill(Color(hex: 0x2B2B3A))
                        .frame(width: 13, height: 19)
                    Circle().fill(Color.white.opacity(0.85))
                        .frame(width: 4, height: 4)
                        .offset(x: 2, y: -4)
                }
                .position(x: CGFloat(x), y: 125)
            }

            // Eyelashes (girl)
            if gender == .girl {
                Path { p in
                    p.move(to: CGPoint(x: 95, y: 118)); p.addLine(to: CGPoint(x: 89, y: 113))
                    p.move(to: CGPoint(x: 97, y: 115)); p.addLine(to: CGPoint(x: 93, y: 109))
                    p.move(to: CGPoint(x: 167, y: 118)); p.addLine(to: CGPoint(x: 173, y: 113))
                    p.move(to: CGPoint(x: 165, y: 115)); p.addLine(to: CGPoint(x: 169, y: 109))
                }
                .stroke(Color(hex: 0x2B2B3A), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            }

            // Eyebrows
            Path { p in
                p.move(to: CGPoint(x: 86, y: 106))
                p.addQuadCurve(to: CGPoint(x: 120, y: 104), control: CGPoint(x: 103, y: 94))
                p.move(to: CGPoint(x: 142, y: 104))
                p.addQuadCurve(to: CGPoint(x: 176, y: 106), control: CGPoint(x: 159, y: 94))
            }
            .stroke(Color(hex: 0x4B2E22), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))

            // Nose
            Path { p in
                p.move(to: CGPoint(x: 124, y: 148))
                p.addQuadCurve(to: CGPoint(x: 136, y: 148), control: CGPoint(x: 130, y: 157))
            }
            .stroke(Color(hex: 0xB98260).opacity(0.8), style: StrokeStyle(lineWidth: 2, lineCap: .round))

            // Smile
            Path { p in
                p.move(to: CGPoint(x: 112, y: 164))
                p.addQuadCurve(to: CGPoint(x: 152, y: 164), control: CGPoint(x: 132, y: 183))
            }
            .stroke(Color(hex: 0x8A3E3A), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
        }
        .frame(width: 260, height: 480)
    }
}

// MARK: - Full avatar

struct AvatarView: View {
    let skin: Color
    let hair: AvatarHairOption
    let top: AvatarTopOption
    let bottom: AvatarBottomOption
    var gender: AvatarGender = .girl

    var body: some View {
        ZStack {
            AvatarHairBack(option: hair)

            // Legs
            ForEach([101.0, 160.0], id: \.self) { x in
                Capsule()
                    .fill(skin)
                    .frame(width: 34, height: 100)
                    .position(x: CGFloat(x), y: 410)
            }

            bottomLayer

            // Shoes
            ForEach([100.0, 160.0], id: \.self) { x in
                Ellipse()
                    .fill(Color(hex: 0xF6F2E6))
                    .frame(width: 68, height: 30)
                    .overlay(
                        VStack(spacing: 4) {
                            Capsule().fill(Color(hex: 0xC4A765)).frame(width: 24, height: 2.5)
                            Capsule().fill(Color(hex: 0xC4A765)).frame(width: 24, height: 2.5)
                        }
                    )
                    .shadow(color: .black.opacity(0.12), radius: 2, y: 2)
                    .position(x: CGFloat(x), y: 454)
            }

            // Torso (skin) + arms
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(skin)
                .frame(width: 115, height: 150)
                .position(x: 130, y: 282)

            ForEach([52.0, 208.0], id: \.self) { x in
                Capsule()
                    .fill(skin)
                    .frame(width: 30, height: 100)
                    .position(x: CGFloat(x), y: 300)
            }

            topLayer

            // Hands
            ForEach([52.0, 208.0], id: \.self) { x in
                Circle()
                    .fill(skin)
                    .frame(width: 32, height: 32)
                    .position(x: CGFloat(x), y: 347)
            }

            // Neck
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(skin)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.black.opacity(0.07)))
                .frame(width: 52, height: 56)
                .position(x: 130, y: 198)

            AvatarFace(skin: skin, gender: gender)
            AvatarHairFront(option: hair)
        }
        .frame(width: 260, height: 480)
    }

    @ViewBuilder
    private var topLayer: some View {
        switch top.kind {
        case .tee, .longSleeve:
            filled(AvatarTopShape(kind: top.kind), color: top.color)
                .frame(width: 190, height: 150)
                .position(x: 130, y: 283)
        case .scrubs:
            ZStack {
                filled(AvatarTopShape(kind: .scrubs), color: top.color)
                    .frame(width: 190, height: 150)
                    .position(x: 130, y: 283)
                // جيب
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Color.black.opacity(0.18), lineWidth: 1.5)
                    .frame(width: 24, height: 20)
                    .position(x: 158, y: 292)
                // صليب طبي
                ZStack {
                    Capsule().frame(width: 5, height: 15)
                    Capsule().frame(width: 15, height: 5)
                }
                .foregroundColor(.white)
                .position(x: 104, y: 270)
            }
        case .dress:
            filled(AvatarTopShape(kind: .dress), color: top.color)
                .frame(width: 190, height: 225)
                .position(x: 130, y: 320)
        }
    }

    @ViewBuilder
    private var bottomLayer: some View {
        switch bottom.kind {
        case .pants:
            filled(AvatarBottomShape(kind: .pants), color: bottom.color)
                .frame(width: 117, height: 100)
                .position(x: 130, y: 400)
        case .shorts:
            filled(AvatarBottomShape(kind: .shorts), color: bottom.color)
                .frame(width: 117, height: 50)
                .position(x: 130, y: 373)
        case .skirt:
            filled(AvatarBottomShape(kind: .skirt), color: bottom.color)
                .frame(width: 150, height: 72)
                .position(x: 130, y: 384)
        }
    }
}

// MARK: - Icons for the option tiles

private let iconLine = Color(hex: 0x3E5B5C)

struct AvatarHeadIcon: View {
    let skin: Color
    let hair: AvatarHairOption
    var gender: AvatarGender = .girl

    var body: some View {
        ZStack {
            AvatarHairBack(option: hair)
            AvatarFace(skin: skin, gender: gender)
            AvatarHairFront(option: hair)
        }
        .frame(width: 260, height: 480)
        .frame(width: 260, height: 270, alignment: .top)
        .offset(y: 8)
        .scaleEffect(0.25)
        .frame(width: 70, height: 68)
    }
}

struct AvatarTopIcon: View {
    let option: AvatarTopOption

    var body: some View {
        let shape = AvatarTopShape(kind: option.kind)
        ZStack {
            shape.fill(option.color)
            shape.stroke(iconLine, style: StrokeStyle(lineWidth: 1.6, lineJoin: .round))
            if option.kind == .scrubs {
                ZStack {
                    Capsule().frame(width: 4, height: 12)
                    Capsule().frame(width: 12, height: 4)
                }
                .foregroundColor(.white)
                .offset(x: -10, y: 2)
            }
        }
        .frame(width: option.kind == .dress ? 50 : 62,
               height: option.kind == .dress ? 60 : 54)
    }
}

struct AvatarBottomIcon: View {
    let option: AvatarBottomOption

    var body: some View {
        let shape = AvatarBottomShape(kind: option.kind)
        ZStack {
            shape.fill(option.color)
            shape.stroke(iconLine, style: StrokeStyle(lineWidth: 1.6, lineJoin: .round))
        }
        .frame(width: size.width, height: size.height)
    }

    private var size: CGSize {
        switch option.kind {
        case .pants:  return CGSize(width: 40, height: 58)
        case .skirt:  return CGSize(width: 58, height: 50)
        case .shorts: return CGSize(width: 48, height: 40)
        }
    }
}

// MARK: - UI components

struct AvatarCheckBadge: View {
    var body: some View {
        ZStack {
            Circle().fill(Color(hex: 0xE7B845))
            Circle().stroke(Color(hex: 0xA9822F), lineWidth: 2)
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .heavy))
                .foregroundColor(Color(hex: 0x4A3B2A))
        }
        .frame(width: 22, height: 22)
    }
}

struct AvatarOptionTile<Icon: View>: View {
    let isSelected: Bool
    let icon: Icon

    init(isSelected: Bool, @ViewBuilder icon: () -> Icon) {
        self.isSelected = isSelected
        self.icon = icon()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)

        ZStack {
            shape.fill(
                isSelected
                ? AnyShapeStyle(Color(hex: 0xF7EDCB))
                : AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xEAF1ED), Color(hex: 0xD3DDD8)],
                                               startPoint: .top, endPoint: .bottom))
            )
            icon
        }
        .frame(width: 94, height: 80)
        .overlay(
            shape.stroke(isSelected ? Color(hex: 0xD9A93A) : Color.white.opacity(0.35),
                         lineWidth: isSelected ? 4 : 1)
        )
        .background(
            shape
                .fill(isSelected ? Color(hex: 0xB98A2E) : Color(hex: 0x262726))
                .offset(y: 5)
        )
        .overlay(alignment: .topTrailing) {
            if isSelected {
                AvatarCheckBadge().offset(x: 2, y: -10)
            }
        }
    }
}

struct AvatarSkinSwatch: View {
    let color: Color
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle().fill(color)
                .frame(width: 50, height: 50)
            Circle().stroke(Color(hex: 0xEADFB8), lineWidth: 3)
                .frame(width: 50, height: 50)
            if isSelected {
                Circle().stroke(Color(hex: 0xD9A93A), lineWidth: 5)
                    .frame(width: 58, height: 58)
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(hex: 0x4A3B2A))
            }
        }
        .frame(width: 50, height: 50)
    }
}

struct AvatarColorSwatch: View {
    let color: Color
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle().fill(color)
                .frame(width: 50, height: 50)
            Circle().stroke(Color(hex: 0xEADFB8), lineWidth: 3)
                .frame(width: 50, height: 50)
            if isSelected {
                Circle().stroke(Color(hex: 0xD9A93A), lineWidth: 5)
                    .frame(width: 58, height: 58)
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.45), radius: 1.5)
            }
        }
        .frame(width: 50, height: 50)
    }
}

struct AvatarGenderIcon: View {
    let gender: AvatarGender
    let skin: Color
    let hairColor: Color

    var body: some View {
        VStack(spacing: 0) {
            AvatarHeadIcon(skin: skin,
                           hair: AvatarHairOption(id: -1,
                                                  style: gender == .boy ? .short : .long,
                                                  color: hairColor),
                           gender: gender)
                .scaleEffect(0.72)
                .frame(width: 52, height: 50)
            Text(gender == .boy ? "Boy" : "Girl")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(Color(hex: 0x3E5B5C))
        }
    }
}

struct AvatarLockedOverlay: View {
    let price: Int

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.42))
            VStack(spacing: 4) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                HStack(spacing: 4) {
                    ZStack {
                        Circle().fill(Color(hex: 0xF5C14B))
                        Image(systemName: "star.fill")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(Color(hex: 0x6B4A1A))
                    }
                    .frame(width: 15, height: 15)
                    Text("\(price)")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.black.opacity(0.45)))
            }
        }
        .frame(width: 94, height: 80)
        .allowsHitTesting(false)
    }
}

struct AvatarPointsPill: View {
    let points: Int

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle().fill(Color(hex: 0xF5C14B))
                Image(systemName: "star.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(hex: 0x6B4A1A))
            }
            .frame(width: 26, height: 26)
            Text("\(points)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: 0xF5C14B))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color(hex: 0x6B4A35))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color(hex: 0x9A7658), lineWidth: 3))
    }
}

struct AvatarCircleButton: View {
    let systemName: String
    var size: CGFloat = 58
    var isPrimary: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(
                    isPrimary
                    ? AnyShapeStyle(Color(hex: 0xF2C54E))
                    : AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xF8EFD2), Color(hex: 0xE6D6A5)],
                                                   startPoint: .top, endPoint: .bottom))
                )
                Circle().stroke(Color(hex: 0xA9824F), lineWidth: 4)
                Image(systemName: systemName)
                    .font(.system(size: size * 0.34, weight: .bold))
                    .foregroundColor(Color(hex: 0x4A3B2A))
            }
            .frame(width: size, height: size)
            .background(Circle().fill(Color(hex: 0x7A5A35)).offset(y: 4))
        }
        .buttonStyle(.plain)
    }
}

struct AvatarCloud: View {
    var body: some View {
        ZStack {
            Ellipse().fill(Color(hex: 0xCDD7E6))
                .frame(width: 130, height: 30)
                .position(x: 65, y: 48)
            Circle().fill(Color(hex: 0xD6DEEB))
                .frame(width: 46, height: 46)
                .position(x: 55, y: 32)
            Circle().fill(Color(hex: 0xDCE3EE))
                .frame(width: 34, height: 34)
                .position(x: 92, y: 36)
        }
        .frame(width: 140, height: 70)
    }
}

// MARK: - Main screen

struct AvatarCustomizerView: View {
    var onBack: () -> Void = {}
    var onConfirm: (AvatarSelection) -> Void = { _ in }

    @State private var hairIndex = 0
    @State private var hairColorIndex = 0
    @State private var skinIndex = 1
    @State private var topIndex = avatarHospitalID
    @State private var bottomIndex = avatarHospitalID
    @State private var gender: AvatarGender = .girl
    @State private var shopAlert: AvatarShopAlert?
    @ObservedObject private var wardrobe = AvatarWardrobe.shared
    @State private var isFlipped = false

    var body: some View {
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let s = w / 512                     // مقياس التصميم (التصميم بعرض 512)
                let panelTop: CGFloat = 609 * s     // تم تصحيح الخطأ المطبعي هنا لضبط مكان اللوحة
                let panelHeight = max(h - panelTop, 0)

                ZStack {
                    background(s: s)

                    // Clouds
                    AvatarCloud().placed(x: 78, y: 141, scale: s)
                    AvatarCloud().placed(x: 455, y: 214, scale: s * 1.05)

                    // Island
                    island(s: s)

                    // Avatar
                    AvatarView(skin: avatarSkinTones[skinIndex],
                               hair: styledHair(avatarHairOptions[hairIndex]),
                               top: avatarTopOptions[topIndex],
                               bottom: avatarBottomOptions[bottomIndex],
                               gender: gender)
                        .scaleEffect(x: isFlipped ? -s : s, y: s)
                        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: isFlipped)
                        .position(x: 254 * s, y: 334 * s) // ضبط إحداثيات مركز الشخصية بدقة

                    // Top buttons
                    AvatarCircleButton(systemName: "chevron.left", action: onBack)
                        .placed(x: 54, y: 99, scale: s)
                    AvatarCircleButton(systemName: "checkmark", isPrimary: true) {
                        onConfirm(AvatarSelection(hair: hairIndex, skin: skinIndex,
                                                top: topIndex, bottom: bottomIndex,
                                                gender: gender, hairColor: hairColorIndex))
                    }
                    .placed(x: 454, y: 99, scale: s)

                    // Points
                    AvatarPointsPill(points: wardrobe.points)
                        .placed(x: 72, y: 168, scale: s)

                    // Turn arrows
                    AvatarCircleButton(systemName: "chevron.left", size: 52) { isFlipped.toggle() }
                        .placed(x: 49, y: 499, scale: s)
                    AvatarCircleButton(systemName: "chevron.right", size: 52) { isFlipped.toggle() }
                        .placed(x: 461, y: 499, scale: s)

                    // Bottom panel
                    panel(width: w, height: panelHeight + 20, s: s)
                        .position(x: w / 2, y: panelTop + (panelHeight + 20) / 2)
                }
                .frame(width: w, height: h)
            }
            .ignoresSafeArea()
            .alert(shopAlertTitle, isPresented: shopAlertBinding) {
                shopAlertButtons
            } message: {
                Text(shopAlertMessage)
            }
        }

    // MARK: Background & island

    private func background(s: CGFloat) -> some View {
            func ray(_ pts: [(CGFloat, CGFloat)]) -> Path {
                Path { p in
                    p.move(to: CGPoint(x: pts[0].0 * s, y: pts[0].1 * s))
                    for pt in pts.dropFirst() { p.addLine(to: CGPoint(x: pt.0 * s, y: pt.1 * s)) }
                    p.closeSubpath()
                }
            }

            return ZStack {
                LinearGradient(colors: [Color(hex: 0xBBD1D0), Color(hex: 0x8DAEAE), Color(hex: 0x7B9E9E)],
                               startPoint: .top, endPoint: .bottom)
                ray([(110, 0), (190, 0), (330, 620), (210, 620)]).fill(Color.white.opacity(0.08))
                ray([(260, 0), (300, 0), (430, 620), (380, 620)]).fill(Color.white.opacity(0.07))
                ray([(380, 0), (470, 0), (512, 520), (470, 620)]).fill(Color.white.opacity(0.06))
            }
        }

    private func island(s: CGFloat) -> some View {
        ZStack {
            Ellipse().fill(Color.white.opacity(0.35))
                .frame(width: 322, height: 62)
                .placed(x: 254, y: 575, scale: s)
            Ellipse().fill(Color(hex: 0xAD925F))
                .frame(width: 282, height: 52)
                .placed(x: 254, y: 556, scale: s)
            Ellipse().fill(Color(hex: 0xC9A96A))
                .frame(width: 282, height: 52)
                .placed(x: 254, y: 548, scale: s)
            Ellipse().fill(Color(hex: 0xF0DC96))
                .frame(width: 282, height: 52)
                .placed(x: 254, y: 540, scale: s)
            Ellipse().fill(Color.black.opacity(0.08))
                .frame(width: 190, height: 24)
                .placed(x: 254, y: 546, scale: s)

            PalmTree()
                .frame(width: 80, height: 80)
                .placed(x: 130, y: 506, scale: s * 1.15)
            TreasureChest()
                .frame(width: 44, height: 40)
                .placed(x: 367, y: 536, scale: s * 1.1)
        }
    }

    // MARK: Panel

    private func panel(width w: CGFloat, height: CGFloat, s: CGFloat) -> some View {
        let shape = UnevenRoundedRectangle(topLeadingRadius: 42, bottomLeadingRadius: 0,
                                           bottomTrailingRadius: 0, topTrailingRadius: 42,
                                           style: .continuous)
        return ZStack(alignment: .topLeading) {
            shape.fill(Color(hex: 0x434443))
            shape.stroke(Color(hex: 0xC9A24F), lineWidth: 3)

            panelContent
                .frame(width: 512, height: max((height - 20) / s, 0), alignment: .topLeading)
                .scaleEffect(s, anchor: .topLeading)
        }
        .frame(width: w, height: height)
    }

    private var panelContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
        VStack(alignment: .leading, spacing: 0) {
            // Handle
            HStack {
                Spacer()
                Capsule().fill(Color(hex: 0x8C7A4A)).frame(width: 78, height: 6)
                Spacer()
            }
            .padding(.top, 8)

            Spacer().frame(height: 10)
            sectionHeader("Character")
            Spacer().frame(height: 7)
            genderRow

            Spacer().frame(height: 16)
            sectionHeader("Hair")
            Spacer().frame(height: 7)
            hairRow

            Spacer().frame(height: 16)
            sectionHeader("Hair color")
            Spacer().frame(height: 6)
            hairColorRow

            Spacer().frame(height: 16)
            sectionHeader("Skin tone")
            Spacer().frame(height: 6)
            skinRow

            Spacer().frame(height: 15)
            sectionHeader("Tops & dresses")
            Spacer().frame(height: 4)
            topsRow

            Spacer().frame(height: 13)
            sectionHeader("Bottoms")
            Spacer().frame(height: 7)
            bottomsRow

            Spacer().frame(height: 70)
        }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 17, weight: .regular, design: .rounded))
                .foregroundColor(Color(hex: 0xE6DDB8))
            Rectangle()
                .fill(Color(hex: 0x8A8466).opacity(0.8))
                .frame(height: 1.5)
        }
        .padding(.leading, 25)
        .padding(.trailing, 28)
        .frame(height: 22)
    }

    private var hairRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 13) {
                ForEach(visibleHairOptions) { option in
                    AvatarOptionTile(isSelected: hairIndex == option.id) {
                        AvatarHeadIcon(skin: avatarSkinTones[skinIndex], hair: styledHair(option), gender: gender)
                    }
                    .onTapGesture { hairIndex = option.id }
                }
            }
            .padding(.horizontal, 26)
        }
        .scrollClipDisabled()
        .frame(height: 80)
    }

    // MARK: Gender

    private var genderRow: some View {
        HStack(spacing: 13) {
            ForEach([AvatarGender.boy, AvatarGender.girl], id: \.self) { g in
                AvatarOptionTile(isSelected: gender == g) {
                    AvatarGenderIcon(gender: g,
                                     skin: avatarSkinTones[skinIndex],
                                     hairColor: avatarHairColors[hairColorIndex])
                }
                .onTapGesture { selectGender(g) }
            }
        }
        .padding(.leading, 26)
        .frame(height: 80)
    }

    private func selectGender(_ g: AvatarGender) {
        guard g != gender else { return }
        gender = g
        hairIndex = (g == .boy) ? 5 : 0          // قصير للولد / طويل للبنت
        if g == .boy {
            // الفساتين والتنانير للبنات فقط (عدّل الشرطين إن أردت غير ذلك)
            if avatarTopOptions[topIndex].kind == .dress { topIndex = avatarHospitalID }
            if avatarBottomOptions[bottomIndex].kind == .skirt { bottomIndex = avatarHospitalID }
        }
    }

    // MARK: Wardrobe (لبس المستشفى أولًا، والباقي بالنقاط)

    private var visibleTopOptions: [AvatarTopOption] {
        let list = avatarTopOptions.filter { gender == .girl || $0.kind != .dress }
        return list.filter { $0.id == avatarHospitalID } + list.filter { $0.id != avatarHospitalID }
    }

    private var visibleBottomOptions: [AvatarBottomOption] {
        let list = avatarBottomOptions.filter { gender == .girl || $0.kind != .skirt }
        return list.filter { $0.id == avatarHospitalID } + list.filter { $0.id != avatarHospitalID }
    }

    private func selectTop(_ option: AvatarTopOption) {
        if wardrobe.ownsTop(option.id) { topIndex = option.id }
        else { requestPurchase(isTop: true, id: option.id) }
    }

    private func selectBottom(_ option: AvatarBottomOption) {
        if wardrobe.ownsBottom(option.id) { bottomIndex = option.id }
        else { requestPurchase(isTop: false, id: option.id) }
    }

    private func requestPurchase(isTop: Bool, id: Int) {
        let price = (isTop ? avatarTopPrices[id] : avatarBottomPrices[id]) ?? 0
        if wardrobe.points >= price {
            shopAlert = .confirm(isTop: isTop, id: id, price: price)
        } else {
            shopAlert = .notEnough(price: price)
        }
    }

    private func completePurchase(isTop: Bool, id: Int, price: Int) {
        if isTop {
            if wardrobe.buyTop(id, price: price) { topIndex = id }
        } else {
            if wardrobe.buyBottom(id, price: price) { bottomIndex = id }
        }
    }

    private var shopAlertBinding: Binding<Bool> {
        Binding(get: { shopAlert != nil },
                set: { if !$0 { shopAlert = nil } })
    }

    private var shopAlertTitle: String {
        switch shopAlert {
        case .confirm:   return "Buy this item?"
        case .notEnough: return "Not enough points"
        case .none:      return ""
        }
    }

    private var shopAlertMessage: String {
        switch shopAlert {
        case .confirm(_, _, let price):
            return "It costs \(price) points. You have \(wardrobe.points)."
        case .notEnough(let price):
            return "You need \(price) points. Collect more points on the islands!"
        case .none:
            return ""
        }
    }

    @ViewBuilder
    private var shopAlertButtons: some View {
        switch shopAlert {
        case .confirm(let isTop, let id, let price):
            Button("Buy for \(price) pts") {
                completePurchase(isTop: isTop, id: id, price: price)
            }
            Button("Cancel", role: .cancel) { }
        default:
            Button("OK", role: .cancel) { }
        }
    }

    /// يطبّق لون الشعر المختار على أي شكل شعر
    private func styledHair(_ option: AvatarHairOption) -> AvatarHairOption {
        AvatarHairOption(id: option.id, style: option.style, color: avatarHairColors[hairColorIndex])
    }

    /// الخيار رقم 4 (طويل بنفسجي) صار مكررًا لأن اللون منفصل الآن، لذلك لا يظهر في الصف
    private var visibleHairOptions: [AvatarHairOption] {
        avatarHairOptions.filter { $0.id != 4 }
    }

    private var hairColorRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 18) {
                ForEach(avatarHairColors.indices, id: \.self) { i in
                    Button { hairColorIndex = i } label: {
                        AvatarColorSwatch(color: avatarHairColors[i], isSelected: hairColorIndex == i)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 29)
        }
        .scrollClipDisabled()
        .frame(height: 52)
    }

    private var skinRow: some View {
        HStack(spacing: 26.5) {
            ForEach(avatarSkinTones.indices, id: \.self) { i in
                Button { skinIndex = i } label: {
                    AvatarSkinSwatch(color: avatarSkinTones[i], isSelected: skinIndex == i)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, 29)
        .frame(height: 52)
    }

    private var topsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 13) {
                ForEach(visibleTopOptions) { option in
                    AvatarOptionTile(isSelected: topIndex == option.id) {
                        AvatarTopIcon(option: option)
                    }
                    .overlay {
                        if !wardrobe.ownsTop(option.id) {
                            AvatarLockedOverlay(price: avatarTopPrices[option.id] ?? 0)
                        }
                    }
                    .onTapGesture { selectTop(option) }
                }
            }
            .padding(.horizontal, 26)
        }
        .scrollClipDisabled()
        .frame(height: 80)
    }

    private var bottomsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 13) {
                ForEach(visibleBottomOptions) { option in
                    AvatarOptionTile(isSelected: bottomIndex == option.id) {
                        AvatarBottomIcon(option: option)
                    }
                    .overlay {
                        if !wardrobe.ownsBottom(option.id) {
                            AvatarLockedOverlay(price: avatarBottomPrices[option.id] ?? 0)
                        }
                    }
                    .onTapGesture { selectBottom(option) }
                }
            }
            .padding(.horizontal, 26)
        }
        .scrollClipDisabled()
        .frame(height: 80)
    }
}

// MARK: - Preview

#Preview {
    AvatarCustomizerView()
}
