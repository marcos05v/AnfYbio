// Extrae el texto de un PDF con PDFKit, igual que la app en el iPhone
// (ADR-0009). Uso: swift tool/pdf_text.swift archivo.pdf
import Foundation
import PDFKit

guard CommandLine.arguments.count == 2,
  let document = PDFDocument(url: URL(fileURLWithPath: CommandLine.arguments[1]))
else {
  FileHandle.standardError.write("Uso: swift pdf_text.swift archivo.pdf\n".data(using: .utf8)!)
  exit(1)
}
print(document.string ?? "")
