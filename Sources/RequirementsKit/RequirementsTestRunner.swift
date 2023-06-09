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


class RequirementTestRunner: NSObject, XCTestObservation {
    var file: File
    var requirement: Requirement
    var hasFailed = false
    var continueAfterFailure = false
    var setupActive = false
    var currentStatement: Requirement.Example.Statement?
    var shouldDisplayFailuresOnRequirement: Bool = true
    let matchLabels: LabelExpression?
    let statementHandlers: [StatementHandler]
    var beforeEachExample: ((Requirement.Example) -> Void)?
    var timeoutDispatchWorkItem: DispatchWorkItem?

    init(file: File, requirement: Requirement, statementHandlers: [StatementHandler], matchLabels: LabelExpression? = nil) {
        self.file = file
        self.requirement = requirement
        self.statementHandlers = statementHandlers
        self.matchLabels = matchLabels
    }

    func testCase(_ testCase: XCTestCase, didFailWithDescription description: String, inFile filePath: String?, atLine lineNumber: Int) {
        if !continueAfterFailure {
            hasFailed = true
        }
    }

    func run(timeout: TimeInterval = 180, continueAfterFailure: Bool = false, shouldDisplayErrorsOnRequirement: Bool = true, beforeEachExample: ((Requirement.Example) -> Void)? = nil) {
        self.hasFailed = false
        self.continueAfterFailure = true
        self.shouldDisplayFailuresOnRequirement = shouldDisplayErrorsOnRequirement
        self.beforeEachExample = beforeEachExample

        XCTestObservationCenter.shared.addTestObserver(self)
        for example in requirement.examples {
            guard !self.hasFailed || continueAfterFailure else { break }
            if let matchLabels {
                if !matchLabels.matches(example.labels) {
                    XCTContext.runActivity(named: "[SKIPPED] " + example.activity(syntax: file.syntax)) { _ in }
                    continue
                }
            }
            XCTContext.runActivity(named: "💡 " + example.activity(syntax: file.syntax)) { _ in
                self.beforeEachExample?(example)
                let setups = statementHandlers.filter { $0.setup != nil }
                setups.forEach { handler in
                    if let match = example.statements.first(where: {
                        $0.type == handler.type && handler.getMatch($0) != nil
                    }) {
                        currentStatement = match
                        setupActive = true
                        defer { setupActive = false }
                        do {
                            let timeoutWorkItem = DispatchWorkItem {
                                XCTFail("Statement setup timed out after \(handler.timeout ?? timeout) seconds")
                            }
                            self.timeoutDispatchWorkItem?.cancel()
                            self.timeoutDispatchWorkItem = timeoutWorkItem
                            DispatchQueue.global().asyncAfter(deadline: .now() + (handler.timeout ?? timeout), execute: timeoutWorkItem)
                            try handler.setup?(handler.getMatch(match))
                        } catch {
                            XCTFail(error.localizedDescription)
                            if !continueAfterFailure {
                                hasFailed = true
                            }
                        }
                    }
                }
                for statement in example.statements {
                    guard !self.hasFailed || continueAfterFailure else { break }
                    currentStatement = statement
                    XCTContext.runActivity(named: "❇️ " + statement.activity(syntax: file.syntax)) { _ in
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
                                    XCTFail("Statement timed out after \(matches.first?.timeout ?? timeout) seconds")
                                }
                                self.timeoutDispatchWorkItem?.cancel()
                                self.timeoutDispatchWorkItem = timeoutWorkItem
                                DispatchQueue.global().asyncAfter(deadline: .now() + (matches.first?.timeout ?? timeout), execute: timeoutWorkItem)
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
