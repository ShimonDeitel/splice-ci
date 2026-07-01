import UIKit

/// Renders a sharp still-frame share image: the death freeze-frame (passed as a snapshot),
/// big score, best combo, the "off by Xpx" of the fatal nick, a "Splice" wordmark + date.
/// (The full deterministic replay-to-mp4 clip is a documented v1.1 follow-up.)
enum ShareCard {

    static func make(snapshot: UIImage?,
                     score: Int,
                     bestCombo: Int,
                     deltaText: String,
                     isNewBest: Bool,
                     background: UIColor) -> UIImage {
        let size = CGSize(width: 1080, height: 1920)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let cg = ctx.cgContext
            background.setFill()
            cg.fill(CGRect(origin: .zero, size: size))

            // Freeze-frame snapshot, aspect-fill into the top 60%.
            if let snap = snapshot {
                let target = CGRect(x: 0, y: 0, width: size.width, height: size.height * 0.62)
                drawAspectFill(snap, in: target, context: cg)
                // Darken gradient toward the bottom for legibility.
                let colors = [UIColor.clear.cgColor, background.withAlphaComponent(0.95).cgColor] as CFArray
                if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                         colors: colors, locations: [0, 1]) {
                    cg.saveGState()
                    cg.clip(to: CGRect(x: 0, y: target.height * 0.5, width: size.width, height: target.height * 0.5 + 40))
                    cg.drawLinearGradient(grad,
                                          start: CGPoint(x: 0, y: target.height * 0.5),
                                          end: CGPoint(x: 0, y: target.height + 40),
                                          options: [])
                    cg.restoreGState()
                }
            }

            let center = size.width / 2

            // Big result label.
            let resultLabel = isNewBest ? "NEW BEST" : "NICKED"
            draw(text: resultLabel, font: .systemFont(ofSize: 84, weight: .heavy),
                 color: isNewBest ? UIColor(red: 1, green: 0.83, blue: 0, alpha: 1) : UIColor(red: 1, green: 0.27, blue: 0.33, alpha: 1),
                 center: CGPoint(x: center, y: size.height * 0.66))

            // Huge score.
            draw(text: "\(score)", font: .systemFont(ofSize: 320, weight: .black),
                 color: .white, center: CGPoint(x: center, y: size.height * 0.80))

            // Sub stats.
            draw(text: "BEST COMBO  \(bestCombo)   ·   \(deltaText)",
                 font: .systemFont(ofSize: 44, weight: .semibold),
                 color: UIColor.white.withAlphaComponent(0.85),
                 center: CGPoint(x: center, y: size.height * 0.90))

            // Wordmark + date.
            let df = DateFormatter(); df.dateFormat = "yyyy.MM.dd"
            draw(text: "SPLICE   ·   \(df.string(from: Date()))",
                 font: .systemFont(ofSize: 38, weight: .bold),
                 color: UIColor.white.withAlphaComponent(0.6),
                 center: CGPoint(x: center, y: size.height * 0.955))
        }
    }

    private static func draw(text: String, font: UIFont, color: UIColor, center: CGPoint) {
        let para = NSMutableParagraphStyle(); para.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font, .foregroundColor: color, .paragraphStyle: para
        ]
        let s = NSAttributedString(string: text, attributes: attrs)
        let bounds = s.boundingRect(with: CGSize(width: 1000, height: 600),
                                    options: [.usesLineFragmentOrigin], context: nil)
        let rect = CGRect(x: center.x - bounds.width / 2, y: center.y - bounds.height / 2,
                          width: bounds.width, height: bounds.height)
        s.draw(in: rect)
    }

    private static func drawAspectFill(_ image: UIImage, in rect: CGRect, context: CGContext) {
        context.saveGState()
        context.clip(to: rect)
        let imgSize = image.size
        let scale = max(rect.width / imgSize.width, rect.height / imgSize.height)
        let w = imgSize.width * scale, h = imgSize.height * scale
        let x = rect.midX - w / 2, y = rect.midY - h / 2
        image.draw(in: CGRect(x: x, y: y, width: w, height: h))
        context.restoreGState()
    }
}
