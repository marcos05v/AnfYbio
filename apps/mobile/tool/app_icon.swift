// Dibuja el logo de AnfYbio (1024 × 1024, sin transparencia, como pide
// iOS): una gota de agua (natación y apnea) con una pesa (fuerza), en el
// color de la app. Uso: swift tool/app_icon.swift salida.png
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let space = CGColorSpaceCreateDeviceRGB()
guard CommandLine.arguments.count == 2,
  let ctx = CGContext(
    data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
    space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
else {
  FileHandle.standardError.write("Uso: swift app_icon.swift salida.png\n".data(using: .utf8)!)
  exit(1)
}

// Origen arriba a la izquierda, como en un diseño.
ctx.translateBy(x: 0, y: CGFloat(size))
ctx.scaleBy(x: 1, y: -1)

func color(_ hex: UInt32) -> CGColor {
  CGColor(
    red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
    blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

// Fondo: degradado del verde azulado de la app.
let gradient = CGGradient(
  colorsSpace: space, colors: [color(0x14A3A3), color(0x075E5E)] as CFArray,
  locations: [0, 1])!
ctx.drawLinearGradient(
  gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: CGFloat(size)), options: [])

// Gota: un círculo abajo y una punta arriba unidos con curvas suaves.
let center = CGPoint(x: 512, y: 612)
let radius: CGFloat = 282
let tip = CGPoint(x: 512, y: 128)
let drop = CGMutablePath()
drop.move(to: tip)
drop.addCurve(
  to: CGPoint(x: center.x + radius, y: center.y),
  control1: CGPoint(x: 600, y: 270), control2: CGPoint(x: center.x + radius, y: 430))
drop.addArc(
  center: center, radius: radius, startAngle: 0, endAngle: .pi, clockwise: false)
drop.addCurve(
  to: tip,
  control1: CGPoint(x: center.x - radius, y: 430), control2: CGPoint(x: 424, y: 270))
drop.closeSubpath()
ctx.setFillColor(color(0xFFFFFF))
ctx.addPath(drop)
ctx.fillPath()

// Pesa dentro de la gota, en el color de la app.
ctx.setFillColor(color(0x0A7C7C))
func rounded(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) {
  ctx.addPath(
    CGPath(
      roundedRect: CGRect(x: x - w / 2, y: y - h / 2, width: w, height: h),
      cornerWidth: r, cornerHeight: r, transform: nil))
  ctx.fillPath()
}
let y: CGFloat = 640
rounded(512, y, 330, 44, 22)  // barra
for side in [-1.0, 1.0] as [CGFloat] {
  rounded(512 + side * 118, y, 62, 214, 22)  // disco grande
  rounded(512 + side * 182, y, 46, 150, 18)  // disco chico
}

let url = URL(fileURLWithPath: CommandLine.arguments[1])
guard let image = ctx.makeImage(),
  let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
else { exit(1) }
CGImageDestinationAddImage(dest, image, nil)
exit(CGImageDestinationFinalize(dest) ? 0 : 1)
