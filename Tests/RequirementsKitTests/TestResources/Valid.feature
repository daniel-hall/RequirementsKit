# Auth stuff
@featureLabel
Feature: Auth and Notifications

# 1.1
@labelOne @labelTwo
Rule: The user can log in with a valid username and password

    # 1.1.1
    @labelThree
    Example: Valid username and password
        Given the user is on the log in screen
        And the user has entered a valid username and password
          | username: Snaffle |
          | password: guest   |

        When the user taps the submit button

        Then the user should arrive on the home screen with expected elements visible
          | logOutButton   |
          | accountTab     |
          | settingsButton |

    # 1.1.2
    @labelFour
    Scenario: Valid username with invalid password
        Given the user is on the log in screen

        # Less than 8 characters is invalid
        And the user has entered an INVALID username and password
          | username: Snaffle |
          | password: admin   |

        When the user taps the submit button

        Then the user should still be on the login screen
        And an error should be displayed
          """
          Error
          Invalid Username or password
          """

# 1.2
@labelFive @labelSix
Rule: The user can log out

  Scenario Outline: Logging out
    Given the user is on the <screen-name> screen
    When the user taps the log out button
    Then the user should arrive on the login screen
    And the user should not be on the <screen-name> screen

    Examples:
      | screen-name |
      # 1.2.1
      | home        |
      # 1.2.2
      # Account screen not supported on Android yet
      @ios
      | account     |
      # 1.2.3
      | settings    |

# Notification Stuff
# 1.3
Rule: Welcome notifications display correctly

  # No premium subscription requirements defined yet
  # 1.3.1
  @basic
  Example: Basic subscription

    Given the notification payloads are
      |        | title             | body                                |
      | first  | Welcome           | Thanks for subscribing, Pat!        |
      | second | Let's get started | Tap here to set up your preferences |

    When the notifications are received
      | first  |
      | second |

    Then two notification banners are on the lock screen
      | title             | body                                |
      | Welcome           | Thanks for subscribing, Pat!        |
      | Let's get started | Tap here to set up your preferences |

    And the application icon has a badge
