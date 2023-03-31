//
//  LabelExpression.swift
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

public indirect enum LabelExpression {
    case label(String)
    case not(String)
    case orLabel(LabelExpression, String)
    case andLabel(LabelExpression, String)
    case orNotLabel(LabelExpression, String)
    case andNotLabel(LabelExpression, String)
    case orExpression(LabelExpression, LabelExpression)
    case andExpression(LabelExpression, LabelExpression)
    case orNotExpression(LabelExpression, LabelExpression)
    case andNotExpression(LabelExpression, LabelExpression)

    public func or(_ string: String) -> LabelExpression {
        return .orLabel(self, string)
    }

    public func and(_ string: String) -> LabelExpression {
        return .andLabel(self, string)
    }

    public func orNot(_ string: String) -> LabelExpression {
        return .orNotLabel(self, string)
    }

    public func andNot(_ string: String) -> LabelExpression {
        return .andNotLabel(self, string)
    }

    public func or(_ expression: LabelExpression) -> LabelExpression {
        return .orExpression(self, expression)
    }

    public func and(_ expression: LabelExpression) -> LabelExpression {
        return .andExpression(self, expression)
    }

    public func orNot(_ expression: LabelExpression) -> LabelExpression {
        return .orNotExpression(self, expression)
    }

    public func andNot(_ expression: LabelExpression) -> LabelExpression {
        return .andNotExpression(self, expression)
    }

    private enum MatchResult {
        case success
        case notIncluded
        case excluded
        case notIncludedAndExcluded
        case failure
    }

    private func matchResult(_ labels: [String]) -> MatchResult {
        switch self {

        case .label(let string):
            return labels.contains(string) ? .success : .notIncluded

        case .not(let string):
            return !labels.contains(string) ? .success : .excluded

        case .andLabel(let expression, let string):
            switch expression.matchResult(labels) {
            case .success: return labels.contains(string) ? .success : .notIncluded
            case .excluded: return labels.contains(string) ? .excluded : .notIncludedAndExcluded
            case .notIncluded: return .notIncluded
            case .notIncludedAndExcluded: return .notIncludedAndExcluded
            case .failure: return .failure
            }

        case .orLabel(let expression, let string):
            switch expression.matchResult(labels) {
            case .success: return .success
            case .excluded: return labels.contains(string) ? .excluded : .notIncludedAndExcluded
            case .notIncluded: return labels.contains(string) ? .success : .notIncluded
            case .notIncludedAndExcluded: return labels.contains(string) ? .excluded : .notIncludedAndExcluded
            case .failure: return .failure
            }

        case .orNotLabel(let expression, let string):
            switch expression.matchResult(labels) {
            case .success: return .success
            case .excluded: return !labels.contains(string) ? .success : .excluded
            case .notIncluded: return .notIncluded
            case .notIncludedAndExcluded: return !labels.contains(string) ? .notIncluded : .notIncludedAndExcluded
            case .failure: return .failure
            }

        case .andNotLabel(let expression, let string):
            switch expression.matchResult(labels) {
            case .success: return !labels.contains(string) ? .success : .excluded
            case .excluded: return .excluded
            case .notIncluded: return !labels.contains(string) ? .notIncluded : .notIncludedAndExcluded
            case .notIncludedAndExcluded: return .notIncludedAndExcluded
            case .failure: return .failure
            }

        case .orExpression(let first, let second):
            return first.matchResult(labels) == .success || second.matchResult(labels) == .success ? .success : .failure

        case .andExpression(let first, let second):
            return first.matchResult(labels) == .success && second.matchResult(labels) == .success ? .success : .failure

        case .orNotExpression(let first, let second):
            return first.matchResult(labels) == .success || second.matchResult(labels) != .success ? .success : .failure

        case .andNotExpression(let first, let second):
            return first.matchResult(labels) == .success && second.matchResult(labels) == .success ? .success : .failure
        }
    }

    public func matches(_ labels: [String]?) -> Bool {
        return matchResult(labels ?? []) == .success
    }

    public func matches(_ label: String) -> Bool {
        return matches([label])
    }
}
