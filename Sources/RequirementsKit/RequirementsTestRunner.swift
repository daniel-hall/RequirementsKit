//
//  RequirementsTestRunner.swift
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


class RequirementsTestRunner: NSObject, XCTestObservation {
    private static var current: RequirementsTestRunner?
    public var timeout: TimeInterval = 180
    public var files: [File]
    public var hasFailed = false
    public var continueAfterFailure = false
    public let labels: LabelExpression?
    private let statementHandlers: [StatementHandler]
    private var beforeEachExample: ((Requirement.Example) -> Void)?
    private var timeoutDispatchWorkItem: DispatchWorkItem?

    init(file: File, statementHandlers: [StatementHandler], matching: LabelExpression? = nil) {
        self.files = [file]
        self.statementHandlers = statementHandlers
        self.labels = matching
    }

    init(files: [File], statementHandlers: [StatementHandler], matching: LabelExpression? = nil) {
        self.files = files
        self.statementHandlers = statementHandlers
        self.labels = matching
    }

    func testCase(_ testCase: XCTestCase, didFailWithDescription description: String, inFile filePath: String?, atLine lineNumber: Int) {
        if !continueAfterFailure {
            hasFailed = true
        }
    }

    func run(timeout: TimeInterval = 180, continueAfterFailure: Bool = false, beforeEachExample: ((Requirement.Example) -> Void)? = nil) {
        guard Self.current == nil else { fatalError("Can't start running a RequirementsTestRunner when there is already one running") }
        Self.current = self

        self.timeout = timeout
        self.hasFailed = false
        self.continueAfterFailure = true
        self.beforeEachExample = beforeEachExample

        XCTestObservationCenter.shared.addTestObserver(self)

        files.forEach {
            let file = $0
            XCTContext.runActivity(named: file.activity) { _ in
                for requirement in file.requirements {
                    guard !self.hasFailed || continueAfterFailure else { break }
                    XCTContext.runActivity(named: requirement.activity(syntax: file.syntax)) { _ in
                        for example in requirement.examples {
                            guard !self.hasFailed || continueAfterFailure else { break }
                            if let labels {
                                if !labels.matches(example.labels) {
                                    XCTContext.runActivity(named: "[SKIPPED] " + example.activity(syntax: file.syntax)) { _ in }
                                    continue
                                }
                            }
                            XCTContext.runActivity(named: example.activity(syntax: file.syntax)) { _ in
                                self.beforeEachExample?(example)
                                for statement in example.statements {
                                    guard !self.hasFailed || continueAfterFailure else { break }
                                    XCTContext.runActivity(named: statement.activity(syntax: file.syntax)) { _ in
                                        let matches = self.statementHandlers.filter { $0.type == statement.type && $0.getMatch(statement) != nil }
                                        if matches.isEmpty {
                                            XCTFail("No StatementHandler provided for the statement '\(statement.activity(syntax: file.syntax))'")
                                            if !continueAfterFailure {
                                                hasFailed = true
                                            }
                                        } else if matches.count > 1 {
                                            XCTFail("Multiple matching StatementHandlers provided for the statement '\(statement.activity(syntax: file.syntax))'")
                                            if !continueAfterFailure {
                                                hasFailed = true
                                            }
                                        } else {
                                            do {
                                                let timeoutWorkItem = DispatchWorkItem {
                                                    XCTFail("Statement timed out after \(matches.first?.timeout ?? self.timeout) seconds")
                                                }
                                                self.timeoutDispatchWorkItem?.cancel()
                                                self.timeoutDispatchWorkItem = timeoutWorkItem
                                                DispatchQueue.global().asyncAfter(deadline: .now() + (matches.first?.timeout ?? self.timeout), execute: timeoutWorkItem)
                                                try matches.first?.action(matches.first?.getMatch(statement))
                                            } catch {
                                                XCTFail(error.localizedDescription)
                                                if !continueAfterFailure {
                                                    hasFailed = true
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

fileprivate extension File {
    var activity: String {
        syntax == .gherkin ? "Feature: \(description ?? name)" : "File: \(name)"
    }
}

fileprivate extension Requirement {
    func activity(syntax: File.Syntax) -> String {
        (syntax == .gherkin ? "Rule: " : "Requirement: ") + description
    }
}

fileprivate extension Requirement.Example {
    func activity(syntax: File.Syntax) -> String {
        "Example: \(description ?? "")"
    }
}

fileprivate extension Requirement.Example.Statement {
    func activity(syntax: File.Syntax) -> String {
        type.activity(syntax: syntax) + description
    }
}

fileprivate extension Requirement.Example.StatementType {
    func activity(syntax: File.Syntax) -> String {
        switch self {
        case .if: return syntax == .gherkin ? "Given " : "If: "
        case .when: return syntax == .gherkin ? "When " : "When: "
        case .expect: return syntax == .gherkin ? "Then " : "Expect: "
        }
    }
}
