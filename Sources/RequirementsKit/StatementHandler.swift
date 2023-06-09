//
//  StatementHandler.swift
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

import Foundation


public struct StatementHandler {

    public struct Input<Match> {
        public let statement: Requirement.Example.Statement
        public let match: Match
    }

    let type: Requirement.Example.StatementType
    let timeout: TimeInterval?
    let getMatch: (Requirement.Example.Statement) -> Any?
    let action: (Any?) throws -> Void
    let setup: ((Any?) throws -> Void)?

    fileprivate init<T>(statementType: Requirement.Example.StatementType, statement: Regex<T>, timeout: TimeInterval?, handler: @escaping (Input<T>) throws -> Void, setup: ((Input<T>) throws -> Void)?) {
        type = statementType
        getMatch = { exampleStatement in
            exampleStatement.description.wholeMatch(of: statement).map { Input(statement: exampleStatement, match: $0.output) }
        }
        self.action = { try handler($0 as! Input<T>) }
        self.timeout = timeout
        self.setup = { try setup?($0 as! Input<T>) }
    }

    fileprivate init(statementType: Requirement.Example.StatementType, statement: [String], timeout: TimeInterval?, handler: @escaping (Input<AnyRegexOutput>) throws -> Void, setup: ((Input<AnyRegexOutput>) throws -> Void)?) {
        type = statementType
        getMatch = { exampleStatement in

            exampleStatement.description.wholeMatch(of: try! Regex("(" + statement.joined(separator: "|") + ")")).map { Input(statement: exampleStatement, match: AnyRegexOutput($0)) }
        }
        self.action = { try handler($0 as! Input<AnyRegexOutput>) }
        self.timeout = timeout
        self.setup = { try setup?($0 as! Input<AnyRegexOutput>) }
    }
}

public extension StatementHandler {

    // MARK: - if -

    static func `if`<T>(_ statement: Regex<T>, timeout: TimeInterval? = nil, handler: @escaping (Input<T>) throws -> Void) -> StatementHandler {
        .init(statementType: .if, statement: statement, timeout: timeout, handler: handler, setup: nil)
    }
    static func `if`(_ statement: String..., timeout: TimeInterval? = nil, handler: @escaping (Input<AnyRegexOutput>) throws -> Void) -> StatementHandler {
        .init(statementType: .if, statement: statement, timeout: timeout, handler: handler, setup: nil)
    }
    static func `if`(_ statement: String..., timeout: TimeInterval? = nil, handler: @escaping () throws -> Void) -> StatementHandler {
        .init(statementType: .if, statement: statement, timeout: timeout, handler: { _ in try handler() }, setup: nil)
    }

    // MARK: - given -

    static func given<T>(_ statement: Regex<T>, timeout: TimeInterval? = nil, handler: @escaping (Input<T>) throws -> Void) -> StatementHandler {
        .if(statement, timeout: timeout, handler: handler)
    }
    static func given(_ statement: String..., timeout: TimeInterval? = nil, handler: @escaping (Input<AnyRegexOutput>) throws -> Void) -> StatementHandler {
        .init(statementType: .if, statement: statement, timeout: timeout, handler: handler, setup: nil)
    }
    static func given(_ statement: String..., timeout: TimeInterval? = nil, handler: @escaping () throws -> Void) -> StatementHandler {
        .init(statementType: .if, statement: statement, timeout: timeout, handler: { _ in try handler() }, setup: nil)
    }

    // MARK: - when -

