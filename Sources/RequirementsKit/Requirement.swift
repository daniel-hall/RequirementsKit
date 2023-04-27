//
//  Requirement.swift
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
import OrderedCollections


public struct File: Equatable {
    public let url: URL
    public let comments: [String]?
    public let labels: [String]?
    public let description: String?
    public let syntax: Syntax
    public let requirements: [Requirement]
    public var name: String {
        String(url.lastPathComponent.prefix(upTo: url.lastPathComponent.lastIndex(of: ".") ?? url.lastPathComponent.endIndex))
    }

    public init(url: URL, comments: [String]?, labels: [String]?, description: String?, syntax: Syntax, requirements: [Requirement]) {
        self.url = url
        self.comments = comments
        self.labels = labels
        self.description = description
        self.syntax = syntax
        self.requirements = requirements
    }

    public static func parseFrom(url: URL) throws -> File {
        let fileExtension = String(url.lastPathComponent.drop { $0 != "." }.dropFirst())
        switch fileExtension {
        case "feature": return try parseGherkin(from: url)
        case "requirements": return try parseReqsML(from: url)
        default: throw RequirementsKitError("Requirements files must have the extension .feature (for Gherkin) or .requirements (for ReqsML)")
        }
    }
}

public extension File {
    enum Syntax: Equatable {
        case gherkin, reqsML
    }
}

public struct Requirement: Hashable {
    public let comments: [String]?
    public let identifier: String?
    public let labels: [String]?
    internal let explicitLabels: [String]?
    public let description: String
    public let examples: [Example]

    public init(comments: [String]? = nil, identifier: String? = nil, labels: [String]? = nil, description: String, examples: [Requirement.Example]) {
        self.comments = comments
        self.identifier = identifier
        self.labels = labels
        self.explicitLabels = labels
        self.description = description
        self.examples = examples
    }

    internal init(comments: [String]? = nil, identifier: String? = nil, labels: [String]? = nil, explicitLabels: [String]? = nil, description: String, examples: [Requirement.Example]) {
        self.comments = comments
        self.identifier = identifier
        self.labels = labels
        self.explicitLabels = labels
        self.description = description
        self.examples = examples
    }

    public static func ==(lhs: Requirement, rhs: Requirement) -> Bool {
        return lhs.comments == rhs.comments
        && lhs.identifier == rhs.identifier
        && Set(arrayLiteral: lhs.labels) == Set(arrayLiteral: rhs.labels)
        && lhs.description == rhs.description
        && lhs.examples == rhs.examples
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(comments)
        hasher.combine(identifier)
        hasher.combine(labels)
        hasher.combine(description)
        hasher.combine(examples)
    }
}

extension Requirement {

    public struct Example: Hashable {
        public let comments: [String]?
        public let identifier: String?
        public let labels: [String]?
        internal let explicitLabels: [String]?
        public let description: String?
        public let statements: [Statement]
        internal let exampleSet: _ExampleSet?
        internal let specification: _ExampleSpecification?

        public init(comments: [String]? = nil, identifier: String? = nil, labels: [String]? = nil, description: String? = nil, statements: [Requirement.Example.Statement]) {
            self.comments = comments
            self.identifier = identifier
            self.labels = labels
            self.explicitLabels = labels
            self.description = description
            self.statements = statements
            self.exampleSet = nil
            self.specification = nil
        }

        internal init(comments: [String]? = nil, identifier: String? = nil, labels: [String]? = nil, explicitLabels: [String]? = nil, description: String? = nil, statements: [Requirement.Example.Statement], exampleSet: _ExampleSet? = nil, specification: _ExampleSpecification? = nil) {
            self.comments = comments
            self.identifier = identifier
            self.labels = labels
            self.explicitLabels = explicitLabels
            self.description = description
            self.statements = statements
            self.exampleSet = exampleSet
            self.specification = specification
        }

        public static func ==(lhs: Example, rhs: Example) -> Bool {
            return lhs.comments == rhs.comments
            && lhs.identifier == rhs.identifier
            && Set(arrayLiteral: lhs.labels) == Set(arrayLiteral: rhs.labels)
            && lhs.description == rhs.description
            && lhs.statements == rhs.statements
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(comments)
            hasher.combine(identifier)
            hasher.combine(labels)
            hasher.combine(description)
            hasher.combine(statements)
        }
    }
}

extension Requirement.Example {

    internal struct _ExampleSet: Hashable {
        let comments: [String]?
        let identifier: String?
        let labels: [String]?
        let description: String?
        let statements: [Statement]
    }

    internal struct _ExampleSpecification: Hashable {
        let comments: [String]?
        let identifier: String?
        let description: String?
        let labels: [String]?
        let values: OrderedDictionary<String, String>
    }

    public enum StatementType: String, Hashable {
        case `if`, when, expect
    }
    
    public struct Statement: Hashable {
        public let comments: [String]?
        public let type: StatementType
        public let description: String
        public let data: Data?
        public let line: Int?

        public init(comments: [String]? = nil, type: Requirement.Example.StatementType, description: String, data: Requirement.Example.Statement.Data? = nil, line: Int? = nil) {
            self.comments = comments
            self.type = type
            self.description = description
            self.data = data
            self.line = line
        }
    }
}

extension Requirement.Example.Statement {
    public static func ==(lhs: Requirement.Example.Statement, rhs: Requirement.Example.Statement) -> Bool {
        return lhs.comments == rhs.comments
        && lhs.type == rhs.type
        && lhs.description == rhs.description
        && lhs.data == rhs.data
    }
}

extension Requirement.Example.Statement {
    public enum Data: Hashable {
        case text(String)
        case keyValues(OrderedDictionary<String, String>)
        case list([String])
        case table([OrderedDictionary<String, String>])
        case matrix(OrderedDictionary<String, OrderedDictionary<String, String>>)

        public var text: String? {
            if case .text(let data) = self { return data }
            return nil
        }

        public var keyValues: Dictionary<String, String>? {
            if case .keyValues(let data) = self {
                return Dictionary(uniqueKeysWithValues: data.map {
                    ($0.key, $0.value)
                })
            }
            return nil
        }

        public var list: [String]? {
            if case .list(let data) = self { return data }
            return nil
        }

        public var table: [Dictionary<String, String>]? {
            if case .table(let data) = self {
                return data.map {
                    Dictionary(uniqueKeysWithValues: $0.map {
                        ($0.key, $0.value)
                    })
                }
            }
            return nil
        }

        public var matrix: Dictionary<String, Dictionary<String, String>>? {
            if case .matrix(let data) = self {
                return Dictionary(uniqueKeysWithValues: data.map {
                    ($0.key, Dictionary(uniqueKeysWithValues: $0.value.map {
                        ($0.key, $0.value)
                    }))
                })
            }
            return nil
        }
    }
}

struct RequirementsKitError: LocalizedError {
    let errorDescription: String?
    init(_ description: String) {
        self.errorDescription = description
    }
}
