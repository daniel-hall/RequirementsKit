//
//  Parsing.swift
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


struct Line {
    let number: Int
    let text: String
}

struct Parser<T> {
    private let closure: (inout [Line]) throws -> T

    private init(closure: @escaping (inout [Line]) throws -> T) {
        self.closure = closure
    }

    @_disfavoredOverload
    init(consumeLine: Bool = true, _ closure: @escaping (String) throws -> T) {
        self.closure = { lines in
            lines = Array(lines.drop { $0.text.trimmingCharacters(in: .whitespaces).isEmpty })
            guard let first = lines.first else {
                throw ParsingError(line: 0, description: "Can't parse an empty array of lines")
            }
            do {
                let result = try closure(first.text)
                if consumeLine {
                    lines = Array(lines.dropFirst())
                }
                return result
            } catch {
                throw ParsingError(line: first.number, description: error.localizedDescription)
            }
        }
    }

    init<U>(consumeLine: Bool = true, _ closure: @escaping (String) throws -> T) where T == U? {
        self.closure = { lines in
            lines = Array(lines.drop { $0.text.trimmingCharacters(in: .whitespaces).isEmpty })
            guard let first = lines.first else {
                throw ParsingError(line: 0, description: "Can't parse an empty array of lines")
            }
            do {
                let result = try closure(first.text)
                if consumeLine && result != nil {
                    lines = Array(lines.dropFirst())
                }
                return result
            } catch {
                throw ParsingError(line: first.number, description: error.localizedDescription)
            }
        }
    }

    @_disfavoredOverload
    init(consumeLine: Bool = true, _ closure: @escaping (String, Int) throws -> T) {
        self.closure = { lines in
            lines = Array(lines.drop { $0.text.trimmingCharacters(in: .whitespaces).isEmpty })
            guard let first = lines.first else {
                throw ParsingError(line: 0, description: "Can't parse an empty array of lines")
            }
            do {
                let result = try closure(first.text, first.number)
                if consumeLine {
                    lines = Array(lines.dropFirst())
                }
                return result
            } catch {
                throw ParsingError(line: first.number, description: error.localizedDescription)
            }
        }
    }

    init<U>(consumeLine: Bool = true, _ closure: @escaping (String, Int) throws -> T) where T == U? {
        self.closure = { lines in
            lines = Array(lines.drop { $0.text.trimmingCharacters(in: .whitespaces).isEmpty })
            guard let first = lines.first else {
                throw ParsingError(line: 0, description: "Can't parse an empty array of lines")
            }
            do {
                let result = try closure(first.text, first.number)
                if consumeLine && result != nil {
                    lines = Array(lines.dropFirst())
                }
                return result
            } catch {
                throw ParsingError(line: first.number, description: error.localizedDescription)
            }
        }
    }

    func callAsFunction(_ lines: inout [Line]) throws -> T {
        try closure(&lines)
    }

    func or(_ parser: Parser<T>) -> Parser<T> {
        return .init { lines in
            var temporary = Array(lines.drop { $0.text.trimmingCharacters(in: .whitespaces).isEmpty })
            do {
                let result = try self(&temporary)
                lines = temporary
                return result
            } catch {
                let firstError = error
                do {
                    let result = try parser.closure(&temporary)
                    lines = temporary
                    return result
                } catch {
                    switch (firstError as? ParsingError, error as? ParsingError) {
                    case (.none, .none): throw error
                    case (.none, .some(let error)), (.some(let error), .none): throw error
                    case (.some(let first), .some(let second)):
                        if first.line > second.line {
                            throw first
                        }
                        throw second
                    }
                }
            }
        }
    }

    @_disfavoredOverload
    func then<U>(_ parser: Parser<U>) -> Parser<(T, U)> {
        return .init { lines in
            var temporary = Array(lines.drop { $0.text.trimmingCharacters(in: .whitespaces).isEmpty })
            let firstResult = try self(&temporary)
            let secondResult = try parser(&temporary)
            lines = temporary
            return (firstResult, secondResult)
        }
    }

    func then(_ parser: Parser<Void>) -> Parser<T> {
        return .init { lines in
            var temporary = Array(lines.drop { $0.text.trimmingCharacters(in: .whitespaces).isEmpty })
            let result = try self(&temporary)
            _ = try parser(&temporary)
            lines = temporary
            return result
        }
    }


