//
//  GherkinParser.swift
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


private struct CommentsAndTags {
    let comments: [String]?
    let tags: [String]?
}

private struct ExampleRow {
    let comments: [String]?
    let tags: [String]?
    let values: [String]
}

public func parseGherkin(from url: URL) throws -> File {
    let data = try Data(contentsOf: url)
    guard let string = String(data: data, encoding: .ascii) else {
        throw RequirementsKitError(errorDescription: "Couldn't decode text from file at url \(url)")
    }
    var lines = string.split(separator: "\n", omittingEmptySubsequences: false).enumerated().map { Line(number: $0.offset + 1, text: String($0.element)) }
    let feature = try parseFeature(&lines)
    return File(url: url, comments: feature.comments, labels: feature.labels, description: feature.description, syntax: feature.syntax, requirements: feature.requirements)
}

private let parseFeature = parseOptionalCommentsAndTags
    .then(parseFeatureDescription)
    .then(parseExtendedDescription)
    .then(.oneOrMore(parseRule, until: .end))
    .flattened()
    .map { commentsAndTags, description, rules in
        let rules = rules.map { rule in
            let combinedRuleLabels = commentsAndTags?.tags.combinedWith(rule.labels) ?? rule.labels
            let examples = rule.examples.map { example in
                let combinedExampleLabels = combinedRuleLabels.combinedWith(example.labels) ?? example.labels
                return Requirement.Example(comments: example.comments, identifier: example.identifier, labels: combinedExampleLabels, explicitLabels: example.labels, description: example.description, statements: example.statements)
            }
            return Requirement(comments: rule.comments, identifier: rule.identifier, labels: combinedRuleLabels, explicitLabels: rule.labels, description: rule.description, examples: examples)
        }
        return File(url: .init(string: "requirements.kit")!, comments: commentsAndTags?.comments, labels: commentsAndTags?.tags, description: description, syntax: .gherkin, requirements: rules)
    }
    .or(
        parseOptionalCommentsAndTags
            .then(parseFeatureDescription)
            .then(parseExtendedDescription)
            .then(parseExamples)
            .flattened()
            .map { commentsAndTags, description, examples in
                let examples = examples.map { example in
                    let combinedLabels = commentsAndTags?.tags.combinedWith(example.labels) ?? example.labels
                    return Requirement.Example(comments: example.comments, identifier: example.identifier, labels: combinedLabels, explicitLabels: example.labels, description: example.description, statements: example.statements)
                }
                let requirement = Requirement(comments: nil, identifier: nil, labels: commentsAndTags?.tags, description: description, examples: examples)
                return File(url: .init(string: "requirements.kit")!, comments: commentsAndTags?.comments, labels: commentsAndTags?.tags, description: description, syntax: .gherkin, requirements: [requirement])
            }
    )

private let parseRule = parseOptionalCommentsAndTags
    .then(parseRuleDescription)
    .then(parseExtendedDescription)
    .then(parseExamples)
    .flattened()
    .map { commentsAndTags, description, examples in
        let examples = examples.map { example in
            let combinedLabels = commentsAndTags?.tags.combinedWith(example.labels) ?? example.labels
            return Requirement.Example(comments: example.comments, identifier: example.identifier, labels: combinedLabels, explicitLabels: example.labels, description: example.description, statements: example.statements)
        }
        return Requirement(comments: commentsAndTags?.comments, identifier: nil, labels: commentsAndTags?.tags, description: description, examples: examples)
    }

private let parseComment = Parser<String> {
    let trimmed = $0.trimmingCharacters(in: .whitespaces)
    guard trimmed.hasPrefix("#") else {
        throw "Can't parse comment because line doesn't start with #"
    }
    return trimmed.drop { $0 == "#" }.trimmingCharacters(in: .whitespaces)
}

private let parseOptionalComments: Parser<[String]?> = Parser.zeroOrMore(parseComment, until: .end.or(.not(parseComment)))
    .map { $0.isEmpty ? nil : $0 }

private let parseTags = Parser<[String]> {
    let trimmed = $0.trimmingCharacters(in: .whitespaces)
    let tags = trimmed.split(separator: " ").map { $0.trimmingCharacters(in: .whitespaces) }
    guard tags.reduce(true, { $0 && $1.first == "@" && !$1.dropFirst().trimmingCharacters(in: .whitespaces).isEmpty ? true : false }) else {
        throw "Tags must all be prefixed with @"
    }
    return tags.map { $0.dropFirst().trimmingCharacters(in: .whitespaces) }
}

