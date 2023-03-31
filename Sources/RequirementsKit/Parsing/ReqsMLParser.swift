//
//  ReqsMLParser.swift
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


struct Metadata {
    let identifier: String?
    let labels: [String]?
}

struct CommentsAndMetadata {
    let comments: [String]?
    let metadata: Metadata?
}

private struct ExampleRow {
    let comments: [String]?
    let metadata: Metadata?
    let values: [String]
}

func parseReqsML(from url: URL) throws -> File {
    let data = try Data(contentsOf: url)
    guard let string = String(data: data, encoding: .ascii) else {
        throw RequirementsKitError(errorDescription: "Couldn't decode text from file at url \(url)")
    }
    var lines = string.split(separator: "\n", omittingEmptySubsequences: false).enumerated().map { Line(number: $0.offset + 1, text: String($0.element)) }
    return File(url: url, comments: nil, labels: nil, description: nil, syntax: .reqsML, requirements: try Parser.oneOrMore(parseRequirement, until: .end)(&lines))
}

private let parseRequirement = parseOptionalCommentsAndMetadata.then(parseRequirementDescription).then(parseSingleExample).flattened().map { commentsAndMetadata, description, example in
    guard example.description?.tokens.isEmpty != false && example.statements.reduce(Set<String>(), { $0.union($1.tokens) }).isEmpty else {
        throw "A single example requirement shouldn't have template tokens without an Examples: table"
    }
    let combinedLabels = commentsAndMetadata?.metadata?.labels.combinedWith(example.labels)
    let example = Requirement.Example(comments: example.comments, identifier: example.identifier, labels: combinedLabels, explicitLabels: example.labels, description: example.description, statements: example.statements)
    return Requirement(comments: commentsAndMetadata?.comments, identifier: commentsAndMetadata?.metadata?.identifier, labels: commentsAndMetadata?.metadata?.labels, description: description, examples: [example])
}
    .or (
        parseOptionalCommentsAndMetadata.then(parseRequirementDescription).then(parseExamples).flattened().map { commentsAndMetadata, description, examples in
            let examples = examples.map { example in
                let combinedLabels = commentsAndMetadata?.metadata?.labels.combinedWith(example.labels)
                return Requirement.Example(comments: example.comments, identifier: example.identifier, labels: combinedLabels, explicitLabels: example.labels, description: example.description, statements: example.statements, exampleSet: example.exampleSet, specification: example.specification)
            }
            return Requirement(comments: commentsAndMetadata?.comments, identifier: commentsAndMetadata?.metadata?.identifier, labels: commentsAndMetadata?.metadata?.labels, description: description, examples: examples)
        }
    ).or (
        parseOptionalCommentsAndMetadata.then(parseRequirementDescription).then(parseExampleTemplate).flattened().map { commentsAndMetadata, description, examples in
            let examples = examples.map { example in
                let combinedLabels = commentsAndMetadata?.metadata?.labels.combinedWith(example.labels)
                return Requirement.Example(comments: example.comments, identifier: example.identifier, labels: combinedLabels, explicitLabels: example.labels, description: example.description, statements: example.statements, exampleSet: example.exampleSet, specification: example.specification)
            }
            return Requirement(comments: commentsAndMetadata?.comments, identifier: commentsAndMetadata?.metadata?.identifier, labels: commentsAndMetadata?.metadata?.labels, description: description, examples: examples)
        }
    )


private let parseComment = Parser<String> {
    let trimmed = $0.trimmingCharacters(in: .whitespaces)
    guard trimmed.hasPrefix("//") else {
        throw "Can't parse comment because line doesn't start with //"
    }
    return trimmed.drop { $0 == "/" }.trimmingCharacters(in: .whitespaces)
}

private let parseOptionalComments: Parser<[String]?> = Parser.zeroOrMore(parseComment, until: .end.or(.not( parseComment))).map { $0.isEmpty ? nil : $0 }

