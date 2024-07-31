//
//  utils.swift
//  monitor-changer
//
//  Created by Selmir Nedzibi on 31. 7. 24.
//

import Foundation

func runShellCommand(_ command: String, arguments: [String] = []) -> String {
    let process = Process()
    
    process.executableURL = URL(fileURLWithPath: command)
    process.arguments = arguments

    let pipe = Pipe()
    process.standardOutput = pipe

    do {
        try process.run()
        process.waitUntilExit()
    } catch {
        print("Error running command: \(error.localizedDescription)")
        return ""
    }

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8) ?? ""
}
