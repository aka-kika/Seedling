import SwiftUI

// MARK: - SeedGrowthView
//
// The "seed moment." A fine, high-end line-art animation that draws itself:
//   .birth  — a seed settles and a short sprout rises (the welcome beat, shown
//             the first time a folder is chosen).
//   .growth — the stem extends and two leaves draw in along their veins (shown
//             on every successful seed).
//
// Pure SwiftUI, no image assets. KIKA-compliant: accent color only, hairline
// strokes, no shadows. Honors Reduce Motion by rendering the final frame.
//
// Both the seed dot and the stem/leaves are Shapes whose `animatableData` is a
// single `progress`. Animating `progress` makes SwiftUI call `path(in:)` at each
// interpolated step, so the staggered, segment-by-segment drawing is frame-exact
// (a plain `.trim` modifier can't stagger like this).

enum SeedGrowthMode {
    case birth
    case growth
}

struct SeedGrowthView: View {
    let mode: SeedGrowthMode
    var size: CGFloat = 120
    var onComplete: (() -> Void)?

    @Environment(\.kikaTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: CGFloat = 0
    @State private var bloom = false
    @State private var bloomStarted = false

    private var duration: Double { mode == .birth ? 1.2 : 1.4 }

    var body: some View {
        ZStack {
            SeedDotShape(mode: mode, progress: progress)
                .fill(theme.accent)
            SeedGrowthShape(mode: mode, progress: progress)
                .stroke(
                    theme.accent,
                    style: StrokeStyle(lineWidth: 1.0, lineCap: .round, lineJoin: .round)
                )
        }
        .frame(width: size, height: size)
        .overlay(alignment: .top) {
            // One breath of light as the growth completes (growth mode only).
            if mode == .growth && bloomStarted {
                Circle()
                    .fill(theme.accent)
                    .frame(width: size * 0.18, height: size * 0.18)
                    .blur(radius: size * 0.04)
                    .scaleEffect(bloom ? 1.7 : 0.3)
                    .opacity(bloom ? 0.0 : 0.7)
                    .padding(.top, size * 0.12)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .onAppear {
            if reduceMotion {
                progress = 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { onComplete?() }
                return
            }
            withAnimation(.easeInOut(duration: duration)) { progress = 1 }
            if mode == .growth {
                // Near the end of the draw, reveal the petal and let it swell + dissolve.
                DispatchQueue.main.asyncAfter(deadline: .now() + duration * 0.82) {
                    bloomStarted = true
                    withAnimation(.easeOut(duration: 0.55)) { bloom = true }
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.1) { onComplete?() }
        }
    }
}

// MARK: - Phase helper

/// Map global `progress` to a 0…1 fraction for a sub-segment that runs from
/// `start` to `end`.
private func phaseFraction(_ progress: CGFloat, _ start: CGFloat, _ end: CGFloat) -> CGFloat {
    guard progress > start else { return 0 }
    if progress >= end { return 1 }
    return (progress - start) / (end - start)
}

// MARK: - Bézier sampling (unit space, y-up)

/// Sample a cubic Bézier into `steps + 1` points, in normalized unit coordinates
/// where y points up (0 = bottom, 1 = top).
private func sampleCubic(_ a: CGPoint, _ c1: CGPoint, _ c2: CGPoint, _ b: CGPoint, steps: Int) -> [CGPoint] {
    var points: [CGPoint] = []
    points.reserveCapacity(steps + 1)
    for i in 0...steps {
        let t = CGFloat(i) / CGFloat(steps)
        let u = 1 - t
        let x = u*u*u*a.x + 3*u*u*t*c1.x + 3*u*t*t*c2.x + t*t*t*b.x
        let y = u*u*u*a.y + 3*u*u*t*c1.y + 3*u*t*t*c2.y + t*t*t*b.y
        points.append(CGPoint(x: x, y: y))
    }
    return points
}

/// Map unit (y-up) points into view coordinates within `rect`.
private func mapped(_ pts: [CGPoint], in rect: CGRect) -> [CGPoint] {
    pts.map { CGPoint(x: rect.minX + $0.x * rect.width,
                      y: rect.maxY - $0.y * rect.height) }
}

/// Append a polyline drawn up to fraction `f` (0…1) of its total length-by-count.
private func addPolyline(_ pts: [CGPoint], upTo f: CGFloat, to path: inout Path) {
    guard pts.count > 1, f > 0 else { return }
    path.move(to: pts[0])
    if f >= 1 {
        for p in pts.dropFirst() { path.addLine(to: p) }
        return
    }
    let total = CGFloat(pts.count - 1)
    let exact = total * f
    let full = Int(exact.rounded(.down))
    if full >= 1 {
        for i in 1...full where i < pts.count { path.addLine(to: pts[i]) }
    }
    if full + 1 < pts.count {
        let frac = exact - CGFloat(full)
        let a = pts[full]
        let b = pts[full + 1]
        path.addLine(to: CGPoint(x: a.x + (b.x - a.x) * frac,
                                 y: a.y + (b.y - a.y) * frac))
    }
}

// MARK: - The seed dot (filled)

private struct SeedDotShape: Shape {
    let mode: SeedGrowthMode
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        // Birth lingers on the seed; growth gets it out of the way quickly.
        let f = mode == .birth
            ? phaseFraction(progress, 0.0, 0.45)
            : phaseFraction(progress, 0.0, 0.16)
        let eased = f * f * (3 - 2 * f) // smoothstep
        let center = CGPoint(x: rect.midX, y: rect.maxY - 0.10 * rect.height)
        let maxR = 0.05 * rect.width
        let r = maxR * eased
        var path = Path()
        if r > 0.1 {
            path.addEllipse(in: CGRect(x: center.x - r, y: center.y - r, width: 2 * r, height: 2 * r))
        }
        return path
    }
}

// MARK: - Stem + leaves (stroked)

private struct SeedGrowthShape: Shape {
    let mode: SeedGrowthMode
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        switch mode {
        case .birth:
            // A short, deliberate sprout from the seed.
            let stem = sampleCubic(
                CGPoint(x: 0.5, y: 0.12),
                CGPoint(x: 0.46, y: 0.25),
                CGPoint(x: 0.54, y: 0.36),
                CGPoint(x: 0.5, y: 0.47),
                steps: 28
            )
            addPolyline(mapped(stem, in: rect), upTo: phaseFraction(progress, 0.4, 1.0), to: &path)

        case .growth:
            // Tall stem.
            let stem = sampleCubic(
                CGPoint(x: 0.5, y: 0.12),
                CGPoint(x: 0.40, y: 0.34),
                CGPoint(x: 0.60, y: 0.56),
                CGPoint(x: 0.5, y: 0.76),
                steps: 36
            )
            addPolyline(mapped(stem, in: rect), upTo: phaseFraction(progress, 0.10, 0.52), to: &path)

            // Left leaf — one continuous stroke: out along the top edge to the
            // tip, then back along the bottom edge to the anchor.
            let leftTop = sampleCubic(
                CGPoint(x: 0.50, y: 0.50),
                CGPoint(x: 0.42, y: 0.62),
                CGPoint(x: 0.26, y: 0.66),
                CGPoint(x: 0.18, y: 0.62),
                steps: 20
            )
            let leftBottom = sampleCubic(
                CGPoint(x: 0.18, y: 0.62),
                CGPoint(x: 0.30, y: 0.54),
                CGPoint(x: 0.44, y: 0.50),
                CGPoint(x: 0.50, y: 0.50),
                steps: 20
            )
            addPolyline(mapped(leftTop + leftBottom.dropFirst(), in: rect),
                        upTo: phaseFraction(progress, 0.46, 0.76), to: &path)

            // Right leaf.
            let rightTop = sampleCubic(
                CGPoint(x: 0.50, y: 0.60),
                CGPoint(x: 0.62, y: 0.72),
                CGPoint(x: 0.76, y: 0.76),
                CGPoint(x: 0.84, y: 0.74),
                steps: 20
            )
            let rightBottom = sampleCubic(
                CGPoint(x: 0.84, y: 0.74),
                CGPoint(x: 0.72, y: 0.64),
                CGPoint(x: 0.58, y: 0.60),
                CGPoint(x: 0.50, y: 0.60),
                steps: 20
            )
            addPolyline(mapped(rightTop + rightBottom.dropFirst(), in: rect),
                        upTo: phaseFraction(progress, 0.60, 0.96), to: &path)
        }

        return path
    }
}

#Preview {
    VStack(spacing: 24) {
        SeedGrowthView(mode: .birth)
        SeedGrowthView(mode: .growth)
    }
    .padding(40)
    .background(.regularMaterial)
    .environment(\.kikaTheme, .resolve(scheme: .dark))
    .preferredColorScheme(.dark)
}
