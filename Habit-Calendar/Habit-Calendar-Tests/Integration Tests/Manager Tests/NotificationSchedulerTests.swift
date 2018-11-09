//
//  NotificationSchedulerTests.swift
//  JTAppleCalendar
//
//  Created by Tiago Maia Lopes on 19/07/18.
//

import XCTest
import UserNotifications
@testable import Habit_Calendar

/// Class in charge of testing the NotificationScheduler struct.
class NotificationSchedulerTests: IntegrationTestCase {

    // MARK: Properties

    /// The notification center mock used to test the scheduler.
    var notificationCenterMock: UserNotificationCenterMock!

    /// The scheduler being tested. It takes NotificationMO entities and
    /// schedules tbe user notifications related to each entity.
    var notificationScheduler: NotificationScheduler!

    // MARK: Setup/TearDown

    override func setUp() {
        super.setUp()

        // Instantiate the scheduler by using a notification center mock.
        notificationCenterMock = UserNotificationCenterMock(
            withAuthorization: true
        )
        notificationScheduler = NotificationScheduler(
            notificationManager: UserNotificationManager(notificationCenter: notificationCenterMock)
        )
    }

    override func tearDown() {
        super.tearDown()

        // Remove the instantiated entity.
        notificationCenterMock = nil
        notificationScheduler = nil
    }

    // MARK: Tests

    /// Test the factories for creating the trigger and content options of the pending requests.
    func testRequestContentAndTriggerFactory() {
        // Declare the dummy habit and fire tiem used to get the pending request values.
        let dummyHabit = habitFactory.makeDummy()
        guard let fireTime = (dummyHabit.fireTimes as? Set<FireTimeMO>)?.first else {
            XCTFail("To proceed the test needs a fire time.")
            return
        }

        // Make the content and trigger options out of the passed habit.
        let userNotificationOptions = notificationScheduler.makeNotificationOptions(
            from: fireTime
        )

        // Check on the content properties(texts).
        XCTAssertNotNil(
            userNotificationOptions.content,
            "The generated user notification should be set."
        )
        XCTAssertEqual(
            userNotificationOptions.content.title,
            dummyHabit.getTitleText(),
            "The user notification content should have the correct title text."
        )
        XCTAssertEqual(
            userNotificationOptions.content.subtitle,
            dummyHabit.getSubtitleText(),
            "The user notification content should have the correct subtitle text."
        )
        XCTAssertEqual(
            userNotificationOptions.content.body,
            dummyHabit.getBodyText(),
            "The user notification content should have the correct body text."
        )
        XCTAssertEqual(
            userNotificationOptions.content.userInfo["habitIdentifier"] as? String,
            dummyHabit.id,
            "The notification id should be passed within the user info."
        )
        XCTAssertEqual(
            userNotificationOptions.content.categoryIdentifier,
            UNNotificationCategory.Kind.dayPrompt(habitId: nil).identifier,
            "The category identifier should be informed."
        )
        XCTAssertNotNil(userNotificationOptions.content.sound)
        XCTAssertNotNil(userNotificationOptions.content.badge)

        // Declare the trigger as a UNTitmeIntervalNotificationTrigger.
        guard let calendarTrigger = userNotificationOptions.trigger as? UNCalendarNotificationTrigger else {
            XCTFail("The calendar trigger must be set.")
            return
        }

        // Assert on the date components, they need to be equal to the ones of the FireTimeMO.
        XCTAssertNotNil(calendarTrigger.nextTriggerDate())
        XCTAssertEqual(calendarTrigger.dateComponents.minute, fireTime.getFireTimeComponents().minute)
        XCTAssertEqual(calendarTrigger.dateComponents.hour, fireTime.getFireTimeComponents().hour)
    }

    func testSchedulingNotification() {
        XCTMarkNotImplemented()

        // Schedule a notification.
        let scheduleExpectation = XCTestExpectation(
            description: "Schedules an user notification related to a NotificationMO."
        )

        // Declare a dummy notification to be used.
        let dummyNotification = makeNotification()

        // Schedule it by passing the dummy entity.
        notificationScheduler.schedule(dummyNotification) { notification in
            // Check if the notification was indeed scheduled:
            self.notificationCenterMock.getPendingNotificationRequests { requests in
                // Search for the user notification request associated with it.
                let request = requests.filter { $0.identifier == notification.userNotificationId }.first

                if request == nil {
                    // If it wasn't found, make the test fail.
                    XCTFail("Couldn't find the scheduled user notification request.")
                }

                scheduleExpectation.fulfill()
            }
        }

        wait(for: [scheduleExpectation], timeout: 0.1)
    }