private let parseMetadata = Parser<Metadata> {
    let trimmed = $0.trimmingCharacters(in: .whitespaces)
    guard trimmed.first == "#" else {
        throw "Identifier or labels must be preceded by #"
    }
    let identifier = trimmed.dropFirst().prefix { $0 != "(" }.trimmingCharacters(in: .whitespaces)
    let labelString = trimmed.dropFirst().drop { $0 != "(" }.trimmingCharacters(in: .whitespaces)
    if labelString.isEmpty && identifier.isEmpty {
        throw "Can't have a # that isn't followed by either an identifier, labels in parentheses, or both"
    }
    if labelString.isEmpty {
        return Metadata(identifier: identifier, labels: nil)
    }
    guard labelString.last == ")" else {
        throw "Missing closing parenthesis on labels"
    }
    let labels = labelString.dropFirst().dropLast().trimmingCharacters(in: .whitespaces).split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    guard labels.first?.isEmpty == false else {
        throw "There must be at least one label specified inside parentheses ()"
    }
    return Metadata(identifier: identifier.isEmpty ? nil : identifier, labels: labels)
}

private let parseOptionalMetadata: Parser<Metadata?> = parseMetadata.map { .some($0) }.or (Parser<Metadata?>(consumeLine: false) { _ in nil })

private let parseOptionalCommentsAndMetadata: Parser<CommentsAndMetadata?> =
parseOptionalComments.then(parseOptionalMetadata).map {
    if $0.0 == nil && $0.1 == nil {
        return nil
    }
    return CommentsAndMetadata(comments: $0.0, metadata: $0.1)
}

private let parseRequirementDescription = Parser<String> {
    let trimmed = $0.trimmingCharacters(in: .whitespaces)
    guard trimmed.hasPrefix("Requirement:") == true else {
        throw "Line doesn't begin with \"Requirement:\""
    }
    let description = trimmed.drop { $0 != ":" }.dropFirst().trimmingCharacters(in: .whitespaces)
    guard !description.isEmpty else {
        throw "There must be a non-empty description of the Requirement after the the \"Requirement:\" keyword"
    }
    return description
}

private let parseExampleDescription = Parser<String> {
    let trimmed = $0.trimmingCharacters(in: .whitespaces)
    guard trimmed.hasPrefix("Example:") == true else {
        throw "Line doesn't begin with \"Example:\""
    }
    let description = trimmed.drop { $0 != ":" }.dropFirst().trimmingCharacters(in: .whitespaces)
    guard !description.isEmpty else {
        throw "There must be a non-empty description of the Example after the the \"Example:\" keyword"
    }
    return description
}

private let parseExampleSetDescription = Parser<String> {
    let trimmed = $0.trimmingCharacters(in: .whitespaces)
    guard trimmed.hasPrefix("ExampleSet:") == true || trimmed.hasPrefix("Example Set:") == true else {
        throw "Line doesn't begin with \"ExampleSet:\" or \"Example Set:\""
    }
    let description = trimmed.drop { $0 != ":" }.dropFirst().trimmingCharacters(in: .whitespaces)
    guard !description.isEmpty else {
        throw "There must be a non-empty description of the Example Set after the the \"ExampleSet:\" or \"Example Set:\" keyword"
    }
    return description
}

private let parseStatementKeyword = Parser<(Requirement.Example.StatementType, String)> {
    let type: Requirement.Example.StatementType
    let trimmed = $0.trimmingCharacters(in: .whitespaces)
    switch trimmed.prefix(upTo: trimmed.firstIndex(of: ":") ?? trimmed.startIndex) {
    case "If": type = .if
        case "When": type = .when
            case "Expect": type = .expect
            default: throw "No If, When, or Expect keyword found"
    }
    let description = trimmed.drop { $0 != ":" }.dropFirst().trimmingCharacters(in: .whitespaces)
    return (type, description)
}

