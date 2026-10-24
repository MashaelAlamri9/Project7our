//
//  Home.swift
//  Porject7our
//
//  Created by HANAN ABDALLAH on 14/05/1448 AH.
//

import Foundation
import SwiftUI

// MARK: - Colors

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    static let sea        = Color(hex: 0x7FA3A3)
    static let riverDark  = Color(hex: 0x6B8F8F)
    static let riverLight = Color(hex: 0x8FB0AE)
    static let sandTop    = Color(hex: 0xF0DC96)
    static let sandMid    = Color(hex: 0xC9A96A)
    static let sandSide   = Color(hex: 0xAD925F)
    static let trunk      = Color(hex: 0x6B5A44)
    static let leaf       = Color(hex: 0x5E7F5F)
    static let chestBrown = Color(hex: 0x6B4A1A)
    static let gold       = Color(hex: 0xF5C14B)
    static let pillBrown  = Color(hex: 0x6B4A35)
    static let pillBorder = Color(hex: 0x9A7658)
    static let badgeFill  = Color(hex: 0xD9C7A0)
}

// MARK: - Model

struct IslandItem: Identifiable {
    let id: Int
    let x: CGFloat        // fraction of screen width
    let y: CGFloat        // fraction of screen height (island center)
    let badgeY: CGFloat   // fraction of screen height (number badge)
    let scale: CGFloat
    let isLocked: Bool
}

private let islands: [IslandItem] = [
    .init(id: 1, x: 0.22, y: 0.855, badgeY: 0.937, scale: 1.00, isLocked: false),
    .init(id: 2, x: 0.78, y: 0.714, badgeY: 0.800, scale: 0.88, isLocked: false),
    .init(id: 3, x: 0.23, y: 0.620, badgeY: 0.700, scale: 0.90, isLocked: false),
    .init(id: 4, x: 0.78, y: 0.527, badgeY: 0.608, scale: 0.88, isLocked: false),
    .init(id: 5, x: 0.25, y: 0.397, badgeY: 0.467, scale: 0.72, isLocked: true),
    .init(id: 6, x: 0.77, y: 0.340, badgeY: 0.410, scale: 0.72, isLocked: true)
]

// MARK: - Main screen

struct IslandsMapView: View {
    var userName: String = "sawsan"
    var coins: Int = 5
    var onSelectIsland: (Int) -> Void = { _ in }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                Color.sea

                RiverView()
                    .frame(width: w, height: h)

                // Eagle
                EagleView()
                    .scaleEffect(w * 0.70 / 370)
                    .frame(width: w * 0.70, height: w * 0.70 * 180 / 370)
                    .position(x: w * 0.5, y: h * 0.185)

                // Islands + number badges
                ForEach(islands) { island in
                    IslandView(isLocked: island.isLocked)
                        .scaleEffect(island.scale * min(w / 393, 1.2))
                        .frame(width: 200 * island.scale * min(w / 393, 1.2),
                               height: 130 * island.scale * min(w / 393, 1.2))
                        .position(x: w * island.x, y: h * island.y)
                        .onTapGesture {
                            if !island.isLocked { onSelectIsland(island.id) }
                        }

                    NumberBadge(number: island.id)
                        .position(x: w * island.x, y: h * island.badgeY)
                }

                // Greeting pill
                GreetingPill(name: userName, coins: coins)
                    .frame(width: w, alignment: .leading)
                    .padding(.leading, 36)
                    .position(x: w / 2, y: max(geo.safeAreaInsets.top + 50, h * 0.13))

                // Bottom hint
                Text("tap an island to explore")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(Color(hex: 0x4A4A4A))
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(Color(hex: 0xF1E9DC, opacity: 0.85))
                    .clipShape(Capsule())
                    .position(x: w * 0.5, y: h - max(geo.safeAreaInsets.bottom, 20) - 14)
            }
            .frame(width: w, height: h)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Greeting pill

struct GreetingPill: View {
    let name: String
    let coins: Int

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(Color.gold)
                Text("\(coins)")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundColor(Color.chestBrown)
            }
            .frame(width: 28, height: 28)

            // استبدل الخط بالخط المخصص من تصميمك:
            // .font(.custom("YourFontName", size: 16))
            Text("Hi, \(name)")
                .font(.system(size: 16, weight: .medium, design: .serif))
                .italic()
                .foregroundColor(Color.gold.opacity(0.9))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.pillBrown)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.pillBorder, lineWidth: 3))
        .shadow(color: .black.opacity(0.15), radius: 3, y: 2)
    }
}

