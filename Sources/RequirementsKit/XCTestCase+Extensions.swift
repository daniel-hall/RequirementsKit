//
//  XCTestCase+Extensions.swift
//  RequirementsKit
//
//  Copyright (c) 2022 - 2023 Daniel Hall (https://danielhall.io)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

import XCTest


public extension XCTestCase {

    func testRequirements(from file: File, statementHandlers: [StatementHandler], matching: LabelExpression? = nil, continueAfterFailure: Bool = false, timeout: TimeInterval = 180, beforeEachExample: ((Requirement.Example) -> Void)? = nil) {
        let runner = RequirementsTestRunner(file: file, statementHandlers: statementHandlers, matching: matching)
        if Thread.isMainThread {
            runner.run(timeout: timeout, continueAfterFailure: continueAfterFailure, beforeEachExample: beforeEachExample)
        } else {
            DispatchQueue.main.async {
                runner.run(timeout: timeout, continueAfterFailure: continueAfterFailure, beforeEachExample: beforeEachExample)
            }
        }
    }

    func testRequirements(from url: URL, statementHandlers: [StatementHandler], matching: LabelExpression? = nil, continueAfterFailure: Bool = false, timeout: TimeInterval = 180, beforeEachExample: ((Requirement.Example) -> Void)? = nil) throws {
        let file = try File.parseFrom(url: url)
        testRequirements(from: file, statementHandlers: statementHandlers, matching: matching, continueAfterFailure: continueAfterFailure, timeout: timeout, beforeEachExample: beforeEachExample)
    }

    func testRequirements(from urls: [URL], statementHandlers: [StatementHandler], matching: LabelExpression? = nil, continueAfterFailure: Bool = false, timeout: TimeInterval = 180, beforeEachExample: ((Requirement.Example) -> Void)? = nil) throws {
        let files = try urls.map { try File.parseFrom(url: $0) }
        let runner = RequirementsTestRunner(files: files, statementHandlers: statementHandlers, matching: matching)
        if Thread.isMainThread {
            runner.run(timeout: timeout, continueAfterFailure: continueAfterFailure, beforeEachExample: beforeEachExample)
        } else {
            DispatchQueue.main.async {
                runner.run(timeout: timeout, continueAfterFailure: continueAfterFailure, beforeEachExample: beforeEachExample)
            }
        }
    }

    func testRequirements(in directory: String? = nil, recursively: Bool = true, statementHandlers: [StatementHandler], matching: LabelExpression? = nil, continueAfterFailure: Bool = false, timeout: TimeInterval = 180, beforeEachExample:  ((Requirement.Example) -> Void)? = nil) throws {
        let bundle = Bundle(for: type(of: self))
        let subdirectoryPath = directory.map { "/\($0)" } ?? ""
        let urls: [URL]
        if !recursively {
            let directoryContents = try FileManager.default.contentsOfDirectory(atPath: bundle.bundlePath.appending(subdirectoryPath))
            urls = directoryContents.compactMap { path in
                if URL(fileURLWithPath: path).pathExtension == "feature" || URL(fileURLWithPath: path).pathExtension == "requirements" {
                    return bundle.bundleURL.appendingPathComponent(subdirectoryPath + "/" + path)
                }
                return nil
            }
        } else {
            let enumerator = FileManager.default.enumerator(atPath: bundle.bundlePath.appending(subdirectoryPath))
            var recursiveURLs: [URL] = []
            while let path = enumerator?.nextObject() as? String {
                if URL(fileURLWithPath: path).pathExtension == "feature" || URL(fileURLWithPath: path).pathExtension == "requirements" {
                    recursiveURLs.append(bundle.bundleURL.appendingPathComponent(subdirectoryPath + "/" + path))
                }
            }
            urls = recursiveURLs
        }
        try testRequirements(from: urls, statementHandlers: statementHandlers, matching: matching, continueAfterFailure: continueAfterFailure, timeout: timeout, beforeEachExample: beforeEachExample)
    }
}


public func waitForAsync(timeout: TimeInterval = 10, closure: @escaping () async throws -> Void) rethrows {
    let expectation = XCTestExpectation(description: "Waiting for async closure")
    Task {
        defer {
            expectation.fulfill()
        }
        do {
            try await closure()
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    XCTWaiter().wait(for: [expectation], timeout: timeout)
}