private let parseListItem = parseOptionalComments.then(
    Parser<String> {
        let trimmed = $0.trimmingCharacters(in: .whitespaces)
        guard ["-", "*", "•"].contains(trimmed.first) else {
            throw "Not a statement list item because the line doesn't start with -, * or •"
        }
        let description = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
        guard !description.isEmpty else {
            throw "A statement list item must have a description and cannot be empty"
        }
        return description
    }
).then(parseOptionalData).flattened()

private let parseStatement = parseOptionalComments.then(parseStatementKeyword).then(parseOptionalData).flattened().map {
    Requirement.Example.Statement(comments: $0, type: $1.0, description: $1.1, data: $2)
}

private let parseEitherKindOfStatement = parseStatement.map {
    guard !$0.description.isEmpty else {
        throw "A Statement must have a description following the If:, When:, or Expect:"
    }
    return [$0]
}.or (
    parseStatement.then(.oneOrMore(parseListItem, until: .end.or(.not(parseListItem)) ) ).map { statement, items in
        guard statement.comments == nil else {
            throw "Comments for a statement list must be placed above each list item, not above the statement keyword"
        }
        guard statement.description.isEmpty else {
            throw "Can't have a Statement that contains both a description and a list. Remove any text after the \(statement.type.rawValue.capitalized): keyword"
        }
        return items.map {
            Requirement.Example.Statement(comments: $0.0, type: statement.type, description: $0.1, data: $0.2)
        }
    }
)

private let parseStatements = Parser.oneOrMore(parseEitherKindOfStatement, until: .end.or(.not( parseEitherKindOfStatement))).map { Array($0.joined()) }

private let parseExample = parseOptionalCommentsAndMetadata.then(parseExampleDescription).then(parseStatements ).flattened().map { commentsAndMetadata, description, statements in
    guard !statements.isEmpty else {
        throw "An Example must contain one or more Statements"
    }
    return Requirement.Example(comments: commentsAndMetadata?.comments, identifier: commentsAndMetadata?.metadata?.identifier, labels: commentsAndMetadata?.metadata?.labels, description: description, statements: statements)
}

private let parseSingleExample = parseOptionalCommentsAndMetadata.then(parseStatements).map {
    guard $0 == nil else {
        throw "When a Requirement has a single in-line Example that Example can't include separate comments, labels or identifiers"
    }
    return Requirement.Example(comments: nil, identifier: nil, labels: nil, description: nil, statements: $1)
}

private let parseExamplesKeyword = Parser<Void> {
    let trimmed = $0.trimmingCharacters(in: .whitespaces)
    guard trimmed.hasPrefix("Examples:") else {
        throw "No Examples: keyword found"
    }
    guard trimmed.replacingOccurrences(of: "Examples:", with: "").isEmpty else {
        throw "The Examples: keyword should not have any description after it and should be on a line by itself"
    }
    return ()
}

private let parseExampleRowWithoutComments =  Parser<ExampleRow> {
    let trimmed = $0.trimmingCharacters(in: .whitespaces)
    let prefix = trimmed.prefix { $0 != "|" }.trimmingCharacters(in: .whitespaces)
    let metadata: Metadata?
HandlePrefix:
    if !prefix.isEmpty {
        guard prefix.first == "#" else {
            throw "Examples can only contain a valid identifier and/or labels before the table, e.g. '#identifier (labelOne, labelTwo) | some value | another value |'"
        }
        let identifier = prefix.dropFirst().prefix { $0 != "(" }.trimmingCharacters(in: .whitespaces)
        let labelString = prefix.dropFirst().drop { $0 != "(" }.trimmingCharacters(in: .whitespaces)
        if labelString.isEmpty && identifier.isEmpty {
            throw "Can't have a # that isn't followed by either an identifier, labels in parentheses, or both"
        }
        if labelString.isEmpty {
            metadata = .init(identifier: identifier, labels: nil)
            break HandlePrefix
        }
        guard labelString.last == ")" else {
            throw "Missing closing parenthesis on labels"
        }
        let labels = labelString.dropFirst().dropLast().trimmingCharacters(in: .whitespaces).split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard labels.first?.isEmpty == false else {
            throw "There must be at least one label specified inside parentheses ()"
        }
        metadata = .init(identifier: identifier.isEmpty ? nil : identifier, labels: labels)
        break HandlePrefix
    } else {
        metadata = nil
    }
    let row = trimmed.drop { $0 != "|" }
    guard row.first == "|" && row.last == "|" else {
        throw "Examples rows must be in table format inside pipe | characters"
    }
    let array = row.trimmingCharacters(in: ["|"]).split(separator: "|").map({ $0.trimmingCharacters(in: .whitespaces) })
    guard !array.isEmpty else {
        throw "Line is not an Examples row because it doesn't contain data in between | characters"
    }
    return ExampleRow(comments: nil, metadata: metadata, values: array)
}

