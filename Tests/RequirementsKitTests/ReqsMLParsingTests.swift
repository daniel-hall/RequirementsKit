//
//  ReqsMLParsingTests.swift
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


class ReqsMLParsingTests: XCTestCase {

    func testValidExample() throws {

        let url = Bundle.module.url(forResource: "Valid", withExtension: "requirements", subdirectory: "TestResources")!

        let expectedResult = File(url: url,
                                  comments: nil,
                                  labels: nil,
                                  description: nil,
                                  syntax: .reqsML,
                                  requirements: [
                Requirement(comments: ["Auth stuff"], identifier: "1.1", labels: ["labelOne", "labelTwo"], description: "The user can log in with a valid username and password", examples: [
                    .init(comments: nil, identifier: "1.1.1", labels: ["labelThree", "labelOne", "labelTwo"], description: "Valid username and password", statements: [
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
                    .init(comments: nil, identifier: "1.1.2", labels: ["labelFour", "labelOne", "labelTwo"], description: "Valid username with invalid password", statements: [
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
                Requirement(comments: nil, identifier: "1.2", labels: ["labelFive", "labelSix"], description: "The user can log out", examples: [
                    .init(comments: nil, identifier: "1.2.1", labels: ["labelFive", "labelSix"], description: "Log out from home screen", statements: [
                        .init(comments: nil, type: .if, description: "the user is on the home screen", data: nil),
                        .init(comments: nil, type: .when, description: "the user taps the log out button", data: nil),
                        .init(comments: nil, type: .expect, description: "the user should arrive on the login screen", data: nil),
                        .init(comments: nil, type: .expect, description: "the user should not be on the home screen", data: nil)
                    ]),
                    .init(comments: ["Account screen not supported on Android yet"], identifier: "1.2.2", labels: ["ios", "labelFive", "labelSix"], description: "Log out from account screen", statements: [
                        .init(comments: nil, type: .if, description: "the user is on the account screen", data: nil),
                        .init(comments: nil, type: .when, description: "the user taps the log out button", data: nil),
                        .init(comments: nil, type: .expect, description: "the user should arrive on the login screen", data: nil),
                        .init(comments: nil, type: .expect, description: "the user should not be on the account screen", data: nil)
                    ]),
                    .init(comments: nil, identifier: "1.2.3", labels: ["labelFive", "labelSix"], description: "Log out from settings screen", statements: [
                        .init(comments: nil, type: .if, description: "the user is on the settings screen", data: nil),
                        .init(comments: nil, type: .when, description: "the user taps the log out button", data: nil),
                        .init(comments: nil, type: .expect, description: "the user should arrive on the login screen", data: nil),
                        .init(comments: nil, type: .expect, description: "the user should not be on the settings screen", data: nil)
                    ])
                ]),
                Requirement(comments: ["Notification Stuff"], identifier: "1.3", labels: nil, description: "Welcome notifications display correctly", examples: [
                    .init(comments: ["No premium subscription requirements defined yet"], identifier: "1.3.1", labels: ["basic"], description: "Basic subscription", statements: [
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
                ]),
                Requirement(identifier: "1.4", description: "If the user isn't logged in, certain buttons should be disabled", examples: [
                    .init(description: "User can't proceed past splash screen", statements: [
                        .init(type: .if, description: "The user is not logged in"),
                        .init(type: .if, description: "The user is on the splash screen"),
                        .init(type: .expect, description: "The proceed button is disabled")
                    ]),
                    .init(description: "If the user isn't logged in on the home screen, disable the settings button", statements: [
                        .init(type: .if, description: "The user is not logged in"),
                        .init(type: .if, description: "The user is on the home screen"),
                        .init(type: .expect, description: "The settings button should be disabled")

                    ]),
                    .init(description: "If the user isn't logged in on the home screen, disable the account button", statements: [
                        .init(type: .if, description: "The user is not logged in"),
                        .init(type: .if, description: "The user is on the home screen"),
                        .init(type: .expect, description: "The account button should be disabled")
                    ]),
                    .init(description: "If the user isn't logged in on the notifications screen, disable the more button", statements: [
                        .init(type: .if, description: "The user is not logged in"),
                        .init(type: .if, description: "The user is on the notifications screen"),
                        .init(type: .expect, description: "The more button should be disabled")
                    ]),
                    .init(description: "User is already on the Settings screen and logged out automatically", statements: [
                        .init(type: .if, description: "The user is logged in"),
                        .init(type: .if, description: "The user is on the settings screen"),
                        .init(type: .when, description: "The app is backgrounded"),
                        .init(type: .when, description: "The user is logged out in the background"),
                        .init(type: .when, description: "The app is foregrounded"),
                        .init(type: .expect, description: "The user should be on the log in screen")
                    ])
                ])
            ])

        let file = try File.parseFrom(url: url)
        XCTAssertEqual(file, expectedResult)
    }
}
