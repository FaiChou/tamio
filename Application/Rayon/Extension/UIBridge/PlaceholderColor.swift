//
//  PlaceholderColor.swift
//  Rayon
//
//  AppKit draws a text field's placeholder in the secondary label colour; UIKit
//  draws it much fainter, and SwiftUI's TextField sets an attributed placeholder
//  in the primary colour at a quarter opacity.
//

import ObjectiveC
import UIKit

extension UITextField {
    /// From now on, placeholders in a faint grey (or no colour) are drawn in the
    /// secondary label colour. A placeholder given a colour of its own keeps it.
    static func drawPlaceholdersAsAppKit() {
        let selector = #selector(setter: UITextField.attributedPlaceholder)
        guard let original = class_getInstanceMethod(UITextField.self, selector),
              let replacement = class_getInstanceMethod(UITextField.self, #selector(UITextField.rx_setAttributedPlaceholder(_:)))
        else { return }
        method_exchangeImplementations(original, replacement)
    }

    @objc private func rx_setAttributedPlaceholder(_ placeholder: NSAttributedString?) {
        // The implementations are exchanged: this calls UIKit's setter.
        rx_setAttributedPlaceholder(placeholder.map(Self.recolored))
    }

    private static func recolored(_ placeholder: NSAttributedString) -> NSAttributedString {
        let result = NSMutableAttributedString(attributedString: placeholder)
        let whole = NSRange(location: 0, length: result.length)
        result.enumerateAttribute(.foregroundColor, in: whole) { value, range, _ in
            if (value as? UIColor).map(isFaintGrey) ?? true {
                result.addAttribute(.foregroundColor, value: UIColor.secondaryLabel, range: range)
            }
        }
        return result
    }

    private static func isFaintGrey(_ color: UIColor) -> Bool {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard color.resolvedColor(with: .current).getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return false }
        return abs(red - green) < 0.02 && abs(green - blue) < 0.02 && alpha < 0.4
    }
}