    static func when<T>(_ statement: Regex<T>, timeout: TimeInterval? = nil, handler: @escaping (Input<T>) throws -> Void, setup: @escaping (Input<T>) throws -> Void) -> StatementHandler {
        .init(statementType: .when, statement: statement, timeout: timeout, handler: handler, setup: setup)
    }
    static func when<T>(_ statement: Regex<T>, timeout: TimeInterval? = nil, handler: @escaping (Input<T>) throws -> Void, setup: @escaping () throws -> Void) -> StatementHandler {
        .init(statementType: .when, statement: statement, timeout: timeout, handler: handler, setup: { _ in try setup() })
    }
    static func when<T>(_ statement: Regex<T>, timeout: TimeInterval? = nil, handler: @escaping () throws -> Void, setup: @escaping (Input<T>) throws -> Void) -> StatementHandler {
        .init(statementType: .when, statement: statement, timeout: timeout, handler: { _ in try handler() }, setup: setup)
    }
    static func when<T>(_ statement: Regex<T>, timeout: TimeInterval? = nil, handler: @escaping () throws -> Void, setup: @escaping () throws -> Void) -> StatementHandler {
        .init(statementType: .when, statement: statement, timeout: timeout, handler: { _ in try handler() }, setup: { _ in try setup() })
    }
    static func when<T>(_ statement: Regex<T>, timeout: TimeInterval? = nil, handler: @escaping (Input<T>) throws -> Void) -> StatementHandler {
        .init(statementType: .when, statement: statement, timeout: timeout, handler: handler, setup: nil)
    }
    static func when(_ statement: String..., timeout: TimeInterval? = nil, handler: @escaping (Input<AnyRegexOutput>) throws -> Void, setup: @escaping (Input<AnyRegexOutput>) throws -> Void) -> StatementHandler {
        .init(statementType: .when, statement: statement, timeout: timeout, handler: handler, setup: setup)
    }
    static func when(_ statement: String..., timeout: TimeInterval? = nil, handler: @escaping (Input<AnyRegexOutput>) throws -> Void, setup: @escaping () throws -> Void) -> StatementHandler {
        .init(statementType: .when, statement: statement, timeout: timeout, handler: handler, setup: { _ in try setup() })
    }
    static func when(_ statement: String..., timeout: TimeInterval? = nil, handler: @escaping () throws -> Void, setup: @escaping (Input<AnyRegexOutput>) throws -> Void) -> StatementHandler {
        .init(statementType: .when, statement: statement, timeout: timeout, handler: { _ in try handler() }, setup: setup)
    }
    static func when(_ statement: String..., timeout: TimeInterval? = nil, handler: @escaping () throws -> Void, setup: @escaping () throws -> Void) -> StatementHandler {
        .init(statementType: .when, statement: statement, timeout: timeout, handler: { _ in try handler() }, setup: { _ in try setup() })
    }
    static func when(_ statement: String..., timeout: TimeInterval? = nil, handler: @escaping (Input<AnyRegexOutput>) throws -> Void) -> StatementHandler {
        .init(statementType: .when, statement: statement, timeout: timeout, handler: handler, setup: nil)
    }
    static func when(_ statement: String..., timeout: TimeInterval? = nil, handler: @escaping () throws -> Void) -> StatementHandler {
        .init(statementType: .when, statement: statement, timeout: timeout, handler: { _ in try handler() }, setup: nil)
    }

    // MARK: - expect -

    static func expect<T>(_ statement: Regex<T>, timeout: TimeInterval? = nil, handler: @escaping (Input<T>) throws -> Void, setup: @escaping (Input<T>) throws -> Void) -> StatementHandler {
        .init(statementType: .expect, statement: statement, timeout: timeout, handler: handler, setup: setup)
    }
    static func expect<T>(_ statement: Regex<T>, timeout: TimeInterval? = nil, handler: @escaping (Input<T>) throws -> Void, setup: @escaping () throws -> Void) -> StatementHandler {
        .init(statementType: .expect, statement: statement, timeout: timeout, handler: handler, setup: { _ in try setup() })
    }
    static func expect<T>(_ statement: Regex<T>, timeout: TimeInterval? = nil, handler: @escaping () throws -> Void, setup: @escaping (Input<T>) throws -> Void) -> StatementHandler {
        .init(statementType: .expect, statement: statement, timeout: timeout, handler: { _ in try handler() }, setup: setup)
    }
    static func expect<T>(_ statement: Regex<T>, timeout: TimeInterval? = nil, handler: @escaping () throws -> Void, setup: @escaping () throws -> Void) -> StatementHandler {
        .init(statementType: .expect, statement: statement, timeout: timeout, handler: { _ in try handler() }, setup: { _ in try setup() })
    }
    static func expect<T>(_ statement: Regex<T>, timeout: TimeInterval? = nil, handler: @escaping (Input<T>) throws -> Void) -> StatementHandler {
        .init(statementType: .expect, statement: statement, timeout: timeout, handler: handler, setup: nil)
    }
    static func expect(_ statement: String..., timeout: TimeInterval? = nil, handler: @escaping (Input<AnyRegexOutput>) throws -> Void, setup: @escaping (Input<AnyRegexOutput>) throws -> Void) -> StatementHandler {
        .init(statementType: .expect, statement: statement, timeout: timeout, handler: handler, setup: setup)
    }
    static func expect(_ statement: String..., timeout: TimeInterval? = nil, handler: @escaping () throws -> Void, setup: @escaping (Input<AnyRegexOutput>) throws -> Void) -> StatementHandler {
        .init(statementType: .expect, statement: statement, timeout: timeout, handler: {_ in try handler() }, setup: setup)
    }
    static func expect(_ statement: String..., timeout: TimeInterval? = nil, handler: @escaping (Input<AnyRegexOutput>) throws -> Void, setup: @escaping () throws -> Void) -> StatementHandler {
        .init(statementType: .expect, statement: statement, timeout: timeout, handler: handler, setup: { _ in try setup() })
    }
    static func expect(_ statement: String..., timeout: TimeInterval? = nil, handler: @escaping () throws -> Void, setup: @escaping () throws -> Void) -> StatementHandler {
        .init(statementType: .expect, statement: statement, timeout: timeout, handler: { _ in try handler() }, setup: { _ in try setup() })
    }
    static func expect(_ statement: String..., timeout: TimeInterval? = nil, handler: @escaping (Input<AnyRegexOutput>) throws -> Void) -> StatementHandler {
        .init(statementType: .expect, statement: statement, timeout: timeout, handler: handler, setup: nil)
    }
    static func expect(_ statement: String..., timeout: TimeInterval? = nil, handler: @escaping () throws -> Void) -> StatementHandler {
        .init(statementType: .expect, statement: statement, timeout: timeout, handler: { _ in try handler() }, setup: nil)
    }