    func map<U>(_ transform: @escaping (T) throws -> U) -> Parser<U> {
        .init { lines in
            var temporary = Array(lines.drop { $0.text.trimmingCharacters(in: .whitespaces).isEmpty })
            let result = try self(&temporary)
            do {
                let mapped = try transform(result)
                lines = temporary
                return mapped
            } catch {
                throw ParsingError(line: lines.first?.number ?? 0, description: error.localizedDescription)
            }
        }
    }
}

extension Parser where T == Void {
    func then<U>(_ parser: Parser<U>) -> Parser<(U)> {
        return .init { lines in
            var temporary = Array(lines.drop { $0.text.trimmingCharacters(in: .whitespaces).isEmpty })
            _ = try self(&temporary)
            let result = try parser(&temporary)
            lines = temporary
            return result
        }
    }

}

extension Parser where T == Void  {

    static var end: Self {
        .init { lines in
            lines = Array(lines.drop { $0.text.trimmingCharacters(in: .whitespaces).isEmpty })
            guard lines.isEmpty else {
                throw RequirementsKitError("Expected end of file but there are still lines remaining")
            }
            return ()
        }
    }

    static func not<U>(_ parser: Parser<U>) -> Self {
        return .init { lines in
            var temporary = Array(lines.drop { $0.text.trimmingCharacters(in: .whitespaces).isEmpty })
            do {
                _ = try parser(&temporary)
            } catch {
                return ()
            }
            throw ParsingError(line: lines.first?.number ?? 0, description: "Parser was expected not to succeed and to not return a \(U.self), but it succeeded")
        }
    }
}

extension Parser {

    static func zeroOrMore<U, V>(_ parser: Parser<U>, until: Parser<V>) -> Self where T == [U] {
        let until = AnyParser(until)
        return .init { lines in
            var temporary = Array(lines.drop { $0.text.trimmingCharacters(in: .whitespaces).isEmpty })
            var checkRemaining = lines
            var accumulated = [U]()
            var proceed = true
            while proceed {
                do {
                    _ = try until(&checkRemaining)
                    proceed = false
                } catch {
                    accumulated.append(try parser(&temporary))
                    checkRemaining = temporary
                }
            }
            if !accumulated.isEmpty {
                lines = temporary
            }
            return accumulated
        }
    }

    static func oneOrMore<U, V>(_ parser: Parser<U>, until: Parser<V>) -> Self where T == [U] {
        let until = AnyParser(until)
        return .init { lines in
            var temporary = Array(lines.drop { $0.text.trimmingCharacters(in: .whitespaces).isEmpty })
            var checkRemaining = lines
            var accumulated = [U]()
            var proceed = true
            while proceed {
                do {
                    _ = try until(&checkRemaining)
                    proceed = false
                } catch {
                    accumulated.append(try parser(&temporary))
                    checkRemaining = temporary
                }
            }
            if accumulated.isEmpty {
                throw ParsingError(line: temporary.first?.number ?? 0, description: "No instances of \(U.self) accumulated when at least one was expected")
            }
            lines = temporary
            return accumulated
        }
    }
}

extension Parser {

    func flattened<A, B, C>() -> Parser<(A, B, C)> where T == ((A, B), C) {
        map { ($0.0, $0.1, $1) }
    }

    func flattened<A, B, C, D>() -> Parser<(A, B, C, D)> where T == (((A, B), C), D) {
        map { ($0.0.0, $0.0.1, $0.1, $1) }
    }

    func flattened<A, B, C, D, E>() -> Parser<(A, B, C, D, E)> where T == ((((A, B), C), D), E) {
        map { ($0.0.0.0, $0.0.0.1, $0.0.1, $0.1, $1) }
    }

    func flattened<A, B, C, D, E, F>() -> Parser<(A, B, C, D, E, F)> where T == (((((A, B), C), D), E), F) {
        map { ($0.0.0.0.0, $0.0.0.0.1, $0.0.0.1, $0.0.1, $0.1, $1) }
    }

