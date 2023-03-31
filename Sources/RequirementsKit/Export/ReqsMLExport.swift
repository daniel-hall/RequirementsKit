//
//  ReqsMLExport.swift
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


func consolidateSpacing(_ array: [String]) -> [String] {
    if array.isEmpty || (array.count == 1 && array.first?.trimmingCharacters(in: .whitespaces).first == "\n") { return [] }
    let leadingSpaces = array.prefix { $0.trimmingCharacters(in: .whitespaces).first == "\n" }
    let consolidated = array.trimmingPrefix { $0.trimmingCharacters(in: .whitespaces).first == "\n" }
    let head = consolidated.prefix { $0.trimmingCharacters(in: .whitespaces).first != "\n" }
    let tail = consolidated.trimmingPrefix { $0.trimmingCharacters(in: .whitespaces).first != "\n" }
    return (leadingSpaces.count > 0 ? ["\n"] : []) + Array(head) + consolidateSpacing(Array(tail))
}

public extension File {
    func asReqsML() -> String {
        consolidateSpacing(requirements.asReqsML()).joined(separator: "\n").replacingOccurrences(of: "\n\n\n", with: "\n\n").drop { $0 == "\n" } + ""
    }
}

extension Requirement {
    fileprivate func asReqsML() -> [String] {
        let comments: [String] = comments.map { ["\n"] + $0.map { "// " + $0 }  } ?? []
        let metadata = reqsMLFrom(identifier: identifier, labels: explicitLabels)
        let requirementDescription: [String] = ["Requirement: " + description, "\n"]

        var exampleGroups = [[Requirement.Example]]()
        var currentGroup = [Requirement.Example]()

        examples.forEach {
            switch (currentGroup.first?.exampleSet, $0.exampleSet) {
            case (.none, .none):
                currentGroup.append($0)
            case (.some(let current), .some(let example)) where current == example:
                currentGroup.append($0)
            default:
                if !currentGroup.isEmpty { exampleGroups.append(currentGroup) }
                currentGroup = [$0]
            }
        }
        if !currentGroup.isEmpty {
            exampleGroups.append(currentGroup)
        }
        let indentedExamples: [String]
        if exampleGroups.count == 1,
           let firstGroup = exampleGroups.first,
           let exampleSet = firstGroup.first?.exampleSet,
           exampleSet.comments == nil,
           exampleSet.description == nil,
           exampleSet.labels == nil,
           exampleSet.identifier == nil
        {
            let ifs: [Requirement.Example.Statement] = exampleSet.statements.filter { $0.type == .if }
            let whens: [Requirement.Example.Statement] = exampleSet.statements.filter { $0.type == .when }
            let expects: [Requirement.Example.Statement] = exampleSet.statements.filter { $0.type == .expect }
            let statements: [String] = ifs.asReqsML() + whens.asReqsML() + expects.asReqsML()
            let indentedStatements: [String] = statements.map { $0 == "\n" ? $0 : "  " + $0 }
            let examplesKeyword = ["  " + "Examples:", "\n"]
            var maxDescriptionCount: Int?
            var maxMetadataCount: Int?
            var maxKeyCounts = OrderedDictionary<String, Int>()
            firstGroup.forEach {
                if let description = $0.specification?.description {
                    maxDescriptionCount = (maxDescriptionCount == nil || (maxDescriptionCount ?? 0) < description.count) ? description.count : maxDescriptionCount
                }
                if let metadata = reqsMLFrom(identifier: $0.specification?.identifier, labels: $0.specification?.labels).first {
                    maxMetadataCount = (maxMetadataCount == nil || (maxMetadataCount ?? 0) < metadata.count) ? metadata.count : maxMetadataCount
                }
                $0.specification?.values.forEach {
                    if maxKeyCounts[$0.key] == nil {
                        maxKeyCounts[$0.key] = $0.key.count
                    }
                    if (maxKeyCounts[$0.key] ?? 0) < $0.value.count {
                        maxKeyCounts[$0.key] = $0.value.count
                    }
                }
            }
            let headerRows = [
                (maxMetadataCount == nil ? "" : String(repeating: " ", count: maxMetadataCount! + 1))
                + (maxDescriptionCount == nil ? "" : "| " + String(repeating: " ", count: maxDescriptionCount! + 1))
                + String(maxKeyCounts.map { "| " + $0.key + String(repeating: " ", count: $0.value - $0.key.count) }.joined())
                + " |",
                (maxMetadataCount == nil ? "" : String(repeating: " ", count: maxMetadataCount! + 1))
                + (maxDescriptionCount == nil ? "" : "| " + String(repeating: "-", count: maxDescriptionCount!) + " ")
                + String(maxKeyCounts.map { "| " + String(repeating: "-", count: $0.value) }.joined())
                + " |"
            ]
            let valueRows: [String] = firstGroup.map { example in
                let comments: [String] = example.specification?.comments.map { ["\n"] + $0.map { "// " + $0 }  } ?? []
                let metadata = reqsMLFrom(identifier: example.specification?.identifier, labels: example.specification?.labels).first ?? String(repeating: " ", count: maxMetadataCount ?? 0)
                let description = example.specification?.description ?? String(repeating: " ", count: maxDescriptionCount ?? 0)
                var metadataString: String = ""
                var descriptionString: String = ""
                if let maxMetadataCount {
                    metadataString = metadata + String(repeating: " ", count: maxMetadataCount - metadata.count) + " "
                }
                if let maxDescriptionCount {
                    descriptionString = "| " + description + String(repeating: " ", count: maxDescriptionCount - description.count) + " "
                }
                let values = metadataString + descriptionString + String(maxKeyCounts.map { "| " + example.specification!.values[$0.key]! + String(repeating: " ", count: $0.value - example.specification!.values[$0.key]!.count) }.joined()) + " |"
                return comments + [values]
            }.joined().map { $0 }

            let indentedValues = (headerRows + valueRows).map { $0 == "\n" ? $0 : "  " + "  " + $0 }
            indentedExamples = indentedStatements + examplesKeyword + indentedValues + ["\n"]
        }
        else if exampleGroups.count == 1,
            let firstGroup = exampleGroups.first,
            let firstExample = firstGroup.first,
            firstGroup.count == 1
        {
            indentedExamples = firstExample.asReqsML().map { $0 == "\n" ? $0 : "  " + $0 }
        } else {
            indentedExamples = exampleGroups.map { $0.asReqsML() }.joined().map { $0 == "\n" ? $0 : "  " + $0 }
        }
        return comments + metadata + requirementDescription + indentedExamples
    }
}