private let parseOptionalTags: Parser<[String]?> = parseTags
    .map { .some($0) }
    .or(
        Parser<[String]?>(consumeLine: false) { _ in nil }
    )

private let parseOptionalCommentsAndTags: Parser<CommentsAndTags?> = parseOptionalComments
    .then(parseOptionalTags)
    .then(parseOptionalComments)
    .flattened()
    .map { firstComments, tags, secondComments in
        if firstComments == nil && secondComments == nil && tags == nil {
            return nil
        }
        let combinedComments = firstComments.map { secondComments == nil ? $0 : $0 + secondComments!  } ?? secondComments
        return CommentsAndTags(comments: combinedComments, tags:tags)
    }

private let parseExtendedDescription: Parser<Void> =
Parser.zeroOrMore(parseString, until: parseRuleDescription.map { _ in ()}
    .or(parseScenarioOutlineDescription.map {_ in () })
    .or(parseExampleDescription.map { _ in () })
    .or(parseStatement.map { _ in () })
    .or(parseComment.map { _ in () })
    .or(parseTags.map { _ in () }))
.map { _ in () }

private let parseFeatureDescription = Parser<String> {
    let trimmed = $0.trimmingCharacters(in: .whitespaces)
    guard trimmed.hasPrefix("Feature:") == true else {
        throw "Line doesn't begin with \"Feature:\""
    }
    let description = trimmed.drop { $0 != ":" }.dropFirst().trimmingCharacters(in: .whitespaces)
    guard !description.isEmpty else {
        throw "There must be a non-empty description of the Rule after the the \"Feature:\" keyword"
    }
    return description
}

private let parseRuleDescription = Parser<String> {
    let trimmed = $0.trimmingCharacters(in: .whitespaces)
    guard trimmed.hasPrefix("Rule:") == true else {
        throw "Line doesn't begin with \"Rule:\""
    }
    let description = trimmed.drop { $0 != ":" }.dropFirst().trimmingCharacters(in: .whitespaces)
    guard !description.isEmpty else {
        throw "There must be a non-empty description of the Rule after the the \"Rule:\" keyword"
    }
    return description
}

private let parseExampleDescription = Parser<String> {
    let trimmed = $0.trimmingCharacters(in: .whitespaces)
    guard trimmed.hasPrefix("Example:") == true || trimmed.hasPrefix("Scenario:") == true else {
        throw "Line doesn't begin with \"Example:\" or \"Scenario:\""
    }
    let description = trimmed.drop { $0 != ":" }.dropFirst().trimmingCharacters(in: .whitespaces)
    guard !description.isEmpty else {
        throw "There must be a non-empty description after the the \"Example:\" or \"Scenario:\" keyword"
    }
    return description
}

private let parseStatementKeyword = Parser<(Requirement.Example.StatementType, String)> {
    let type: Requirement.Example.StatementType
    let trimmed = $0.trimmingCharacters(in: .whitespaces)
    switch trimmed.prefix(upTo: trimmed.firstIndex(of: " ") ?? trimmed.startIndex) {
    case "Given":
        type = .if
    case "When":
        type = .when
    case "Then":
        type = .expect
    default:
        throw "No Given, When, or Then keyword found"
    }
    let description = trimmed.drop { $0 != " " }.dropFirst().trimmingCharacters(in: .whitespaces)
    guard !description.isEmpty else {
        throw "A Statement must have a description after the Given, When or Then keyword"
    }
    return (type, description)
}

