//
//  ViewController.swift
//  GSPinField
//
//  Created by Gaganjot Singh on 15/02/2023.
//  Copyright © 2018 Gaganjot Singh. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    @IBOutlet var secureSwitch: UISwitch!
    @IBOutlet var secureLabel: UILabel!
    @IBOutlet var targetCodeLabel: UILabel!
    @IBOutlet var pinField: GSPinField!
    @IBOutlet var refreshButton: UIButton!
        
    private var targetCode = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // -- Properties --
        self.setupPinfield()
        refresh()
        // Get focus
        pinField.becomeFirstResponder()
    }
    
    
    func randomCode(numDigits: Int) -> String {
        var string = ""
        for _ in 0..<numDigits {
            string += String(Int.random(in: 0...9))
        }
        return string
    }
    
    @IBAction func setupPinfield() {
        
        // Random numberOfCharacters
        pinField.text = ""
        
        pinField.updateProperties { properties in
            properties.numberOfCharacters = 6
            properties.delegate = self
        }
        
        // Random target code
        targetCode = self.randomCode(numDigits: pinField.properties.numberOfCharacters)
        targetCodeLabel.text = "Code : \(targetCode)"
        UIPasteboard.general.string = targetCode
        
//        self.refresh()
    }
    
    @IBAction func toggleSecure() {
        self.refresh()
        self.pinField.becomeFirstResponder()
    }
    
    func refresh() {
        self.targetCodeLabel.textColor = UIColor.label.withAlphaComponent(0.8)
        
        pinField.updateProperties { properties in
            properties.isSecure = self.secureSwitch.isOn
            properties.token = "◦"
            properties.isUppercased = false
            properties.validCharacters = "1234567890"
        }
        
        pinField.updateAppearence { appearance in
            appearance.tokenColor = UIColor.label
            appearance.tokenFocusColor = UIColor.label
            appearance.textColor = UIColor.label
            appearance.font = .menlo(40)
            appearance.kerning = 24
        }
    }
}

// MARK: - GSPinFieldDelegate
extension ViewController: GSPinFieldDelegate {
    func pinField(_ field: GSPinField, didChangeTo string: String, isValid: Bool) {
        if isValid {
            print("Valid input: \(string) ")
        } else {
            print("Invalid input: \(string) ")
            self.pinField.animateFailure()
        }
    }
    
    func pinField(_ field: GSPinField, didFinishWith code: String) {
        print("didFinishWith: \(code)")
        if code != targetCode {
            print("Failure")
            field.animateFailure()
        } else {
            print("Success")
        }
    }
}