    func testUnschedulingNotification() {
        XCTMarkNotImplemented()

        // Declare the expectation to be fullfilled.
        let unscheduleExpectation = XCTestExpectation(
            description: "Unschedules an user notification associated with a NotificationMO."
        )

        // 1. Declare a dummy notification.
        let dummyNotification = makeNotification()

        // 2. Schedule it.
        notificationScheduler.schedule(dummyNotification) { _ in
            // 3. Unschedule it.
            self.notificationScheduler.unschedule(
                [dummyNotification]
            )

            // 4. Assert it was deleted by trying to fetch it
            // using the mock.
            self.notificationCenterMock.getPendingNotificationRequests { requests in
                XCTAssertTrue(
                    requests.filter {
                        $0.identifier == dummyNotification.userNotificationId
                    }.count == 0,
                    "The scheduled notification should have been deleted."
                )

                unscheduleExpectation.fulfill()
            }
        }

        wait(for: [unscheduleExpectation], timeout: 0.1)
    }

    func testSchedulingManyNotifications() {
        XCTMarkNotImplemented()

//        // 1. Declare the expectation to be fulfilled.
//        let scheduleExpectation = XCTestExpectation(
//            description: "Schedule a bunch of user notifications related to the NotificationMO entities."
//        )
//
//        // 2. Declare a dummy habit with n notifications.
//        let dummyHabit = habitFactory.makeDummy()
//
//        // 3. Schedule the notifications.
//        guard let notificationsSet = dummyHabit.notifications as? Set<NotificationMO> else {
//            XCTFail("Error: Couldn't get the dummy habit notifications.")
//            return
//        }
//        let notifications = Array(notificationsSet)
//        notificationScheduler.schedule(notifications)
//
//        // 4. Fetch them by using the mock and assert on each value.
//        self.notificationCenterMock.getPendingNotificationRequests { requests in
//
//            let identifiers = requests.map { $0.identifier }
//
//            // Setup a timer to get the notifications to be marked as
//            // executed. Since they're marked within the managed object
//            // context's thread, they aren't marked immediatelly,
//            // that's why a timer is needed here.
//            Timer.scheduledTimer(withTimeInterval: 0.01, repeats: false) { _ in
//                for notification in notifications {
//                    // Assert on the identifier.
//                    XCTAssertTrue(
//                        identifiers.contains(
//                            notification.userNotificationId!
//                        ),
//                        "The notification wasn't properly scheduled."
//                    )
//                }
//                scheduleExpectation.fulfill()
//            }
//        }

//        wait(for: [scheduleExpectation], timeout: 0.2)
    }

    func testUnschedulingManyNotifications() {
        XCTMarkNotImplemented()

//        // 1. Declare the expectation.
//        let unscheduleExpectation = XCTestExpectation(
//            description: "Unschedule many user notifications."
//        )
//
//        // 2. Declare a dummy habit and get its notifications.
//        let dummyHabit = habitFactory.makeDummy()
//
//        guard let notificationsSet = dummyHabit.notifications as? Set<NotificationMO> else {
//            XCTFail("Error: Couldn't get the dummy habit's notifications.")
//            return
//        }
//
//        let notifications = Array(notificationsSet)
//
//        // 3. Schedule all of them.
//        notificationScheduler.schedule(notifications)
//
//        // 4. Fire a timer to delete all of them.
//        Timer.scheduledTimer(withTimeInterval: 0.01, repeats: false) { _ in
//            self.notificationScheduler.unschedule(notifications)
//
//            // 5. Assert they were deleted by trying to fetch them from the
//            // mock.
//            self.notificationCenterMock.getPendingNotificationRequests { requests in
//                XCTAssertTrue(
//                    requests.isEmpty,
//                    "The notifications should have been deleted."
//                )
//                unscheduleExpectation.fulfill()
//            }
//        }
//        wait(for: [unscheduleExpectation], timeout: 0.2)
    }
}
