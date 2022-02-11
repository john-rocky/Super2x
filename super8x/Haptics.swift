//
//  Haptics.swift
//  super8x
//
//  Created by 間嶋大輔 on 2022/02/12.
//

import Foundation
import CoreHaptics

class Haptics:NSObject {
    var engine: CHHapticEngine?
    lazy var supportsHaptics: Bool = {
        CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }()
    override init() {
        super.init()
        if supportsHaptics {
            createEngine()
        }
        print(supportsHaptics)

    }
    
    func createEngine() {
        do {
            engine = try CHHapticEngine()
        } catch let error {
            fatalError("Engine Creation Error: \(error)")
        }
        
        engine?.stoppedHandler = { reason in
            print("Stop Handler: The engine stopped for reason: \(reason.rawValue)")
            switch reason {
            case .audioSessionInterrupt: print("Audio session interrupt")
            case .applicationSuspended: print("Application suspended")
            case .idleTimeout: print("Idle timeout")
            case .notifyWhenFinished: print("Finished")
            case .systemError: print("System error")
            default:
                print("Unknown error")
            }
        }
        engine?.resetHandler = {
            print("The engine reset --> Restarting now!")
            
            
            do {
                try self.engine?.start()
            } catch let error {
                fatalError("Engine Start Error: \(error)")
            }
        }
        
        do {
            try self.engine?.start()
        } catch let error {
            fatalError("Engine Start Error: \(error)")
        }
    }
    
    func playHapticsFile(_ filename: String){
        if !supportsHaptics {
            return
        }
        
        guard let path = Bundle.main.path(forResource: filename, ofType: "ahap") else {
            return
        }
        do {
            try engine?.start()
            try engine?.playPattern(from: URL(fileURLWithPath: path))
        } catch {
            print("haptics error")
        }
    }
}