    func flattened<A, B, C, D, E, F, G>() -> Parser<(A, B, C, D, E, F, G)> where T == ((((((A, B), C), D), E), F), G) {
        map { ($0.0.0.0.0.0, $0.0.0.0.0.1, $0.0.0.0.1, $0.0.0.1, $0.0.1, $0.1, $1) }
    }
}

private struct AnyParser {
    private let closure: (inout [Line]) throws -> Any
    init<T>(_ parser: Parser<T>) {
        self.closure =  { try parser(&$0) }
    }
    func callAsFunction(_ lines: inout [Line]) throws -> Any {
        try closure(&lines)
    }
}

struct ParsingError: Error {
    let line: Int
    let description: String
}

extension Requirement.Example._ExampleSet {
    var tokens: Set<String> {
        return (description?.tokens ?? []).union(statements.map { $0.tokens }.joined())
    }

    func replacing(token: String, with value: String) -> Self {
        .init(comments: comments, identifier: identifier, labels: labels, description: description?.replacingOccurrences(of: token, with: value), statements: statements.map { $0.replacing(token: token, with: value) })
    }
}

extension Requirement.Example {
    var tokens: Set<String> {
        return (description?.tokens ?? []).union(statements.map { $0.tokens }.joined())
    }

    func replacing(token: String, with value: String) -> Self {
        .init(comments: comments, identifier: identifier, labels: labels, description: description?.replacingOccurrences(of: token, with: value), statements: statements.map { $0.replacing(token: token, with: value) })
    }
}

extension Requirement.Example.Statement {
    var tokens: Set<String> {
        description.tokens.union(data?.tokens ?? [])
    }

    func replacing(token: String, with value: String) -> Self {
        return .init(comments: comments, type: type, description: description.replacingOccurrences(of: token, with: value), data: data?.replacing(token: token, with: value), line: line)
    }
}

extension Requirement.Example.Statement.Data {
    var tokens: Set<String> {
        switch self {
        case .text(let text): return text.tokens
        case .list(let list): return Set(list.map { $0.tokens }.joined())
        case .keyValues(let keyValues): return Set(keyValues.map { $0.key.tokens.union($0.value.tokens) }.joined())
        case .table(let table): return Set(table.map { $0.map { $0.key.tokens.union($0.value.tokens) }.joined() }.joined())
        case .matrix(let matrix): return Set(matrix.map { $0.key.tokens.union(Set($0.value.map { $0.key.tokens.union($0.value.tokens) }.joined())) }.joined())
        }
    }

    func replacing(token: String, with value: String) -> Self {
        switch self {
        case .text(let text): return .text(text.replacingOccurrences(of: token, with: value))
        case .list(let list): return .list(list.map { $0.replacingOccurrences(of: token, with: value) })
        case .keyValues(let keyValues):
            return .keyValues(OrderedDictionary(uniqueKeysWithValues: keyValues.map { ($0.key.replacingOccurrences(of: token, with: value), $0.value.replacingOccurrences(of: token, with: value)) }))
        case .table(let table):
            return .table(table.map { OrderedDictionary(uniqueKeysWithValues: $0.map { ($0.key.replacingOccurrences(of: token, with: value), $0.value.replacingOccurrences(of: token, with: value)) }) })
        case .matrix(let matrix):
            return .matrix(OrderedDictionary(uniqueKeysWithValues: matrix.map { ($0.key.replacingOccurrences(of: token, with: value), OrderedDictionary(uniqueKeysWithValues: $0.value.map { ($0.key.replacingOccurrences(of: token, with: value), $0.value.replacingOccurrences(of: token, with: value)) })) }))
        }
    }
}

extension String {
    var tokens: Set<String> {
        let regex = try! NSRegularExpression(pattern: "<.+?>")
        let matches = regex.matches(in: self, range: .init(location: 0, length: self.count))
        return Set(matches.map {
            String(self[Range($0.range, in: self)!])
        })
    }
}

internal extension [String]? {
    func combinedWith(_ array: [String]?) -> [String]? {
        switch (self, array) {
        case (.none, .none): return nil
        case (.none, .some(let existing)), (.some(let existing), .none): return existing
        case (.some(let first), .some(let second)):
            var combined = second
            first.forEach {
                if !combined.contains($0) { combined.append($0) }
            }
            return combined
        }
    }
}