fileprivate func reqsMLFrom(identifier: String?, labels: [String]?) -> [String] {
    switch (identifier, labels) {
    case (.none, .none): return []
    case (.some(let identifier), .none): return ["#\(identifier)"]
    case (.none, .some(let labels)): return ["#(\(labels.joined(separator: ", ")))"]
    case (.some(let identifier), .some(let labels)): return ["#\(identifier) (\(labels.joined(separator: ", ")))"]
    }
}

extension [Requirement] {
    public func asReqsML() -> [String] {
        guard count > 0 else { return [] }
        return map { $0.asReqsML() }.joined().map { $0 }
    }
}

extension [Requirement.Example] {

    fileprivate func asReqsML() -> [String] {
        guard count > 0 else { return [] }
        if let first = first, let exampleSet = first.exampleSet {
            let comments: [String] = exampleSet.comments.map { ["\n"] + $0.map { "// " + $0 }  } ?? []
            let metadata = reqsMLFrom(identifier: exampleSet.identifier, labels: exampleSet.labels)
            let exampleDescription: [String] = ["Example Set: " + (exampleSet.description ?? ""), "\n"]
            let ifs: [Requirement.Example.Statement] = exampleSet.statements.filter { $0.type == .if }
            let whens: [Requirement.Example.Statement] = exampleSet.statements.filter { $0.type == .when }
            let expects: [Requirement.Example.Statement] = exampleSet.statements.filter { $0.type == .expect }
            let statements: [String] = ifs.asReqsML() + whens.asReqsML() + expects.asReqsML()
            let indentedStatements: [String] = statements.map { $0 == "\n" ? $0 : "  " + $0 }
            let examplesKeyword = ["  " + "Examples:", "\n"]
            var maxMetadataCount = -1
            var maxKeyCounts = OrderedDictionary<String, Int>()
            self.forEach {
                $0.specification?.values.forEach {
                    if maxKeyCounts[$0.key] == nil {
                        maxKeyCounts[$0.key] = $0.key.count
                    }
                    if (maxKeyCounts[$0.key] ?? 0) < $0.value.count {
                        maxKeyCounts[$0.key] = $0.value.count
                    }
                }
                if let metadata = reqsMLFrom(identifier: $0.specification?.identifier, labels: $0.specification?.labels).first {
                    if metadata.count > maxMetadataCount {
                        maxMetadataCount = metadata.count
                    }
                }
            }
            let headerRows = [
                String(repeating: " ", count: maxMetadataCount + 1) + String(maxKeyCounts.map { "| " + $0.key + String(repeating: " ", count: $0.value - $0.key.count) + " " }.joined())  + "|",
                String(repeating: " ", count: maxMetadataCount + 1) + String(maxKeyCounts.map { "| " + String(repeating: "-", count: $0.value) + " " }.joined()) + "|"
            ]
            let valueRows: [String] = self.map { example in
                let comments: [String] = example.specification?.comments.map { ["\n"] + $0.map { "// " + $0 }  } ?? []
                let metadata = reqsMLFrom(identifier: example.specification?.identifier, labels: example.specification?.labels).first ?? ""
                let values = metadata + String(repeating: " ", count: maxMetadataCount - metadata.count + 1) + String(maxKeyCounts.map { "| " + example.specification!.values[$0.key]! + String(repeating: " ", count: $0.value - example.specification!.values[$0.key]!.count + 1) }.joined()) + "|"
                return comments + [values]
            }.joined().map { $0 }

            let indentedValues = (headerRows + valueRows).map { $0 == "\n" ? $0 : "  " + "  " + $0 }
            return comments + metadata + exampleDescription + indentedStatements + examplesKeyword + indentedValues + ["\n"]
        }
        return map { $0.asReqsML() }.joined().map { $0 }
    }
}

