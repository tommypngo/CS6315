//
//  ViewController.swift
//  SwiftAutoDetectError
//
//  Created by Tommy Ngo on 5/2/23.
//

import Cocoa
import Foundation
import Swift
import SwiftSyntax

struct Function {
    let name: String
    let parameters: String
    let returnType: String
}

class ViewController: NSViewController {
    
    private var directoryPicker: NSOpenPanel?
    
    @IBOutlet weak var directoryLabel: NSTextField!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }

    @IBAction func selectDirectoryTapped(_ sender: Any) {
        let directoryPicker = NSOpenPanel()
        directoryPicker.title = "Choose a directory"
        directoryPicker.canChooseDirectories = true
        directoryPicker.canChooseFiles = false
        directoryPicker.allowsMultipleSelection = false
        directoryPicker.directoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        directoryPicker.begin { [weak self] (result) in
            guard result == .OK, let url = directoryPicker.urls.first else {
                return
            }
            self?.directoryLabel.stringValue = url.path
            self?.loadAndCompileFilesInFolder(at: url, in: self.view.window!)
        }
        self.directoryPicker = directoryPicker
    }
    
    func extractFunctions(from sourceCode: String) throws -> [Function] {
        let tree = try SyntaxParser.parse(source: sourceCode)
        var functions = [Function]()
        for topLevelDecl in tree.topLevelDecls {
            if let functionDecl = topLevelDecl.as(FunctionDeclSyntax.self) {
                let functionName = functionDecl.identifier.text
                let parameterList = functionDecl.signature.input
                let parameterTypes = parameterList.map { $0.typeAnnotation!.type.description.trimmingCharacters(in: .whitespaces) }
                let returnType = functionDecl.signature.output?.returnType.description.trimmingCharacters(in: .whitespaces) ?? "Void"
                let function = Function(name: functionName, parameters: parameterTypes.joined(separator: ", "), returnType: returnType)
                functions.append(function)
            }
        }
        return functions
    }
    
    func loadAndCompileFilesInFolder(at folderURL: URL, in window: NSWindow) {
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)
            let swiftFileURLs = fileURLs.filter { $0.pathExtension == "swift" }
            for swiftFileURL in swiftFileURLs {
                let sourceCode = try String(contentsOf: swiftFileURL)
                let functions = try extractFunctions(from: sourceCode)
                for function in functions {
                    let code = """
                func \(function.name)(\(function.parameters)) -> \(function.returnType) {
                    // Generate random Swift code for the function body.
                }
                """
                    do {
                        try compileAndEval(code: code)
                    } catch {
                        let alert = NSAlert()
                        alert.messageText = "Error compiling function '\(function.name)' in file '\(swiftFileURL.lastPathComponent)'"
                        alert.informativeText = "\(error)"
                        alert.alertStyle = .critical
                        alert.beginSheetModal(for: window, completionHandler: nil)
                    }
                }
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Error loading files in folder"
            alert.informativeText = "\(error)"
            alert.alertStyle = .critical
            alert.beginSheetModal(for: window, completionHandler: nil)
        }
    }
    

//    func loadSwiftFilesAndTestFunctions(directory: URL, functionTemplate: Function) {
//        let fileManager = FileManager.default
//        let swiftFiles = fileManager.enumerator(atPath: directory.path)?.compactMap { $0 as? String }.filter { $0.hasSuffix(".swift") } ?? []
//        let regex = try? NSRegularExpression(pattern: "func\\s+([^(]+)\\(([^)]*)\\)\\s*->\\s*([^\\s{]+)")
//        var failedFiles = [String]()
//        for fileName in swiftFiles {
//            let fileURL = directory.appendingPathComponent(fileName)
//            guard let fileContents = try? String(contentsOf: fileURL, encoding: .utf8) else {
//                continue
//            }
//            let matches = regex?.matches(in: fileContents, range: NSRange(fileContents.startIndex..., in: fileContents)) ?? []
//            for match in matches {
//                let nameRange = Range(match.range(at: 1), in: fileContents)!
//                let name = String(fileContents[nameRange])
//                let parametersRange = Range(match.range(at: 2), in: fileContents)!
//                let parameters = String(fileContents[parametersRange])
//                let returnTypeRange = Range(match.range(at: 3), in: fileContents)!
//                let returnType = String(fileContents[returnTypeRange])
//                let function = Function(name: name, parameters: parameters, returnType: returnType)
//                let code = """
//                func \(function.name)(\(function.parameters)) -> \(function.returnType) {
//                    return 0
//                }
//                """
//                let tempFileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("temp.swift")
//                try? code.write(to: tempFileURL, atomically: true, encoding: .utf8)
//                let task = Process()
//                task.launchPath = "/usr/bin/env"
//                task.arguments = ["swiftc", tempFileURL.path]
//                task.launch()
//                task.waitUntilExit()
//                let status = task.terminationStatus
//                if status != 0 {
//                    failedFiles.append(fileName)
//                    break
//                }
//            }
//        }
//        if failedFiles.isEmpty {
//            print("All function definitions compiled successfully.")
//        } else {
//            print("The following files contain function definitions that failed to compile: \(failedFiles)")
//        }
//    }
}

