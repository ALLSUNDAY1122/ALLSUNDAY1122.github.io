import SwiftUI

/// マスコット「もじろう」の表情。
enum MascotExpression {
    case normal
    case happy
    case frustrated
    case celebrate
}

/// オリジナルキャラクター「もじろう」。画像ファイルは使わず、
/// SwiftUI の図形だけで描くベクターキャラ。座標はすべて size 基準の相対指定。
struct MascotView: View {
    var expression: MascotExpression = .normal
    var size: CGFloat = 72

    private var bodyColor: Color { Color(red: 1.0, green: 0.80, blue: 0.35) }
    private var cheekColor: Color { Color(red: 0.98, green: 0.55, blue: 0.55).opacity(0.55) }

    private var centerX: CGFloat { size / 2 }
    private var eyeY: CGFloat { size / 2 + 0.02 * size }
    private var mouthY: CGFloat { size / 2 + 0.18 * size }

    var body: some View {
        ZStack {
            armsView
            bodyBaseView
            Circle()
                .stroke(Palette.ink.opacity(0.15), lineWidth: max(1, 0.02 * size))
                .frame(width: size, height: size)
            cheeksView
            eyesView
            mouthView
            if expression == .celebrate {
                starsView
            }
        }
        .frame(width: size, height: size)
    }

    // MARK: - 体とハチマキ

