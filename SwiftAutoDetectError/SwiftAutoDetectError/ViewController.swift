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
import SwiftSyntaxParser

import Cocoa
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
            self?.loadAndCompileFilesInFolder(at: url, in: (self?.view.window!)!)
        }
        self.directoryPicker = directoryPicker
    }
    
    func extractFunctions(from sourceCode: String) throws -> [Function] {
        let tree = try SyntaxParser.parse(source: sourceCode)
        var functions = [Function]()
        for statement in tree.statements {
            if let functionDecl = statement.item.as(FunctionDeclSyntax.self) {
                let functionName = functionDecl.identifier.text
                let parameterList = functionDecl.signature.input.parameterList
                let parameterTypes: [String] = []
                
                parameterList.forEach { param in
                }
                let returnType = functionDecl.signature.output?.returnType.description.trimmingCharacters(in: .whitespaces) ?? "Void"
                let function = Function(name: functionName,
                                        parameters: parameterTypes.joined(separator: ", "),
                                        returnType: returnType)
                functions.append(function)
            }
        }
        return functions
    }
    
    func compileCode(_ code: String) -> String {
        let task = Process()
        task.launchPath = "/usr/bin/env"
        task.arguments = ["xcrun", "swiftc", "-"]
        let pipe = Pipe()
        task.standardInput = FileHandle(forReadingAtPath: "/dev/null")
        task.standardOutput = pipe
        task.standardError = pipe
        task.launch()
        let input = code.data(using: .utf8)!
        let inputHandle = task.standardInput as! FileHandle // Cast to NSFileHandle
        inputHandle.write(input)
        inputHandle.closeFile()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)!
        task.waitUntilExit()
        let status = task.terminationStatus
        if status == 0 {
            return output
        } else {
            return "Compilation failed with status \(status):\n\(output)"
        }
    }
    
    func compileAndEval(code: String) throws {
        let moduleName = "DynamicModule"
        let functionName = "dynamicFunction"
        
        // Define the dynamic module and function
        let moduleCode = """
        import Foundation
        @_cdecl("\(functionName)") func \(functionName)() -> Void {
            \(code)
        }
        """
        
        // Start a Swift REPL process
        let process = Process()
        process.launchPath = "/usr/bin/swift"
        process.arguments = ["-v", "-target", "x86_64-apple-macosx10.15", "-module-name", moduleName]
        
        // Create pipes to read and write to the process
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        
        // Start the process and wait for it to initialize
        process.launch()
        let initOutputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let initOutput = String(data: initOutputData, encoding: .utf8)!
        guard initOutput.contains("Welcome to Swift") else {
            throw NSError(domain: "com.example.compileAndEval", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to start Swift REPL."])
        }
        
        // Define the module and function in the REPL
        inputPipe.fileHandleForWriting.write(Data(moduleCode.utf8))
        inputPipe.fileHandleForWriting.write(Data("\n".utf8))
        inputPipe.fileHandleForWriting.write(Data("\(functionName)()\n".utf8))
        inputPipe.fileHandleForWriting.write(Data(":quit\n".utf8))
        inputPipe.fileHandleForWriting.closeFile()
        
        // Wait for the process to finish and check the result
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8)!
            throw NSError(domain: "com.example.compileAndEval", code: 2, userInfo: [NSLocalizedDescriptionKey: "Swift REPL failed with status \(process.terminationStatus): \(output)"])
        }
    }

    
    func loadAndCompileFilesInFolder(at folderURL: URL, in window: NSWindow) {
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)
            let swiftFileURLs = fileURLs.filter { $0.pathExtension == "swift" }
            var failedFiles = [String]()
            for swiftFileURL in swiftFileURLs {
                let sourceCode = try String(contentsOf: swiftFileURL)
                
                let tempFileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("temp.swift")
                try? sourceCode.write(to: tempFileURL, atomically: true, encoding: .utf8)
                let task = Process()
                task.launchPath = "/usr/bin/env"
                task.arguments = ["swiftc", tempFileURL.path]
                
                let pipe = Pipe()
                task.standardError = pipe
                
                task.launch()
                task.waitUntilExit()
                
                let status = task.terminationStatus
                if status != 0 {
                    failedFiles.append(tempFileURL.absoluteString)
                    let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
                    if let errorString = String(data: errorData, encoding: .utf8) {
                        print("Compilation error: \(errorString)")
                    } else {
                        print("Unknown compilation error")
                    }
                    break
                }
                
//                let sourceCode = try String(contentsOf: swiftFileURL)
//                let functions = try extractFunctions(from: sourceCode)
//                for function in functions {
//                    let code = """
//                func \(function.name)(\(function.parameters)) -> \(function.returnType) {
//                    // Generate random Swift code for the function body.
//                }
//                """
//                    do {
//                        try compileAndEval(code: code)
//                    } catch {
//                        let alert = NSAlert()
//                        alert.messageText = "Error compiling function '\(function.name)' in file '\(swiftFileURL.lastPathComponent)'"
//                        alert.informativeText = "\(error)"
//                        alert.alertStyle = .critical
//                        alert.beginSheetModal(for: window, completionHandler: nil)
//                    }
//                }
            }
            
            if failedFiles.isEmpty {
                let text = "All function definitions compiled successfully."
                print(text)
                
                let alert = NSAlert()
                alert.messageText = "Successfull"
                alert.informativeText = text
                alert.alertStyle = .critical
                alert.beginSheetModal(for: window, completionHandler: nil)
                
            } else {
                let text = "The following files contain function definitions that failed to compile: \(failedFiles)"
                print(text)
                let alert = NSAlert()
                alert.messageText = "Failed"
                alert.informativeText = text
                alert.alertStyle = .critical
                alert.beginSheetModal(for: window, completionHandler: nil)
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Error loading files in folder"
            alert.informativeText = "\(error)"
            alert.alertStyle = .critical
            alert.beginSheetModal(for: window, completionHandler: nil)
        }
    }
    
    
