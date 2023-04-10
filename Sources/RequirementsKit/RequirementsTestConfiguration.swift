//
//  RequirementsTestConfiguration.swift
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


public typealias RequirementsTestConfiguration = _RequirementsTestConfigurationBaseClass & RequirementsTestConfigurationProtocol

public protocol RequirementsTestConfigurationProtocol: _RequirementsTestConfigurationBaseClass {
    var statementHandlers: [StatementHandler] { get }
    var matchLabels: LabelExpression? { get }
    var continueAfterFailure: Bool { get }
    var defaultStatementTimeout: TimeInterval { get }

    func setUp(for example: Requirement.Example)
}

public extension RequirementsTestConfigurationProtocol {
    var continueAfterFailure: Bool { false }
    var defaultStatementTimeout: TimeInterval { 180 }
}

@objc open class _RequirementsTestConfigurationBaseClass: NSObject {

    private static var hasRun = false

    required public override init() {
        guard !Self.hasRun else { return }
        Self.hasRun = true
        let bundle = Bundle(for: type(of: self))
        let enumerator = FileManager.default.enumerator(atPath: bundle.bundlePath)
        var recursiveURLs: [URL] = []
        while let path = enumerator?.nextObject() as? String {
            if URL(fileURLWithPath: path).pathExtension == "feature" || URL(fileURLWithPath: path).pathExtension == "requirements" {
                recursiveURLs.append(bundle.bundleURL.appendingPathComponent("/" + path))
            }
        }
        if let files = try? recursiveURLs.map({ try File.parseFrom(url: $0) }) {
            guard let config = Self.init() as? RequirementsTestConfiguration else {
                fatalError("\(Self.self) must conform to the RequirementsTestConfigurationProtocol")
            }
            let filtered = files.filter { $0.requirements.map { $0.examples }.joined().filter { config.matchLabels?.matches($0.labels) != false }.count > 0 }

            filtered.forEach { file in
                let name = (file.description ?? file.name).cleanedUp()
                if let testCase = objc_allocateClassPair(XCTestCase.self, name, 0), let fileConfig = Self.init() as? RequirementsTestConfiguration {
                    file.requirements.forEach { requirement in
                        let block: @convention(block) () -> Void = {
                            let runner = RequirementTestRunner(file: file, requirement: requirement,  statementHandlers: fileConfig.statementHandlers, matchLabels: fileConfig.matchLabels)
                            let task: () -> Void = {
                                runner.run(timeout: fileConfig.defaultStatementTimeout, continueAfterFailure: fileConfig.continueAfterFailure, beforeEachExample: { fileConfig.setUp(for: $0) })
                            }
                            if Thread.isMainThread { task() }
                            else { DispatchQueue.main.async(execute: task) }
                        }
                        let imp = imp_implementationWithBlock(unsafeBitCast(block, to: AnyObject.self))
                        let name = "test" + requirement.description.cleanedUp()
                        class_addMethod(testCase, Selector(name), imp, "v@:")
                    }
                    objc_registerClassPair(testCase)
                }
            }
        }
    }
}

private extension String {
    func cleanedUp() -> String {
        let firstLine = String(self.split(separator: "\n").first ?? "")
        let camelCased = firstLine.split(separator: " ").map { String($0.first ?? Character("")).capitalized + $0.dropFirst() }.joined()
        let validCharacters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"
        let invalidRemoved = String(camelCased.compactMap { validCharacters.contains($0) ? $0 : nil })
        let leadingFix = "0123456789".contains(invalidRemoved.first ?? Character("")) ?
        String(invalidRemoved.dropFirst().first ?? Character("")).capitalized + invalidRemoved.dropFirst(2) : invalidRemoved
        return String(leadingFix.prefix(100))
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