extension Requirement.Example {

    fileprivate func asReqsML() -> [String] {
        let comments: [String] = comments.map { ["\n"] + $0.map { "// " + $0 }  } ?? []
        let metadata = reqsMLFrom(identifier: identifier, labels: explicitLabels)
        let exampleDescription: [String] = ["Example: " + (description ?? ""), "\n"]
        let ifs: [Requirement.Example.Statement] = statements.filter { $0.type == .if }
        let whens: [Requirement.Example.Statement] = statements.filter { $0.type == .when }
        let expects: [Requirement.Example.Statement] = statements.filter { $0.type == .expect }
        let statements: [String] = ifs.asReqsML() + whens.asReqsML() + expects.asReqsML()
        if self.comments == nil, identifier == nil, labels == nil, description == nil {
            return statements
        }
        let indentedStatements: [String] = statements.map { $0 == "\n" ? $0 : "  " + $0 }
        return comments + metadata + exampleDescription + indentedStatements + ["\n"]
    }
}

extension [Requirement.Example.Statement] {
    fileprivate func asReqsML() -> [String] {
        guard count > 0 else { return [] }
        if let single = first, count == 1  {
            let comments = single.comments.map { ["\n"] + $0.map { "// " + $0 }  } ?? []
            let description = [single.type.rawValue.capitalized + ": " + single.description]
            let data = (single.data?.asReqsML() ?? []).map { $0 == "\n" ? $0 : "  " + $0 }
            return comments + description + data + ["\n"]
        }
        let firstLine: [String] = [first!.type.rawValue.capitalized + ":"]
        let remaining: [String] = self.map { statement in
            let comments: [String] = statement.comments.map { ["\n"] + $0.map { "// " + $0 } } ?? []
            let data: [String] = statement.data?.asReqsML().map { $0 == "\n" ? $0 : ("  " + $0) } ?? []
            return comments + ["- " + statement.description] + data
        }.joined().map { $0 }
        return  firstLine + remaining + ["\n"]
    }
}

extension Requirement.Example.Statement.Data {
    fileprivate func asReqsML() -> [String] {
        switch self {
        case .list(let list):
            let maxCount = list.map { $0.count }.max()!
            return list.map { "| " + $0 + String(repeating: " ", count: maxCount - $0.count) + " |" } + ["\n"]
        case .keyValues(let keyValues):
            let maxCount = keyValues.map { $0.key.count + $0.value.count }.max()!
            return keyValues.map { "| " + $0.key + ": " + $0.value + String(repeating: " ", count: (maxCount - $0.key.count - $0.value.count)) + " |" } + ["\n"]
        case .text(let text): return ["```"] + text.split(separator: "\n", omittingEmptySubsequences: false).map { String($0) } + ["```"] + ["\n"]
        case .table(let table):
            var maxCounts = OrderedDictionary<String, Int>()
            table.forEach {
                $0.forEach {
                    if maxCounts[$0.key] == nil {
                        maxCounts[$0.key] = $0.key.count
                    }
                    if (maxCounts[$0.key] ?? 0) < $0.value.count {
                        maxCounts[$0.key] = $0.value.count
                    }
                }
            }
            var lines = [maxCounts.map { "| " + $0.key + String(repeating: " ", count: maxCounts[$0.key]! - $0.key.count) + " " }.joined() + "|"]
            lines += [maxCounts.map { "| " + String(repeating: "-", count: maxCounts[$0.key]!) + " " }.joined() + "|"]
            lines += table.map { values in
                maxCounts.map { "| " + values[$0.key]! + String(repeating: " ", count: $0.value - values[$0.key]!.count) + " " }.joined() + "|"
            }
            return lines + ["\n"]
        case .matrix(let matrix):
            var maxKeyCount = 0
            var maxCounts = OrderedDictionary<String, Int>()
            matrix.forEach {
                maxKeyCount = max($0.key.count, maxKeyCount)
                $0.value.forEach {
                    if maxCounts[$0.key] == nil {
                        maxCounts[$0.key] = $0.key.count
                    }
                    if (maxCounts[$0.key] ?? 0) < $0.value.count {
                        maxCounts[$0.key] = $0.value.count
                    }
                }
            }
            var lines = ["| " + String(repeating: " ", count: maxKeyCount) + " " + maxCounts.map { "| " + $0.key + String(repeating: " ", count: maxCounts[$0.key]! - $0.key.count) + " " }.joined() + "|"]
            lines += ["| " + String(repeating: "-", count: maxKeyCount) + " " + maxCounts.map { "| " + String(repeating: "-", count: maxCounts[$0.key]!) + " " }.joined() + "|"]
            lines += matrix.map { row in
                "| " + row.key + String(repeating: " ", count: maxKeyCount - row.key.count) + " " + maxCounts.map { "| " + row.value[$0.key]! + String(repeating: " ", count: $0.value - row.value[$0.key]!.count) + " " }.joined() + "|"
            }
            return lines + ["\n"]
        }
    }
}