    /// 円の体にハチマキの帯を重ね、円でクリップしたもの。
    private var bodyBaseView: some View {
        ZStack {
            Circle()
                .fill(bodyColor)
            RoundedRectangle(cornerRadius: 0.05 * size)
                .fill(Palette.primary)
                .frame(width: size, height: 0.30 * size)
                .offset(y: -0.31 * size)
            Text("漢")
                .font(.maru(size * 0.22))
                .foregroundStyle(.white)
                .offset(y: -0.31 * size)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    // MARK: - 腕

    private var armsView: some View {
        let raised = expression == .celebrate
        return ZStack {
            Capsule()
                .fill(bodyColor)
                .frame(width: 0.10 * size, height: 0.26 * size)
                .rotationEffect(.degrees(raised ? -40 : 35))
                .offset(x: -0.52 * size, y: raised ? -0.14 * size : 0.10 * size)
            Capsule()
                .fill(bodyColor)
                .frame(width: 0.10 * size, height: 0.26 * size)
                .rotationEffect(.degrees(raised ? 40 : -35))
                .offset(x: 0.52 * size, y: raised ? -0.14 * size : 0.10 * size)
        }
    }

    // MARK: - 頬

    private var cheeksView: some View {
        ZStack {
            Ellipse()
                .fill(cheekColor)
                .frame(width: 0.17 * size, height: 0.11 * size)
                .offset(x: -0.29 * size, y: 0.10 * size)
            Ellipse()
                .fill(cheekColor)
                .frame(width: 0.17 * size, height: 0.11 * size)
                .offset(x: 0.29 * size, y: 0.10 * size)
        }
    }

    // MARK: - 目

    @ViewBuilder
    private var eyesView: some View {
        switch expression {
        case .normal:
            ZStack {
                Circle()
                    .fill(Palette.ink)
                    .frame(width: 0.09 * size, height: 0.09 * size)
                    .offset(x: -0.18 * size, y: 0.02 * size)
                Circle()
                    .fill(Palette.ink)
                    .frame(width: 0.09 * size, height: 0.09 * size)
                    .offset(x: 0.18 * size, y: 0.02 * size)
            }
        case .happy, .celebrate:
            ZStack {
                happyEyePath(centerX: centerX - 0.18 * size)
                    .stroke(Palette.ink, style: StrokeStyle(lineWidth: 0.04 * size, lineCap: .round))
                happyEyePath(centerX: centerX + 0.18 * size)
                    .stroke(Palette.ink, style: StrokeStyle(lineWidth: 0.04 * size, lineCap: .round))
            }
            .frame(width: size, height: size)
        case .frustrated:
            ZStack {
                frustratedEyePath(centerX: centerX - 0.18 * size, isLeft: true)
                    .stroke(Palette.ink, style: StrokeStyle(lineWidth: 0.04 * size, lineCap: .round))
                frustratedEyePath(centerX: centerX + 0.18 * size, isLeft: false)
                    .stroke(Palette.ink, style: StrokeStyle(lineWidth: 0.04 * size, lineCap: .round))
            }
            .frame(width: size, height: size)
        }
    }

    /// 上向きの弧（∩）の目。
    private func happyEyePath(centerX: CGFloat) -> Path {
        var path = Path()
        path.addArc(
            center: CGPoint(x: centerX, y: eyeY),
            radius: 0.075 * size,
            startAngle: .degrees(180),
            endAngle: .degrees(360),
            clockwise: true
        )
        return path
    }

    /// 「>」「<」型の目。
    private func frustratedEyePath(centerX: CGFloat, isLeft: Bool) -> Path {
        let r = 0.055 * size
        var path = Path()
        if isLeft {
            path.move(to: CGPoint(x: centerX - r, y: eyeY - r))
            path.addLine(to: CGPoint(x: centerX + r, y: eyeY))
            path.addLine(to: CGPoint(x: centerX - r, y: eyeY + r))
        } else {
            path.move(to: CGPoint(x: centerX + r, y: eyeY - r))
            path.addLine(to: CGPoint(x: centerX - r, y: eyeY))
            path.addLine(to: CGPoint(x: centerX + r, y: eyeY + r))
        }
        return path
    }

    // MARK: - 口

    @ViewBuilder
    private var mouthView: some View {
        switch expression {
        case .normal:
            smilePath
                .stroke(Palette.ink, style: StrokeStyle(lineWidth: 0.035 * size, lineCap: .round))
                .frame(width: size, height: size)
        case .happy:
            openMouthPath(radius: 0.085 * size)
                .fill(Palette.ink)
                .frame(width: size, height: size)
        case .celebrate:
            openMouthPath(radius: 0.11 * size)
                .fill(Palette.ink)
                .frame(width: size, height: size)
        case .frustrated:
            wavePath
                .stroke(Palette.ink, style: StrokeStyle(lineWidth: 0.035 * size, lineCap: .round))
                .frame(width: size, height: size)
        }
    }

    /// 下向きの小さい弧（笑口）。
    private var smilePath: Path {
        var path = Path()
        path.addArc(
            center: CGPoint(x: centerX, y: mouthY),
            radius: 0.07 * size,
            startAngle: .degrees(0),
            endAngle: .degrees(180),
            clockwise: true
        )
        return path
    }

    /// 塗りの半円（開いた笑口）。
    private func openMouthPath(radius: CGFloat) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: centerX - radius, y: mouthY))
        path.addArc(
            center: CGPoint(x: centerX, y: mouthY),
            radius: radius,
            startAngle: .degrees(0),
            endAngle: .degrees(180),
            clockwise: true
        )
        path.closeSubpath()
        return path
    }

    /// 小さな波線（2山）。
    private var wavePath: Path {
        let halfWidth = 0.09 * size
        let hump = 0.03 * size
        var path = Path()
        path.move(to: CGPoint(x: centerX - halfWidth, y: mouthY))
        path.addQuadCurve(
            to: CGPoint(x: centerX, y: mouthY),
            control: CGPoint(x: centerX - halfWidth / 2, y: mouthY - hump)
        )
        path.addQuadCurve(
            to: CGPoint(x: centerX + halfWidth, y: mouthY),
            control: CGPoint(x: centerX + halfWidth / 2, y: mouthY + hump)
        )
        return path
    }

    // MARK: - 星（celebrate のみ）

    private var starsView: some View {
        ZStack {
            Image(systemName: "star.fill")
                .font(.system(size: 0.22 * size))
                .foregroundStyle(Palette.accent)
                .offset(x: -0.55 * size, y: -0.42 * size)
            Image(systemName: "star.fill")
                .font(.system(size: 0.15 * size))
                .foregroundStyle(Palette.accent)
                .offset(x: 0.58 * size, y: -0.28 * size)
        }
    }
}