private let parseExampleRow: Parser<ExampleRow> = parseOptionalComments
    .then(parseExampleRowWithoutComments)
    .map { ExampleRow(comments: $0.0, metadata: $0.1.metadata, values: $0.1.values) }

private let parseExampleSet = parseOptionalCommentsAndMetadata.then(parseExampleSetDescription).then(parseStatements).then(parseExamplesKeyword).then(parseExampleRows).flattened().map { commentsAndMetadata, description, statements, exampleRows in

    let exampleSet = Requirement.Example._ExampleSet(comments: commentsAndMetadata?.comments, identifier:  commentsAndMetadata?.metadata?.identifier, labels: commentsAndMetadata?.metadata?.labels, description: description, statements: statements)

    guard statements.reduce(false, { ($0 || !$1.tokens.isEmpty) ? true : false }) else {
        throw "There are no tokens present in the Example Set statements"
    }
    guard exampleRows.count >= 3 else {
        throw "Examples should be a table containing at least 3 rows: a headers row, a separator row, and at least one row of values"
    }
    let headers = exampleRows.first!
    if headers.values.count == 1, headers.values.first!.isEmpty {
        throw "Examples table can't have a single column with no header value"
    }
    guard headers.values.dropFirst().reduce(true, { !$1.isEmpty && $0 == true ? true : false }) else {
        throw "Only the first column of an Examples table can have an empty header, which signifies that the column will be used for each Example's description"
    }
    if headers.values.first!.isEmpty {
        guard exampleRows.dropFirst(2).reduce(true, { !$1.values.first!.trimmingCharacters(in: .whitespaces).isEmpty && $0 == true ? true : false }) else {
            throw "If the Examples table includes a first column containing descriptions, there must be a non-empty description provided for each row"
        }
    }
    let separators = exampleRows.dropFirst().first!
    guard headers.comments == nil && headers.metadata == nil else {
        throw "The Examples header row can't have comments, identifiers or labels"
    }
    guard separators.values.reduce(true, {
        let array = $1.trimmingCharacters(in: .whitespaces).split(separator: "-", omittingEmptySubsequences: false)
        return array.count >= 4 && array.joined().isEmpty
    }) else {
        throw "Examples must start with a header row, followed by a row with '----' (three or more hyphens) for each column"
    }

    guard exampleRows.reduce(true, { $0 && $1.values.count == headers.values.count }) else {
        throw "Every row in the Examples table must have the same number of colums"
    }

    guard Set(exampleSet.tokens.map { $0.trimmingCharacters(in: .init(charactersIn: "<>")) }) == Set(headers.values.drop { $0.isEmpty }) else {
        throw "Every unique token must have exactly one matching column in the Examples table"
    }

    return exampleRows.dropFirst(2).map {
        var description: String?
        var statements = exampleSet.statements
        let specification = Requirement.Example._ExampleSpecification(comments: $0.comments, identifier: $0.metadata?.identifier, description: headers.values.first!.isEmpty ? $0.values.first : nil, labels: $0.metadata?.labels, values: .init(uniqueKeysWithValues: zip(headers.values, $0.values)))
        $0.values.enumerated().forEach { enumerated in
            if enumerated.offset == 0 {
                if headers.values.first!.isEmpty {
                    description = enumerated.element
                } else {
                    description = exampleSet.description
                }
            }
            description = description?.replacingOccurrences(of: "<" + headers.values[enumerated.offset] + ">", with: enumerated.element)
            statements = statements.map { $0.replacing(token: "<" + headers.values[enumerated.offset] + ">", with: enumerated.element) }
        }
        return Requirement.Example(comments: $0.comments, identifier: $0.metadata?.identifier, labels: $0.metadata?.labels, explicitLabels: $0.metadata?.labels, description: description, statements: statements, exampleSet: exampleSet, specification: specification)
    }
}