//    func loadAndCompileFilesInFolder(at directory: URL, in window: NSWindow) {
//        let fileManager = FileManager.default
//        let swiftFiles = fileManager.enumerator(atPath: directory.path)?.compactMap { $0 as? String }.filter { $0.hasSuffix(".swift") } ?? []
//        let regex = try? NSRegularExpression(pattern: "func\\s+([^(]+)\\(([^)]*)\\)\\s*->\\s*([^\\s{]+)")
//        var failedFiles = [String]()
//        for fileName in swiftFiles {
//            let fileURL = directory.appendingPathComponent(fileName)
//            guard let fileContents = try? String(contentsOf: fileURL, encoding: .utf8) else {
//                continue
//            }
//
//            let alert = NSAlert()
//            alert.messageText = "Result"
//            alert.informativeText = compileCode(fileContents)
//            alert.alertStyle = .critical
//            alert.beginSheetModal(for: window, completionHandler: nil)
//
//
////            let matches = regex?.matches(in: fileContents, range: NSRange(fileContents.startIndex..., in: fileContents)) ?? []
////            for match in matches {
////                let nameRange = Range(match.range(at: 1), in: fileContents)!
////                let name = String(fileContents[nameRange])
////                let parametersRange = Range(match.range(at: 2), in: fileContents)!
////                let parameters = String(fileContents[parametersRange])
////                let returnTypeRange = Range(match.range(at: 3), in: fileContents)!
////                let returnType = String(fileContents[returnTypeRange])
////                let function = Function(name: name, parameters: parameters, returnType: returnType)
////                let code = """
////                        func \(function.name)(\(function.parameters)) -> \(function.returnType) {
////                            return 0
////                        }
////                        """
////                let tempFileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("temp.swift")
////                try? code.write(to: tempFileURL, atomically: true, encoding: .utf8)
////                let task = Process()
////                task.launchPath = "/usr/bin/env"
////                task.arguments = ["swiftc", tempFileURL.path]
////                task.launch()
////                task.waitUntilExit()
////                let status = task.terminationStatus
////                if status != 0 {
////                    failedFiles.append(fileName)
////                    break
////                }
////            }
//        }
//        if failedFiles.isEmpty {
//            print("All function definitions compiled successfully.")
//
//            let alert = NSAlert()
//            alert.messageText = "Successfully."
//            alert.informativeText = "All function definitions compiled successfully."
//            alert.alertStyle = .critical
//            alert.beginSheetModal(for: window, completionHandler: nil)
//
//        } else {
//            print("The following files contain function definitions that failed to compile: \(failedFiles)")
//
//            let alert = NSAlert()
//            alert.messageText = "Failed"
//            alert.informativeText = "The following files contain function definitions that failed to compile: \(failedFiles)"
//            alert.alertStyle = .critical
//            alert.beginSheetModal(for: window, completionHandler: nil)
//
//        }
//
//
//
////        do {
////            let fileURLs = try FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)
////            let swiftFileURLs = fileURLs.filter { $0.pathExtension == "swift" }
////            for swiftFileURL in swiftFileURLs {
////                let sourceCode = try String(contentsOf: swiftFileURL)
//////                let functions = try extractFunctions(from: sourceCode)
//////                for function in functions {
//////                    let code = """
//////                func \(function.name)(\(function.parameters)) -> \(function.returnType) {
//////                    // Generate random Swift code for the function body.
//////                }
//////                """
//////                    do {
//////                        //try compileAndEval(code: code)
//////                    } catch {
//////                        let alert = NSAlert()
//////                        alert.messageText = "Error compiling function '\(function.name)' in file '\(swiftFileURL.lastPathComponent)'"
//////                        alert.informativeText = "\(error)"
//////                        alert.alertStyle = .critical
//////                        alert.beginSheetModal(for: window, completionHandler: nil)
//////                    }
//////                }
////
////                let tempFileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("temp.swift")
////                try? sourceCode.write(to: tempFileURL, atomically: true, encoding: .utf8)
////                let task = Process()
////                task.launchPath = "/usr/bin/env"
////                task.arguments = ["swiftc", tempFileURL.path]
////                task.launch()
////                task.waitUntilExit()
////                let status = task.terminationStatus
////                if status != 0 {
////                    failedFiles.append(fileName)
////                    break
////                }
////            }
////        } catch {
////            let alert = NSAlert()
////            alert.messageText = "Error loading files in folder"
////            alert.informativeText = "\(error)"
////            alert.alertStyle = .critical
////            alert.beginSheetModal(for: window, completionHandler: nil)
////        }
//    }
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


