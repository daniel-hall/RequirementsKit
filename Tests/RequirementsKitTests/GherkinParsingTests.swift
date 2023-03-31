//
//  GherkinParsingTests.swift
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

import RequirementsKit
import XCTest


class GherkinParsingTests: XCTestCase {

    func testValidExample() throws {
        let url = Bundle.module.url(forResource: "Valid", withExtension: "feature", subdirectory: "TestResources")!

        let expectedResult = File(url: url,
                                  comments: ["Auth stuff"],
                                  labels: ["featureLabel"],
                                  description: "Auth and Notifications",
                                  syntax: .gherkin,
                                  requirements: [
                Requirement(comments: ["1.1"], identifier: nil, labels: ["labelOne", "labelTwo", "featureLabel"], description: "The user can log in with a valid username and password", examples: [
                    .init(comments: ["1.1.1"], identifier: nil, labels: ["labelThree", "labelOne", "labelTwo", "featureLabel"], description: "Valid username and password", statements: [
                        .init(comments: nil, type: .if, description: "the user is on the log in screen", data: nil),
                        .init(comments: nil, type: .if, description: "the user has entered a valid username and password", data: .keyValues([
                            "username": "Snaffle",
                            "password": "guest"
                        ])),
                        .init(comments: nil, type: .when, description: "the user taps the submit button", data: nil),
                        .init(comments: nil, type: .expect, description: "the user should arrive on the home screen with expected elements visible", data: .list([
                            "logOutButton",
                            "accountTab",
                            "settingsButton"
                        ]))
                    ]),
                    .init(comments: ["1.1.2"], identifier: nil, labels: ["labelFour", "labelOne", "labelTwo", "featureLabel"], description: "Valid username with invalid password", statements: [
                        .init(comments: nil, type: .if, description: "the user is on the log in screen", data: nil),
                        .init(comments: ["Less than 8 characters is invalid"], type: .if, description: "the user has entered an INVALID username and password", data: .keyValues([
                            "username": "Snaffle",
                            "password": "admin"
                        ])),
                        .init(comments: nil, type: .when, description: "the user taps the submit button", data: nil),
                        .init(comments: nil, type: .expect, description: "the user should still be on the login screen", data: nil),
                        .init(comments: nil, type: .expect, description: "an error should be displayed", data: .text("Error\nInvalid Username or password"))
                    ])
                ]),
                Requirement(comments: ["1.2"], identifier: nil, labels: ["labelFive", "labelSix", "featureLabel"], description: "The user can log out", examples: [
                    .init(comments: ["1.2.1"], identifier: nil, labels: ["labelFive", "labelSix", "featureLabel"], description: nil, statements: [
                        .init(comments: nil, type: .if, description: "the user is on the home screen", data: nil),
                        .init(comments: nil, type: .when, description: "the user taps the log out button", data: nil),
                        .init(comments: nil, type: .expect, description: "the user should arrive on the login screen", data: nil),
                        .init(comments: nil, type: .expect, description: "the user should not be on the home screen", data: nil)
                    ]),
                    .init(comments: ["1.2.2", "Account screen not supported on Android yet"], identifier: nil, labels: ["ios", "labelFive", "labelSix", "featureLabel"], description: nil, statements: [
                        .init(comments: nil, type: .if, description: "the user is on the account screen", data: nil),
                        .init(comments: nil, type: .when, description: "the user taps the log out button", data: nil),
                        .init(comments: nil, type: .expect, description: "the user should arrive on the login screen", data: nil),
                        .init(comments: nil, type: .expect, description: "the user should not be on the account screen", data: nil)
                    ]),
                    .init(comments: ["1.2.3"], identifier: nil, labels: ["labelFive", "labelSix", "featureLabel"], description: nil, statements: [
                        .init(comments: nil, type: .if, description: "the user is on the settings screen", data: nil),
                        .init(comments: nil, type: .when, description: "the user taps the log out button", data: nil),
                        .init(comments: nil, type: .expect, description: "the user should arrive on the login screen", data: nil),
                        .init(comments: nil, type: .expect, description: "the user should not be on the settings screen", data: nil)
                    ])
                ]),
                Requirement(comments: ["Notification Stuff", "1.3"], identifier: nil, labels: ["featureLabel"], description: "Welcome notifications display correctly", examples: [
                    .init(comments: ["No premium subscription requirements defined yet", "1.3.1"], identifier: nil, labels: ["basic", "featureLabel"], description: "Basic subscription", statements: [
                        .init(comments: nil, type: .if, description: "the notification payloads are", data: .matrix([
                            "first": ["title": "Welcome", "body": "Thanks for subscribing, Pat!"],
                            "second": ["title": "Let's get started", "body": "Tap here to set up your preferences"]
                        ])),
                        .init(comments: nil, type: .when, description: "the notifications are received", data: .list(["first", "second"])),
                        .init(comments: nil, type: .expect, description: "two notification banners are on the lock screen", data: .table([
                            ["title": "Welcome", "body": "Thanks for subscribing, Pat!"],
                            ["title": "Let's get started", "body": "Tap here to set up your preferences"],
                        ])),
                        .init(comments: nil, type: .expect, description: "the application icon has a badge", data: nil)
                    ])
                ])
            ])

        let file = try parseGherkin(from: url)
        XCTAssertEqual(file, expectedResult)
    }
}
