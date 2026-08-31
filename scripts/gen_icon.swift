// 用法: swift gen_icon.swift <iconset目录>
// 渲染一张 1024x1024 应用图标 PNG 到 iconset/icon_512x512@2x.png
import AppKit

let dir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/BreakTimer.iconset"
let size: CGFloat = 1024

let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

let inset = NSRect(x: 96, y: 96, width: size - 192, height: size - 192)
let path = NSBezierPath(roundedRect: inset, xRadius: 220, yRadius: 220)
path.addClip()
if let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.13, green: 0.72, blue: 0.63, alpha: 1),
    NSColor(calibratedRed: 0.36, green: 0.44, blue: 0.86, alpha: 1),
]) {
    gradient.draw(in: path, angle: -60)
}

let emoji = NSAttributedString(string: "🍅", attributes: [
    .font: NSFont.systemFont(ofSize: 520),
])
let emojiSize = emoji.size()
emoji.draw(at: NSPoint(x: (size - emojiSize.width) / 2,
                       y: (size - emojiSize.height) / 2))

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("gen_icon: 渲染失败\n".utf8))
    exit(1)
}
try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
try png.write(to: URL(fileURLWithPath: "\(dir)/icon_512x512@2x.png"))
print("gen_icon: 已生成 \(dir)/icon_512x512@2x.png")
