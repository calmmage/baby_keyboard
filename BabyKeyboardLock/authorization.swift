//
//  authorization.swift
//  BabyKeyboardLock
//
//  Created by Fangxing Xiong on 19.12.2024.
//
//
import Foundation
import Cocoa

class AccessibilityAuthorization {
    
    private var accessibilityWindowController: NSWindowController?
    
    public func checkAccessibility(completion: @escaping () -> Void) -> Bool {
        if !AXIsProcessTrusted() {
            
            accessibilityWindowController = NSStoryboard(name: "Main", bundle: nil).instantiateController(withIdentifier: "AccessibilityWindowController") as? NSWindowController
            
            NSApp.activate(ignoringOtherApps: true)
            accessibilityWindowController?.showWindow(self)
            pollAccessibility(completion: completion)
            return false
        } else {
            return true
        }
    }
    
    private func pollAccessibility(completion: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if AXIsProcessTrusted() {
                self.accessibilityWindowController?.close()
                self.accessibilityWindowController = nil
                completion()
            } else {
                self.pollAccessibility(completion: completion)
            }
        }
    }
    
    func showAuthorizationWindow() {
        if accessibilityWindowController?.window?.isMiniaturized == true {
            accessibilityWindowController?.window?.deminiaturize(self)
        }
        NSApp.activate(ignoringOtherApps: true)
    }
    
}