// MARK: - Number badge

struct NumberBadge: View {
    let number: Int

    var body: some View {
        Text("\(number)")
            .font(.system(size: 20, weight: .regular, design: .rounded))
            .foregroundColor(Color(hex: 0x4A3B2A))
            .frame(width: 52, height: 44)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.badgeFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.pillBorder, lineWidth: 2.5)
            )
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.chestBrown.opacity(0.8))
                    .offset(y: 4)
            )
    }
}

// MARK: - Island (drawn in a 200 x 130 canvas)

struct IslandView: View {
    var isLocked: Bool = false

    var body: some View {
        ZStack {
            // Water shadow
            Ellipse()
                .fill(Color.gray.opacity(0.35))
                .frame(width: 192, height: 62)
                .position(x: 100, y: 98)

            // Sand layers
            Ellipse().fill(Color.sandSide)
                .frame(width: 168, height: 54)
                .position(x: 100, y: 90)
            Ellipse().fill(Color.sandMid)
                .frame(width: 168, height: 52)
                .position(x: 100, y: 83)
            Ellipse().fill(Color.sandTop)
                .frame(width: 168, height: 50)
                .position(x: 100, y: 76)

            // Palm tree
            PalmTree()
                .frame(width: 80, height: 80)
                .position(x: 62, y: 42)

            if isLocked {
                Image(systemName: "lock")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.7))
                    .position(x: 70, y: 82)
                Ellipse()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: 22, height: 9)
                    .position(x: 118, y: 80)
            } else {
                TreasureChest()
                    .frame(width: 44, height: 40)
                    .position(x: 128, y: 66)
            }
        }
        .frame(width: 200, height: 130)
        .opacity(isLocked ? 0.55 : 1)
    }
}

struct PalmTree: View {
    var body: some View {
        ZStack {
            // Trunk
            Path { p in
                p.move(to: CGPoint(x: 28, y: 78))
                p.addQuadCurve(to: CGPoint(x: 42, y: 26),
                               control: CGPoint(x: 26, y: 48))
            }
            .stroke(Color.trunk, style: StrokeStyle(lineWidth: 5, lineCap: .round))

            // Leaves
            ForEach(0..<5, id: \.self) { i in
                Capsule()
                    .fill(Color.leaf)
                    .frame(width: 42, height: 9)
                    .offset(x: 18)
                    .rotationEffect(.degrees(Double(i) * 55 - 150), anchor: .leading)
                    .position(x: 42, y: 26)
                    .offset(x: -18 + 18)
            }
        }
    }
}

struct TreasureChest: View {
    var body: some View {
        ZStack {
            // Coins pile
            HStack(spacing: -2) {
                Circle().fill(Color.gold).frame(width: 7, height: 7)
                Circle().fill(Color.gold).frame(width: 7, height: 7)
                Circle().fill(Color.gold).frame(width: 7, height: 7)
            }
            .offset(y: -15)

            // Body
            RoundedRectangle(cornerRadius: 3).fill(Color.chestBrown)
                .frame(width: 38, height: 22)
                .offset(y: 4)
            // Lid band
            Rectangle().fill(Color.sandMid)
                .frame(width: 38, height: 4)
                .offset(y: -3)
            // Lock
            RoundedRectangle(cornerRadius: 1).fill(Color.gold)
                .frame(width: 5, height: 9)
                .offset(y: 3)
        }
    }
}

// MARK: - River

