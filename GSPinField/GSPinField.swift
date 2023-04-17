//
//  GSPinField.swift
//  GSPinField
//
//  Created by Gaganjot Singh on 15/02/2023.
//  Copyright © 2018 Gaganjot Singh. All rights reserved.
//

import UIKit

// MARK: - GSPinFieldDelegate
public protocol GSPinFieldDelegate: AnyObject {
    func pinField(_ field: GSPinField, didChangeTo string: String, isValid: Bool) // Optional
    func pinField(_ field: GSPinField, didFinishWith code: String)
}

public extension GSPinFieldDelegate {
    func pinField(_ field: GSPinField, didChangeTo string: String, isValid: Bool) {}
}

public struct GSPinFieldProperties {
    public weak var delegate: GSPinFieldDelegate? = nil
    public var numberOfCharacters: Int = 4 {
        didSet {
            precondition(numberOfCharacters >= 0, "🚫 Number of character must be >= 0, with 0 meaning dynamic")
        }
    }
    public var validCharacters: String = "0123456789" {
        didSet {
            precondition(validCharacters.count > 0, "🚫 There must be at least 1 valid character")
            precondition(!validCharacters.contains(token), "🚫 Valid characters can't contain token \"\(token)\"")
        }
    }
    public var token: Character = "•" {
        didSet {
            precondition(!validCharacters.contains(token), "🚫 token can't be one of the valid characters \"\(token)\"")
            precondition(!token.isWhitespace, "🚫 token can't be a whitespace. Please use a token with a clear color to achieve the same effect")
        }
    }
    public var isSecure : Bool = false
    public var secureToken: Character = "•"
    public var isUppercased: Bool = false
    public var keyboardType: UIKeyboardType = .numberPad
}

public struct GSPinFieldAppearance {
    
    public init() {}
    
    public var font: GS_MonospacedFont? = .menlo(40)
    public var tokenColor : UIColor = .black
    public var tokenFocusColor : UIColor = .gray
    public var textColor : UIColor = .black
    public var kerning : CGFloat = 20.0
}

