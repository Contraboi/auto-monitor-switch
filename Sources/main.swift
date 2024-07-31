//
//  main.swift
//  monitor-changer
//
//  Created by Selmir Nedzibi on 30. 7. 24.
//

import ArgumentParser
import IOKit
import Foundation

let RUN_ON = ["add", "remove"]
let runOnString = RUN_ON.joined(separator: ", ")

struct Ams: ParsableCommand {
    @Argument var name: String
    
    @Option(name: .shortAndLong, help: "Run on effect: \(runOnString)")
    var runOn: String
    
    @Option(name: .shortAndLong, help: "Monitor id, input id")
    var values: [String]
    
    func run() throws {
        var example = usbDelegate(name: name, effect: runOn, values: values)
        CFRunLoopRun()
    }

    func validate() throws {
        if !RUN_ON.contains(runOn) {
            throw ValidationError("Accepted run ons are \(runOnString)). Your input: \(runOn)")
        }
    }
}

Ams.main()