struct RiverView: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // Light band
                Path { p in
                    p.move(to: CGPoint(x: w * 0.60, y: h * 0.31))
                    p.addCurve(to: CGPoint(x: w * 0.50, y: h * 0.46),
                               control1: CGPoint(x: w * 0.55, y: h * 0.36),
                               control2: CGPoint(x: w * 0.46, y: h * 0.40))
                    p.addCurve(to: CGPoint(x: w * 0.40, y: h * 0.72),
                               control1: CGPoint(x: w * 0.53, y: h * 0.55),
                               control2: CGPoint(x: w * 0.43, y: h * 0.62))
                    p.addCurve(to: CGPoint(x: w * 0.36, y: h),
                               control1: CGPoint(x: w * 0.38, y: h * 0.82),
                               control2: CGPoint(x: w * 0.39, y: h * 0.92))
                    p.addLine(to: CGPoint(x: w * 0.72, y: h))
                    p.addCurve(to: CGPoint(x: w * 0.63, y: h * 0.70),
                               control1: CGPoint(x: w * 0.66, y: h * 0.88),
                               control2: CGPoint(x: w * 0.62, y: h * 0.80))
                    p.addCurve(to: CGPoint(x: w * 0.66, y: h * 0.31),
                               control1: CGPoint(x: w * 0.66, y: h * 0.55),
                               control2: CGPoint(x: w * 0.60, y: h * 0.40))
                    p.closeSubpath()
                }
                .fill(Color.riverLight.opacity(0.6))

                // Dark part (left side of the river)
                Path { p in
                    p.move(to: CGPoint(x: w * 0.50, y: h * 0.50))
                    p.addCurve(to: CGPoint(x: w * 0.42, y: h * 0.72),
                               control1: CGPoint(x: w * 0.50, y: h * 0.58),
                               control2: CGPoint(x: w * 0.45, y: h * 0.64))
                    p.addCurve(to: CGPoint(x: w * 0.38, y: h),
                               control1: CGPoint(x: w * 0.40, y: h * 0.82),
                               control2: CGPoint(x: w * 0.41, y: h * 0.92))
                    p.addLine(to: CGPoint(x: w * 0.58, y: h))
                    p.addCurve(to: CGPoint(x: w * 0.55, y: h * 0.70),
                               control1: CGPoint(x: w * 0.56, y: h * 0.88),
                               control2: CGPoint(x: w * 0.53, y: h * 0.80))
                    p.addCurve(to: CGPoint(x: w * 0.56, y: h * 0.50),
                               control1: CGPoint(x: w * 0.57, y: h * 0.62),
                               control2: CGPoint(x: w * 0.54, y: h * 0.56))
                    p.closeSubpath()
                }
                .fill(Color.riverDark.opacity(0.7))
            }
        }
    }
}

// MARK: - Eagle (low-poly, drawn in a 370 x 180 canvas)

struct EagleView: View {
    private func poly(_ pts: [(CGFloat, CGFloat)]) -> Path {
        Path { p in
            guard let first = pts.first else { return }
            p.move(to: CGPoint(x: first.0, y: first.1))
            for pt in pts.dropFirst() { p.addLine(to: CGPoint(x: pt.0, y: pt.1)) }
            p.closeSubpath()
        }
    }

    var body: some View {
        ZStack {
            // Wings
            poly([(0, 92), (135, 50), (160, 52), (168, 100)])
                .fill(Color(hex: 0x555B5E))
            poly([(370, 92), (235, 50), (210, 52), (202, 100)])
                .fill(Color(hex: 0x555B5E))
            poly([(40, 90), (135, 62), (160, 64), (166, 98)])
                .fill(Color(hex: 0x3F4548))
            poly([(330, 90), (235, 62), (210, 64), (204, 98)])
                .fill(Color(hex: 0x3F4548))

            // Tail
            poly([(172, 140), (200, 140), (200, 178), (172, 178)])
                .fill(Color(hex: 0x3A3D40))

            // Body
            poly([(185, 6), (203, 32), (214, 96), (200, 145), (170, 145), (156, 96), (167, 32)])
                .fill(Color(hex: 0xE8E8E4))
            // Body shade
            poly([(185, 32), (204, 52), (185, 100), (166, 52)])
                .fill(Color(hex: 0xD2D4D1))
            // Beak
            poly([(180, 8), (190, 0), (191, 12)])
                .fill(Color.gold)
        }
        .frame(width: 370, height: 180)
    }
}

// MARK: - Preview

#Preview {
    IslandsMapView { id in
        print("Selected island \(id)")
    }
}


// MARK: - ContentView (يستدعيه HorApp.swift)

struct ContentView: View {
    var body: some View {
        IslandsMapView()
    }
}