private let parseExampleRows = Parser.oneOrMore(parseExampleRow, until: .end.or(.not(parseExampleRow)))

private let parseExampleTemplate = parseSingleExample.then(parseExamplesKeyword).then(parseExampleRows).map { example, examples in
    guard !example.tokens.isEmpty else {
        throw "There are no tokens present in the Example Set"
    }
    guard examples.count >= 3 else {
        throw "Examples should be a table containing at least 3 rows: a headers row, a separator row, and at least one row of values"
    }
    let headers = examples.first!
    if headers.values.count == 1, headers.values.first!.isEmpty {
        throw "Examples table can't have a single column with no header value"
    }
    guard headers.values.dropFirst().reduce(true, { !$1.isEmpty && $0 == true ? true : false }) else {
        throw "Only the first column of an Examples table can have an empty header, which signifies that the column will be used for each Example's description"
    }
    if headers.values.first!.isEmpty {
        guard examples.dropFirst(2).reduce(true, { !$1.values.first!.trimmingCharacters(in: .whitespaces).isEmpty && $0 == true ? true : false }) else {
            throw "If the Examples table includes a first column containing descriptions, there must be a non-empty description provided for each row"
        }
    }
    let separators = examples.dropFirst().first!
    guard headers.comments == nil && headers.metadata == nil else {
        throw "The Examples header row can't have comments, identifiers or labels"
    }
    guard separators.values.reduce(true, {
        let array = $1.trimmingCharacters(in: .whitespaces).split(separator: "-", omittingEmptySubsequences: false)
        return array.count >= 4 && array.joined().isEmpty
    }) else {
        throw "Examples must start with a header row, followed by a row with '----' (three or more hyphens) for each column"
    }
    guard examples.reduce(true, { $0 && $1.values.count == headers.values.count }) else {
        throw "Every row in the Examples table must have the same number of colums"
    }
    guard Set(example.tokens.map { $0.trimmingCharacters(in: .init(charactersIn: "<>")) }) == Set(headers.values.drop { $0.isEmpty }) else {
        throw "Every unique template variable must have exactly one matching column in the Examples table"
    }

    let exampleSet = Requirement.Example._ExampleSet(comments: nil, identifier: nil, labels: nil, description: nil, statements: example.statements)

    return examples.dropFirst(2).map {
        var description: String?
        var statements = example.statements
        $0.values.enumerated().forEach { enumerated in
            if enumerated.offset == 0, headers.values.first!.isEmpty {
                description = enumerated.element
            } else {
                description = description?.replacingOccurrences(of: "<" + headers.values[enumerated.offset] + ">", with: enumerated.element)
                statements = statements.map { $0.replacing(token: "<" + headers.values[enumerated.offset] + ">", with: enumerated.element) }
            }
        }
        let headerValues = (headers.values.first?.isEmpty == true) ? Array(headers.values.dropFirst()) : headers.values
        let values = (headers.values.first?.isEmpty == true) ? Array($0.values.dropFirst()) : $0.values
        let specification = Requirement.Example._ExampleSpecification(comments: $0.comments, identifier: $0.metadata?.identifier, description: description, labels: $0.metadata?.labels, values: .init(uniqueKeysWithValues: zip(headerValues, values)))
        return Requirement.Example(comments: $0.comments, identifier: $0.metadata?.identifier, labels: $0.metadata?.labels, explicitLabels: $0.metadata?.labels, description: description, statements: statements, exampleSet: exampleSet, specification: specification)
    }
}

