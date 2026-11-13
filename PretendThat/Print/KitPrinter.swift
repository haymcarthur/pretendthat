import SwiftUI
import UIKit
import NutmegCore

/// Turns kit pages into one PDF and hands it to AirPrint.
enum KitPrinter {
    @MainActor
    static func pdf(pages: [KitPage], art: [String: UIImage], cutouts: [String: [UIImage?]] = [:]) -> Data {
        let data = NSMutableData()
        var box = CGRect(origin: .zero, size: KitPageView.size)
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let ctx = CGContext(consumer: consumer, mediaBox: &box, nil) else { return Data() }
        for page in pages {
            let renderer = ImageRenderer(content: KitPageView(page: page, art: art[page.item.id], cutouts: cutouts[page.item.id] ?? []))
            renderer.render { _, draw in
                ctx.beginPDFPage(nil)
                draw(ctx)
                ctx.endPDFPage()
            }
        }
        ctx.closePDF()
        return data as Data
    }

    @MainActor
    static func print(_ pdf: Data, jobName: String) {
        let info = UIPrintInfo(dictionary: nil)
        info.outputType = .general
        info.jobName = jobName
        let controller = UIPrintInteractionController.shared
        controller.printInfo = info
        controller.printingItem = pdf
        // On iPad the print sheet is a popover and needs an anchor.
        if let view = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows).first(where: \.isKeyWindow)?.rootViewController?.view {
            let anchor = CGRect(x: view.bounds.midX, y: view.bounds.maxY - 120, width: 1, height: 1)
            controller.present(from: anchor, in: view, animated: true)
        } else {
            controller.present(animated: true)
        }
    }
}