// MARK: - GSPinField Class
public class GSPinField : UITextField {
    
    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        self.reload()
    }
    
    // MARK: - Public vars
    private (set) var properties = GSPinFieldProperties() {
        didSet {
            self.reload()
        }
    }
    
    private (set) var appearance = GSPinFieldAppearance() {
        didSet {
            self.reloadAppearance()
        }
    }
    
    public func updateProperties(block : ((inout GSPinFieldProperties) -> ())) {
        var properties = self.properties
        block(&properties)
        self.properties = properties
    }
    
    public func updateAppearence(block : ((inout GSPinFieldAppearance) -> ())) {
        var appearance = self.appearance
        block(&appearance)
        self.appearance = appearance
    }
    
    // MARK: - Overriden vars
    public override var text : String? {
        get { return invisibleText }
        set {
            self.invisibleField.text = newValue
            self.reloadAppearance()
        }
    }
    
    public override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        return action == #selector(paste(_:)) // Only allow pasting
    }
    
    // MARK: - Private vars
    
    private var isRightToLeft : Bool {
        return UIApplication.shared.userInterfaceLayoutDirection == .rightToLeft
    }
    
    // Uses an invisible UITextField to handle text
    // this is necessary for iOS12 .oneTimePassword feature
    // Remove textField.inputView = UIView() to fix issue with keyboard
    private var invisibleField: UITextField = {
        let textField = UITextField()
        return textField
    }()
    
    private var invisibleText : String {
        get {
            return invisibleField.text ?? ""
        }
        set {
            self.reloadAppearance()
        }
    }
    
    private var attributes: [NSAttributedString.Key : Any] = [:]
    private var lastEntry: String = ""
    private var currentFocusRange : NSRange?
    private var previousCode : String?
    private var isDynamicLength = false
    private var isAnimating = false
    private var toolbar : UIToolbar?
    
    // MARK: - UIKeyInput
    public override func insertText(_ text: String) {
        self.invisibleField.insertText(text)
    }
    
    public override func deleteBackward() {
        self.invisibleField.deleteBackward()
    }
    
    public override var hasText: Bool {
        return self.invisibleField.hasText
    }
    
    // MARK: - Lifecycle
    
    public override var keyboardAppearance: UIKeyboardAppearance {
        get { return self.invisibleField.keyboardAppearance }
        set { self.invisibleField.keyboardAppearance = newValue}
    }
    
    public override var keyboardType: UIKeyboardType {
        get { return self.invisibleField.keyboardType }
        set { self.invisibleField.keyboardType = newValue}
    }
    
    public override func reloadInputViews() {
        invisibleField.reloadInputViews()
    }
    
    override public func awakeFromNib() {
        super.awakeFromNib()
        self.reload()
    }
        
    // MARK: - Public functions
    
    @discardableResult override public func becomeFirstResponder() -> Bool {
        return self.invisibleField.becomeFirstResponder()
    }
    
    public func animateFailure(_ completion : (() -> Void)? = nil) {
        
        guard !self.isAnimating else {
            return
        }
        
        isAnimating = true
        
        CATransaction.begin()
        CATransaction.setCompletionBlock({
            self.isAnimating = false
            completion?()
            self.reloadAppearance()
        })
        
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.timingFunction = CAMediaTimingFunction.init(name: .linear)
        animation.duration = 0.6
        animation.values = [-14.0, 14.0, -14.0, 14.0, -8.0, 8.0, -4.0, 4.0, 0.0 ]
        layer.add(animation, forKey: "shake")
        
        CATransaction.commit()
    }
        
    // MARK: - Private function
    
    @objc func cancelNumberPad() {
        self.endEditing(true)
    }
    
    @objc func doneWithNumberPad() {
        self.properties.delegate?.pinField(self, didFinishWith: self.invisibleText)
    }
    
    private func reload() {
        // Dynamic length flag
        isDynamicLength = (self.properties.numberOfCharacters == 0)
        
        // Only setup if view showing
        guard self.superview != nil else {
            return
        }
        
        self.endEditing(true)
        if isDynamicLength {
            if self.inputAccessoryView == nil {
                let frame = CGRect(x: 0,
                                   y: 0,
                                   width: UIScreen.main.bounds.width,
                                   height: 50)
                let numberToolbar = UIToolbar(frame: frame)
                numberToolbar.barStyle = .default
                numberToolbar.items = [
                    UIBarButtonItem.init(barButtonSystemItem: .cancel, target: self, action: #selector(cancelNumberPad)),
                    UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
                    UIBarButtonItem.init(barButtonSystemItem: .done, target: self, action: #selector(doneWithNumberPad))
                ]
                numberToolbar.sizeToFit()
                self.inputAccessoryView = numberToolbar
            }
        } else {
            self.inputAccessoryView = nil
        }
        
        // Debugging ---------------
        // Change alpha for easy debug
        let alpha: CGFloat = 0.0
        self.invisibleField.backgroundColor =  UIColor.white.withAlphaComponent(alpha * 0.8)
        self.invisibleField.tintColor = UIColor.black.withAlphaComponent(alpha)
        self.invisibleField.textColor = UIColor.black.withAlphaComponent(alpha)
        // --------------------------
        
        // Prepare `invisibleField`
        self.invisibleField.textAlignment = .center
        self.invisibleField.autocapitalizationType = .none
        self.invisibleField.autocorrectionType = .no
        self.invisibleField.spellCheckingType = .no

        self.invisibleField.keyboardType = self.properties.keyboardType
       
        self.addSubview(self.invisibleField)
        self.invisibleField.addTarget(self, action: #selector(reloadAppearance), for: .allEditingEvents)
        
        // Prepare visible field
        self.tintColor = .clear // Hide cursor
        self.invisibleField.tintColor = .clear // Hide cursor
        self.contentVerticalAlignment = .center
        
        // Delay fixes kerning offset issue
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            self.reloadAppearance()
        }
    }
    
    @objc private func animateFocusedToken() {
        
        guard !isDynamicLength else {
            return
        }
        
        if  let attString = self.attributedText?.mutableCopy() as? NSMutableAttributedString,
            let range = self.currentFocusRange {
            
            var atts = attString.attributes(at: range.location, effectiveRange: nil)
            
            guard let color = atts[.foregroundColor] as? UIColor else {
                return
            }
            let isClear = (color == .clear)
            let duration: Double = isClear ? 0.3 : 0.6
            if isClear{
                atts[.foregroundColor] = self.appearance.tokenFocusColor
            } else {
                atts[.foregroundColor] = UIColor.clear
            }
            attString.setAttributes(atts, range: range)
            
            UIView.transition(with: self, duration: duration, options: [.transitionCrossDissolve, .allowUserInteraction], animations: {
                self.attributedText = attString
            }, completion: nil)
            
        }
    }
    
    // Updates textfield content
    @objc public func reloadAppearance() {
        
        guard !self.isAnimating else {
            return
        }
        
        self.sanitizeText()
        
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        
        let font =  self.appearance.font?.font() ?? self.font ?? UIFont.preferredFont(forTextStyle: .headline)
        self.attributes = [ .paragraphStyle : paragraph,
                            .font : font,
                            .kern : self.appearance.kerning]
        
        if isDynamicLength {
            attributes[.foregroundColor] = self.appearance.textColor
            self.attributedText =  NSAttributedString(string: self.invisibleField.text!, attributes: attributes)
            return
        }
        
        // Display
        let attString = NSMutableAttributedString(string: "")
        let loopStride = isRightToLeft
            ? stride(from: self.properties.numberOfCharacters-1, to: -1, by: -1)
            : stride(from: 0, to: self.properties.numberOfCharacters, by: 1)
        
        for i in loopStride {
            
            var string = ""
            if i < invisibleText.count {
                if self.properties.isSecure {
                    string = String(self.properties.secureToken)
                } else {
                    let index = invisibleText.index(string.startIndex, offsetBy: i)
                    string = String(invisibleText[index])
                }
                
            } else {
                string = String(self.properties.token)
            }

            // Fix kerning-centering
            let indexForKernFix = isRightToLeft ? 0 : self.properties.numberOfCharacters-1
            if i == indexForKernFix {
                attributes[.kern] = 0.0
            }
            
            attString.append(NSAttributedString(string: string, attributes: attributes))
        }
        
        if #available(iOS 11.0, *) {
            self.updateCursorPosition()
        }
        
        guard !self.isAnimating else {
            return
        }
        
        self.attributedText = attString
        
        if invisibleText == self.previousCode {
            return
        }
        self.previousCode = invisibleText
        
        //        self.sizeToFit()
        self.checkCodeValidity()
    }
    
    private func sanitizeText() {
        var text = self.invisibleField.text ?? ""
        
        if properties.isUppercased {
            text = text.uppercased()
        }
        
        if text != lastEntry {
            let isValid = text.reduce(true) { result, char -> Bool in
                return result && self.properties.validCharacters.contains(char)
            }
            if text.count <= self.properties.numberOfCharacters {
                self.properties.delegate?.pinField(self, didChangeTo: text, isValid: isValid)
            }
            
            lastEntry = text
        }
        
        text = String(text.lazy.filter(self.properties.validCharacters.contains))
        
        if !self.isDynamicLength {
            text = String(text.prefix(self.properties.numberOfCharacters))
        }
        
        self.invisibleField.text = text
    }
    
    // Always position cursor on last valid character
    private func updateCursorPosition() {
        self.currentFocusRange = nil
        let offset = min(self.invisibleText.count, self.properties.numberOfCharacters)
        // Only works with a small delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            if let position = self.invisibleField.position(from: self.invisibleField.beginningOfDocument, offset: offset) {
                
                let textRange = self.textRange(from: position, to: position)
                self.invisibleField.selectedTextRange = textRange
                
                // Compute the currently focused element
                if   let attString = self.attributedText?.mutableCopy() as? NSMutableAttributedString,
                    var range = self.invisibleField.selectedRange,
                    range.location >= -1 && range.location < self.properties.numberOfCharacters {
                    
                    // Compute range of focused text
                    if self.isRightToLeft {
                        range.location = self.properties.numberOfCharacters-range.location-1
                    }
                    range.length = 1
                    
                    // Make sure it's a token that is focused
                    let string = attString.string
                    let startIndex = string.index(string.startIndex, offsetBy: range.location)
                    let endIndex = string.index(startIndex, offsetBy: 1)
                    let sub = string[startIndex..<endIndex]
                    if sub == String(self.properties.token) {
                        
                        // Token focus color
                        var atts = attString.attributes(at: range.location, effectiveRange: nil)
                        atts[.foregroundColor] = self.appearance.tokenFocusColor
                        attString.setAttributes(atts, range: range)
                        
                        // Avoid long fade from tick()
                        UIView.transition(with: self, duration: 0.1, options: [.transitionCrossDissolve, .allowUserInteraction], animations: {
                            self.attributedText = attString
                        }, completion: nil)
                        
                        self.currentFocusRange = range
                    }
                }
            }
        }
    }
    
    private func checkCodeValidity() {
        
        guard !self.isAnimating, !self.isDynamicLength else {
            return
        }
        
        if self.invisibleText.count == self.properties.numberOfCharacters {
            if let pinDelegate = self.properties.delegate {
                let result = isRightToLeft ? String(self.invisibleText.reversed()) : self.invisibleText
                pinDelegate.pinField(self, didFinishWith: result)
            } else {
                print("⚠️ : No delegate set for GSPinField. Set it via yourPinField.properties.delegate.")
            }
        }
    }
}