private let parseTextData: Parser<Requirement.Example.Statement.Data> = parseTextDelimiter.then( .oneOrMore(parseString, until: parseTextDelimiter)).then(parseTextDelimiter).map { $0.joined(separator: "\n") }.map { Requirement.Example.Statement.Data.text($0) }

private let parseOptionalData: Parser<Requirement.Example.Statement.Data?> =
parseTextData
    .or(parseMatrixData)
    .or(parseTableData)
    .or(parseKeyValueData)
    .or(parseListData).map { .some($0) }
    .or(Parser.end.map { Optional<Requirement.Example.Statement.Data>.none })
    .or(Parser(consumeLine: false) { _ in () }.map { Optional<Requirement.Example.Statement.Data>.none })

private let parseString = Parser<String> {
    return $0.trimmingCharacters(in: .whitespaces)
}

private let parseTextDelimiter = Parser<Void> {
    guard $0.trimmingCharacters(in: .whitespaces) == "```" else {
        throw "Text data must start and end with the ``` delimiter on a single line of its own"
    }
    return ()
}

private let parseKeyValueData = Parser.oneOrMore(parseTableRow, until: .end.or(.not(parseTableRow))).map {
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

private let parseListData = Parser.oneOrMore(parseTableRow, until: .end.or(.not(parseTableRow))).map {
    guard $0.reduce(true, { $1.count == 1 && $0 ? true : false }) else {
        throw "List Data must be formatted as a single column table"
    }
    return Requirement.Example.Statement.Data.list($0.map { $0.first!.trimmingCharacters(in: .whitespaces) })
}

private let parseTableData = Parser.oneOrMore(parseTableRow, until: .end.or(.not(parseTableRow))).map {
    let columns = $0.first!
    guard columns.count >= 1 && $0.count >= 3 else {
        throw "Table Data must have at least one column and at least three rows"
    }
    guard $0.dropFirst().first!.reduce(true, {
        let array = $1.trimmingCharacters(in: .whitespaces).split(separator: "-", omittingEmptySubsequences: false)
        return array.count >= 4 && array.joined().isEmpty
    }) else {
        throw "Table Data must start with a header row, followed by a row with '----' (three or more hyphens) for each column"
    }
    guard $0.reduce(true, { $1.count == columns.count && $0 ? true : false  }) else {
        throw "All rows must have the same number of columns for valid Table Data"
    }
    return Requirement.Example.Statement.Data.table($0.dropFirst(2).map { row in
        return OrderedDictionary(uniqueKeysWithValues: columns.enumerated().map { ($0.element, row[$0.offset]) })
    })
}

private let parseMatrixData = Parser.oneOrMore(parseTableRow, until: .end.or(.not(parseTableRow))).map {
    let columns = $0.first!
    guard columns.count >= 2 && $0.count >= 3 else {
        throw "Matrix Data must have at least two columns and at least three rows"
    }
    guard $0.dropFirst().first!.reduce(true, {
        let array = $1.trimmingCharacters(in: .whitespaces).split(separator: "-", omittingEmptySubsequences: false)
        return array.count >= 4 && array.joined().isEmpty
    }) else {
        throw "Matrix Data must start with a header row, followed by a row with '----' (three or more hyphens) for each column"
    }
    guard $0.reduce(true, { $1.count == columns.count && $0 ? true : false  }) else {
        throw "All rows must have the same number of columns for valid Matrix Data"
    }
    guard columns.first?.trimmingCharacters(in: .whitespaces).isEmpty == true else {
        throw "The first column header of Matrix Data should be empty"
    }

    return Requirement.Example.Statement.Data.matrix(OrderedDictionary(uniqueKeysWithValues: $0.dropFirst(2).map { row in
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

private let parseExamples: Parser<[Requirement.Example]> = Parser.oneOrMore(parseExampleSet.or(parseExample.map { [$0] }), until: .end.or(.not(parseExampleSet.or(parseExample.map { [$0] })))).map { Array($0.joined()) }