    // MARK: - then -

    static func then<T>(_ statement: Regex<T>, timeout: TimeInterval? = nil, handler: @escaping (Input<T>) throws -> Void, setup: @escaping (Input<T>) throws -> Void) -> StatementHandler {
        .expect(statement, timeout: timeout, handler: handler, setup: setup)
    }
    static func then<T>(_ statement: Regex<T>, timeout: TimeInterval? = nil, handler: @escaping () throws -> Void, setup: @escaping (Input<T>) throws -> Void) -> StatementHandler {
        .expect(statement, timeout: timeout, handler: { _ in try handler() }, setup: setup)
    }
    static func then<T>(_ statement: Regex<T>, timeout: TimeInterval? = nil, handler: @escaping () throws -> Void, setup: @escaping () throws -> Void) -> StatementHandler {
        .expect(statement, timeout: timeout, handler: { _ in try handler() }, setup: { _ in try setup() })
    }
    static func then<T>(_ statement: Regex<T>, timeout: TimeInterval? = nil, handler: @escaping (Input<T>) throws -> Void, setup: @escaping () throws -> Void) -> StatementHandler {
        .expect(statement, timeout: timeout, handler: handler, setup: { _ in try setup() })
    }
    static func then<T>(_ statement: Regex<T>, timeout: TimeInterval? = nil, handler: @escaping (Input<T>) throws -> Void) -> StatementHandler {
        .expect(statement, timeout: timeout, handler: handler)
    }
    static func then(_ statement: String..., timeout: TimeInterval? = nil, handler: @escaping (Input<AnyRegexOutput>) throws -> Void, setup: @escaping (Input<AnyRegexOutput>) throws -> Void) -> StatementHandler {
        .init(statementType: .expect, statement: statement, timeout: timeout, handler: handler, setup: setup)
    }
    static func then(_ statement: String..., timeout: TimeInterval? = nil, handler: @escaping () throws -> Void, setup: @escaping (Input<AnyRegexOutput>) throws -> Void) -> StatementHandler {
        .init(statementType: .expect, statement: statement, timeout: timeout, handler: { _ in try handler() }, setup: setup)
    }
    static func then(_ statement: String..., timeout: TimeInterval? = nil, handler: @escaping (Input<AnyRegexOutput>) throws -> Void, setup: @escaping () throws -> Void) -> StatementHandler {
        .init(statementType: .expect, statement: statement, timeout: timeout, handler: handler, setup: { _ in try setup() })
    }
    static func then(_ statement: String..., timeout: TimeInterval? = nil, handler: @escaping () throws -> Void, setup: @escaping () throws -> Void) -> StatementHandler {
        .init(statementType: .expect, statement: statement, timeout: timeout, handler: { _ in try handler() }, setup: { _ in try setup() })
    }
    static func then(_ statement: String..., timeout: TimeInterval? = nil, handler: @escaping (Input<AnyRegexOutput>) throws -> Void) -> StatementHandler {
        .init(statementType: .expect, statement: statement, timeout: timeout, handler: handler, setup: nil)
    }
    static func then(_ statement: String..., timeout: TimeInterval? = nil, handler: @escaping () throws -> Void) -> StatementHandler {
        .init(statementType: .expect, statement: statement, timeout: timeout, handler: { _ in try handler() }, setup: nil)
    }
}
