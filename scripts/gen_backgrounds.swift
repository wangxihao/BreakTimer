// 用法: swift gen_backgrounds.swift <输出目录>
// 生成 10 张 1920x1080 护眼绿渐变背景（柔和多层渐变 + 光斑），供休息浮层随机使用。
import AppKit

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Backgrounds"
try FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

// 每张图的配色：深→浅的绿色系组合（色相在 90–160 之间，饱和度低，护眼不刺眼）
let palettes: [[(CGFloat, CGFloat, CGFloat)]] = [
    [(0.05, 0.16, 0.10), (0.13, 0.35, 0.22), (0.35, 0.58, 0.38)],   // 森林晨雾
    [(0.04, 0.13, 0.11), (0.10, 0.32, 0.27), (0.30, 0.55, 0.44)],   // 松林
    [(0.06, 0.15, 0.08), (0.18, 0.38, 0.20), (0.48, 0.64, 0.36)],   // 抹茶
    [(0.03, 0.12, 0.12), (0.08, 0.28, 0.26), (0.26, 0.52, 0.46)],   // 薄荷深潭
    [(0.07, 0.18, 0.10), (0.22, 0.42, 0.24), (0.58, 0.68, 0.40)],   // 春田
    [(0.05, 0.14, 0.13), (0.12, 0.34, 0.30), (0.38, 0.60, 0.52)],   // 青瓷
    [(0.08, 0.17, 0.09), (0.16, 0.36, 0.18), (0.42, 0.62, 0.30)],   // 竹林
    [(0.04, 0.11, 0.09), (0.11, 0.30, 0.24), (0.33, 0.55, 0.42)],   // 苔原
    [(0.06, 0.15, 0.12), (0.20, 0.40, 0.30), (0.50, 0.66, 0.50)],   // 湖畔
    [(0.05, 0.13, 0.10), (0.14, 0.33, 0.26), (0.36, 0.58, 0.48)],   // 岚山
]

let size = CGSize(width: 1920, height: 1080)

for (index, palette) in palettes.enumerated() {
    let image = NSImage(size: size)
    image.lockFocus()
    guard let context = NSGraphicsContext.current?.cgContext else { continue }

    // 底层：对角线性渐变
    let rgbSpace = CGColorSpaceCreateDeviceRGB()
    let stops = palette.map { NSColor(calibratedRed: $0.0, green: $0.1, blue: $0.2, alpha: 1).cgColor }
    if let gradient = CGGradient(colorsSpace: rgbSpace, colors: stops as CFArray, locations: [0, 0.55, 1]) {
        context.drawLinearGradient(gradient,
                                   start: CGPoint(x: 0, y: size.height),
                                   end: CGPoint(x: size.width, y: 0),
                                   options: [])
    }

    // 中层：柔光圆斑（模拟树叶间漏光），位置随索引变化
    let glowCenter = CGPoint(x: size.width * (0.25 + 0.5 * CGFloat(index % 3) / 2),
                             y: size.height * (0.55 + 0.3 * CGFloat((index / 3) % 2)))
    let light = palette[2]
    if let glow = CGGradient(colorsSpace: rgbSpace,
                             colors: [
                                NSColor(calibratedRed: light.0, green: light.1, blue: light.2, alpha: 0.30).cgColor,
                                NSColor(calibratedRed: light.0, green: light.1, blue: light.2, alpha: 0).cgColor,
                             ] as CFArray, locations: [0, 1]) {
        context.drawRadialGradient(glow,
                                   startCenter: glowCenter, startRadius: 0,
                                   endCenter: glowCenter, endRadius: size.width * 0.5,
                                   options: [])
    }

    // 顶层：几个大而虚的圆（ bokeh 光斑），透明度极低
    for i in 0..<4 {
        let r = CGFloat(90 + (i * 37 + index * 23) % 140)
        let cx = CGFloat((i * 463 + index * 271) % Int(size.width))
        let cy = CGFloat((i * 331 + index * 149) % Int(size.height))
        let circleColor = NSColor(calibratedRed: min(1, light.0 + 0.15),
                                  green: min(1, light.1 + 0.15),
                                  blue: min(1, light.2 + 0.12),
                                  alpha: 0.05 + 0.02 * CGFloat((i + index) % 3))
        context.setFillColor(circleColor.cgColor)
        context.fillEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
    }

    image.unlockFocus()

    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let jpeg = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.92]) else { continue }
    let name = String(format: "%@/bg-%02d.jpg", outDir, index + 1)
    try jpeg.write(to: URL(fileURLWithPath: name))
    print("生成 \(name)")
}
print("完成")