class MySyntaxVisitor: SyntaxVisitor {
    let diagnosticEngine: DiagnosticEngine
    
    init(diagnosticEngine: DiagnosticEngine) {
        self.diagnosticEngine = diagnosticEngine
    }
    
    override func visit(_ node: Syntax) {
        // Check for build errors here and add diagnostic messages to the diagnostic engine
        if let tokenNode = node as? TokenSyntax {
            if tokenNode.tokenKind == .unknown {
                diagnosticEngine.diagnose(.init(
                    severity: .error,
                    location: .init(file: tokenNode.sourceLocation.file,
                                    line: tokenNode.sourceLocation.line),
                    message: "Unexpected token: '\(tokenNode.text)'"))
            }
        }
        // Continue traversal
        super.visit(node)
    }
}

class DiagnosticEngine {
    var diagnostics: [Diagnostic] = []
    
    func diagnose(_ diagnostic: Diagnostic) {
        diagnostics.append(diagnostic)
    }
}

struct Diagnostic: CustomStringConvertible {
    let severity: DiagnosticSeverity
    let location: SourceLocation
    let message: String
    
    var description: String {
        return "\(severity.rawValue) \(location): error: \(message)"
    }
}

enum DiagnosticSeverity: String {
    case error
    case warning
    case note
}
