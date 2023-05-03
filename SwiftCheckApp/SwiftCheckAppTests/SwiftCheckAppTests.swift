//
//  SwiftCheckAppTests.swift
//  SwiftCheckAppTests
//
//  Created by Tommy Ngo on 5/1/23.
//

import XCTest
import SwiftCheck
import Foundation

@testable import SwiftCheckApp

final class SwiftCheckAppTests: XCTestCase {
    
    struct Function {
        let name: String
        let parameters: String
        let returnType: String
    }
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
    }
    
    func testGeneratedFunctionCompilesSuccessfully() {
        let function = Function(name: "foo", parameters: "x: Int, y: Int", returnType: "Int")
        
        let code = """
        func \(function.name)(\(function.parameters)) -> \(function.returnType) {
            return x + y
        }
        """
        
        // Create a Swift source code file.
        let fileName = "MyFunction.swift"
        let filePath = FileManager.default.currentDirectoryPath + "/" + fileName
        try? FileManager.default.removeItem(atPath: filePath) // Remove existing file if any
        try? code.write(toFile: filePath, atomically: true, encoding: .utf8)
        
        // Compile the source code file.
        let task = NSProcess()
        task.launchPath = "/usr/bin/env"
        task.arguments = ["swiftc", fileName]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        task.waitUntilExit()
        let status = task.terminationStatus
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if status == 0 {
            XCTAssertNil(output, "Expected no output from successful compilation.")
        } else {
            XCTFail("Compilation failed with status \(status).\nOutput: \(output ?? "")")
        }
    }
    
    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
}