private extension UITextInput {
    var selectedRange: NSRange? {
        guard let range = selectedTextRange else { return nil }
        let location = offset(from: beginningOfDocument, to: range.start)
        let length = offset(from: range.start, to: range.end)
        return NSRange(location: location, length: length)
    }
}

// MARK: - GS_MonospacedFont
// Helper to provide monospaced fonts via literal
public enum GS_MonospacedFont {
    
    case courier(CGFloat)
    case courierBold(CGFloat)
    case courierBoldOblique(CGFloat)
    case courierOblique(CGFloat)
    case courierNewBoldItalic(CGFloat)
    case courierNewBold(CGFloat)
    case courierNewItalic(CGFloat)
    case courierNew(CGFloat)
    case menloBold(CGFloat)
    case menloBoldItalic(CGFloat)
    case menloItalic(CGFloat)
    case menlo(CGFloat)
    
    func font() -> UIFont {
        switch self {
        case .courier(let size) :
            return UIFont(name: "Courier", size: size)!
        case .courierBold(let size) :
            return UIFont(name: "Courier-Bold", size: size)!
        case .courierBoldOblique(let size) :
            return UIFont(name: "Courier-BoldOblique", size: size)!
        case .courierOblique(let size) :
            return UIFont(name: "Courier-Oblique", size: size)!
        case .courierNewBoldItalic(let size) :
            return UIFont(name: "CourierNewPS-BoldItalicMT", size: size)!
        case .courierNewBold(let size) :
            return UIFont(name: "CourierNewPS-BoldMT", size: size)!
        case .courierNewItalic(let size) :
            return UIFont(name: "CourierNewPS-ItalicMT", size: size)!
        case .courierNew(let size) :
            return UIFont(name: "CourierNewPSMT", size: size)!
        case .menloBold(let size) :
            return UIFont(name: "Menlo-Bold", size: size)!
        case .menloBoldItalic(let size) :
            return UIFont(name: "Menlo-BoldItalic", size: size)!
        case .menloItalic(let size) :
            return UIFont(name: "Menlo-Italic", size: size)!
        case .menlo(let size) :
            return UIFont(name: "Menlo-Regular", size: size)!
        }
    }
}