private let parseAndButOrListItem = parseOptionalComments
    .then(
        Parser<String> {
            let trimmed = $0.trimmingCharacters(in: .whitespaces)
            let description: String
            if trimmed.hasPrefix("*") {
                description = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("And") {
                description = trimmed.dropFirst(3).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("But") {
                description = trimmed.dropFirst(3).trimmingCharacters(in: .whitespaces)
            } else {
                throw "Not a Statement that starts with And, But, or *"
            }
            guard !description.isEmpty else {
                throw "A Statement must have a description after the And, But or * keyword"
            }
            return description
        }
    )
    .then(parseOptionalData)
    .flattened()

private let parseStatement = parseOptionalComments
    .then(parseStatementKeyword).then(parseOptionalData)
    .flattened()
    .map {
        Requirement.Example.Statement(comments: $0, type: $1.0, description: $1.1, data: $2)
    }

private let parseEitherKindOfStatement = parseStatement
    .then(.oneOrMore(parseAndButOrListItem, until: .end.or(.not( parseAndButOrListItem))))
    .map { statement, items in
        return [statement] + items.map {
            Requirement.Example.Statement(comments: $0.0, type: statement.type, description: $0.1, data: $0.2)
        }
    }
    .or(parseStatement.map { [$0] })

private let parseStatements = Parser.oneOrMore(parseEitherKindOfStatement, until: .end.or(.not(parseEitherKindOfStatement)))
    .map { Array($0.joined()) }

private let parseExample = parseOptionalCommentsAndTags
    .then(parseExampleDescription)
    .then(parseExtendedDescription)
    .then(parseStatements)
    .flattened()
    .map { commentsAndTags, description, statements in
        guard !statements.isEmpty else {
            throw "An Example must contain one or more Statements"
        }
        return Requirement.Example(comments: commentsAndTags?.comments, identifier: nil, labels: commentsAndTags?.tags, description: description, statements: statements)
    }

private let parseScenarioOutlineDescription = Parser<String> {
    let trimmed = $0.trimmingCharacters(in: .whitespaces)
    guard trimmed.hasPrefix("Scenario Outline:") == true || trimmed.hasPrefix("Scenario Template:") == true else {
        throw "Line doesn't begin with \"Scenario Outline:\" or \"Scenario Template:\""
    }
    let description = trimmed.drop { $0 != ":" }.dropFirst().trimmingCharacters(in: .whitespaces)
    guard !description.isEmpty else {
        throw "There must be a non-empty description after the the \"Scenario Outline:\" or \"Scenario Template:\" keyword"
    }
    return description
}

let parseScenarioOutline = parseOptionalCommentsAndTags
    .then(parseScenarioOutlineDescription)
    .then(parseExtendedDescription)
    .then(parseStatements)
    .flattened()
    .map { commentsAndTags, description, statements in
        guard !statements.isEmpty else {
            throw "A Scenario Outline / Scenario Template must contain one or more Statements"
        }
        return Requirement.Example(comments: commentsAndTags?.comments, identifier: nil, labels: commentsAndTags?.tags, description: description, statements: statements)
    }

private let parseExamplesOrScenariosKeyword = Parser<Void> {
    let trimmed = $0.trimmingCharacters(in: .whitespaces)
    guard trimmed.hasPrefix("Examples:") || trimmed.hasPrefix("Scenarios:") else {
        throw "No Examples: or Scenarios: keyword found"
    }
    guard trimmed.replacingOccurrences(of: "Examples:", with: "").isEmpty || trimmed.replacingOccurrences(of: "Scenarios:", with: "").isEmpty else {
        throw "The Examples: or Scenarios: keyword should not have any description after it and should be on a line by itself"
    }
    return ()
}

private let parseExampleRow: Parser<ExampleRow> = parseOptionalCommentsAndTags
    .then(parseTableRow)
    .map { ExampleRow(comments: $0.0?.comments, tags: $0.0?.tags, values: $0.1) }

private let parseExampleTemplate: Parser<[Requirement.Example]> = parseScenarioOutline
    .then(parseExamplesOrScenariosKeyword)
    .then(.oneOrMore(parseExampleRow, until: .end.or(.not(parseExampleRow))))
    .map { example, examples in
        guard !example.tokens.isEmpty else {
            throw "There are no template tokens present in the Example template"
        }
        guard examples.count >= 2 else {
            throw "Examples should be a table containing at least 2 rows: a headers row and at least one row of values"
        }
        let headers = examples.first!
        guard headers.comments == nil, headers.tags == nil else {
            throw "The Examples / Scenarios header row can't have comments or tags"
        }
        guard examples.reduce(true, { $0 && $1.values.count == headers.values.count }) else {
            throw "Every row in the Examples table must have the same number of colums"
        }
        guard Set(example.tokens.map { $0.trimmingCharacters(in: .init(charactersIn: "<>")) }) == Set(headers.values.drop { $0.isEmpty }) else {
            throw "Every unique template variable must have exactly one matching column in the Examples table"
        }
        return examples.dropFirst().map {
            var description: String?
            var statements = example.statements
            $0.values.enumerated().forEach { enumerated in
                if enumerated.offset == 0, headers.values.first!.isEmpty {
                    description = enumerated.element
                } else {
                    statements = statements.map { $0.replacing(token: "<" + headers.values[enumerated.offset] + ">", with: enumerated.element) }
                }
            }
            return Requirement.Example(comments: $0.comments, identifier: nil, labels: $0.tags, description: description, statements: statements)
        }
    }

private let parseExamples: Parser<[Requirement.Example]> = Parser<[[Requirement.Example]]>.oneOrMore(
    parseExampleTemplate.or( parseExample.map { [$0] }),
    until: parseRuleDescription.then(parseExtendedDescription).map { _ in () }.or(.end).or(.not(parseExampleTemplate.or(parseExample.map { [$0] })))
).map {
    let joined = Array($0.joined())
    guard !joined.isEmpty else {
        throw "No Examples were parsed"
    }
    return joined
}

private let parseTextData: Parser<Requirement.Example.Statement.Data> = parseTextDelimiter
    .then(.oneOrMore(parseString, until: parseTextDelimiter))
    .then(parseTextDelimiter)
    .map { $0.joined(separator: "\n") }
    .map { Requirement.Example.Statement.Data.text($0) }

private let parseOptionalData: Parser<Requirement.Example.Statement.Data?> = parseTextData
    .or(parseMatrixData)
    .or(parseKeyValueData)
    .or(parseListData)
    .or(parseTableData).map { .some($0) }
    .or(Parser.end.map { Optional<Requirement.Example.Statement.Data>.none })
    .or(Parser(consumeLine: false) { _ in () }.map { Optional<Requirement.Example.Statement.Data>.none })

private let parseString = Parser<String> {
    return $0.trimmingCharacters(in: .whitespaces)
}

private let parseTextDelimiter = Parser<Void> {
    guard $0.trimmingCharacters(in: .whitespaces) == "\"\"\"" else {
        throw "Text data must start and end with the \"\"\" delimiter on a single line of its own"
    }
    return ()
}

private let parseKeyValueData = Parser.oneOrMore(parseTableRow, until: .end.or(.not(parseTableRow)))
    .map {
        guard $0.reduce(true, { $1.count == 1 && $0 ? true : false }) else {
            throw "Key Value Data must be formatted as a single column table"
        }
        return try Requirement.Example.Statement.Data.keyValues(OrderedDictionary($0.map {
            let keyValue = $0.first!.split(separator: ":").map { $0.trimmingCharacters(in: .whitespaces) }
            guard keyValue.count == 2 else {
                throw "Each row in Key Value data must have the format '| key: value |'"
            }
            return (keyValue[0], keyValue[1])
        }, uniquingKeysWith: { $1 }))
    }

private let parseListData = Parser.oneOrMore(parseTableRow, until: .end.or(.not(parseTableRow)))
    .map {
        guard $0.reduce(true, { $1.count == 1 && $0 ? true : false }) else {
            throw "List Data must be formatted as a single column table"
        }
        return Requirement.Example.Statement.Data.list($0.map { $0.first!.trimmingCharacters(in: .whitespaces) })
    }

private let parseTableData = Parser.oneOrMore(parseTableRow, until: .end.or(.not(parseTableRow)))
    .map {
        let columns = $0.first!
        guard columns.count >= 1 && $0.count >= 2 else {
            throw "Table Data must have at least one column and at least three rows"
        }
        guard $0.reduce(true, { $1.count == columns.count && $0 ? true : false  }) else {
            throw "All rows must have the same number of columns for valid Table Data"
        }
        return Requirement.Example.Statement.Data.table($0.dropFirst().map { row in
            return OrderedDictionary(uniqueKeysWithValues: columns.enumerated().map { ($0.element, row[$0.offset]) })
        })
    }

private let parseMatrixData = Parser.oneOrMore(parseTableRow, until: .end.or(.not(parseTableRow)))
    .map {
        let columns = $0.first!
        guard columns.count >= 2 && $0.count >= 3 else {
            throw "Matrix Data must have at least two columns and at least three rows"
        }
        guard $0.reduce(true, { $1.count == columns.count && $0 ? true : false  }) else {
            throw "All rows must have the same number of columns for valid Matrix Data"
        }
        guard columns.first?.trimmingCharacters(in: .whitespaces).isEmpty == true else {
            throw "The first column header of Matrix Data should be empty"
        }
        
        return Requirement.Example.Statement.Data.matrix(OrderedDictionary(uniqueKeysWithValues: $0.dropFirst().map { row in
            return (row[0].trimmingCharacters(in: .whitespaces), OrderedDictionary(uniqueKeysWithValues: Array(columns.dropFirst()).enumerated().map {
                return ($0.element, Array(row.dropFirst())[$0.offset])
            }))
        }))
    }

private let parseTableRow = Parser<[String]> {
    let trimmed = $0.trimmingCharacters(in: .whitespaces)
    guard trimmed.first == "|" && trimmed.last == "|" else {
        throw "Table rows must be contained inside pipe | characters"
    }
    let array = trimmed.trimmingCharacters(in: ["|"]).split(separator: "|").map({ $0.trimmingCharacters(in: .whitespaces) })
    guard !array.isEmpty else {
        throw "Line is not a table row because it doesn't contain data in between | characters"
    }
    return array
}
