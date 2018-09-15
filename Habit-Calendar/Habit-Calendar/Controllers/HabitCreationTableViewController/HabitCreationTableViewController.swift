//
//  HabitCreationViewController.swift
//  Active
//
//  Created by Tiago Maia Lopes on 02/07/18.
//  Copyright © 2018 Tiago Maia Lopes. All rights reserved.
//

import UIKit
import CoreData

/// Controller used to allow the user to create/edit habits.
class HabitCreationTableViewController: UITableViewController {

    // MARK: Properties

    /// The segue identifier for the DaysSelection controller.
    private let daysSelectionSegue = "Show days selection controller"

    /// The segue identifier for the NotificationsSelection controller.
    private let notificationSelectionSegue = "Show fire dates selection controller"

    /// The label displaying the name field's title.
    @IBOutlet weak var nameFieldTitleLabel: UILabel!

    /// The text field used to give the habit a name.
    @IBOutlet weak var nameTextField: UITextField!

    /// The button used to store the habit.
    @IBOutlet weak var doneButton: UIButton!

    /// The label displaying the number of selected days.
    @IBOutlet weak var daysAmountLabel: UILabel!

    /// The title label of the days' challenge field.
    @IBOutlet weak var challengeFieldTitleLabel: UILabel!

    /// The question label of the days' challenge field.
    @IBOutlet weak var challengeFieldQuestionTitle: UILabel!

    /// The label displaying the first day in the selected sequence.
    @IBOutlet weak var fromDayLabel: UILabel!

    /// The label displaying the last day in the selected sequence.
    @IBOutlet weak var toDayLabel: UILabel!

    /// The label displaying the amount of fire times selected.
    @IBOutlet weak var fireTimesAmountLabel: UILabel!

    /// The label displaying the of fire time times selected.
    @IBOutlet weak var fireTimesLabel: UILabel!

    /// The label displaying the color field's title.
    @IBOutlet weak var colorFieldTitleLabel: UILabel!

    /// The color's field color picker view.
    @IBOutlet weak var colorPicker: ColorsPickerView!

    /// The container in which the habit is going to be persisted.
    var container: NSPersistentContainer!

    /// The habit storage used for this controller to
    /// create/edit the habit.
    var habitStore: HabitStorage!

    /// The user storage used to associate the main user
    /// to any created habits.
    var userStore: UserStorage!

    /// The habit entity being editted.
    var habit: HabitMO?

    /// Flag indicating if there's a habit being created or editted.
    var isEditingHabit: Bool {
        return habit != nil
    }

    /// The habit's name being informed by the user.
    var name: String? {
        didSet {
            // Update the button state.
            configureDoneButton()
        }
    }

    /// The color to be used as the theme one in case the user hasn't selected any.
    let defaultThemeColor = UIColor(red: 47/255, green: 54/255, blue: 64/255, alpha: 1)

    /// The habit's color selected by the user.
    var habitColor: HabitMO.Color? {
        didSet {
            displayThemeColor()
            // Update the button state.
            configureDoneButton()
        }
    }

    /// The habit's days the user has selected.
    var days: [Date]? {
        didSet {
            configureDaysLabels()
            // Update the button state.
            configureDoneButton()
        }
    }

    /// The habit's notification fire times the user has selected.
    var fireTimes: [FireTimesDisplayable.FireTime]? {
        didSet {
            // Update the button state.
            configureDoneButton()
        }
    }

    /// The notification manager used to get the app's authorization status.
    var notificationManager: UserNotificationManager!

    /// Flag indicating if notifications are authorized or not.
    var areNotificationsAuthorized: Bool = true

    // MARK: Deinitializers

    deinit {
        stopObserving()
    }

    // MARK: ViewController Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // Assert on the values of the injected dependencies (implicitly unwrapped).
        assert(userStore != nil, "Error: Failed to inject the user store.")
        assert(container != nil, "Error: failed to inject the persistent container.")
        assert(habitStore != nil, "Error: failed to inject the habit store.")
        assert(notificationManager != nil, "Error: failed to inject the notification manager.")

        // Observe the app's active event to display if the user notifications are allowed.
        startObserving()

        // Configure the appearance of the navigation bar to never use the
        // large titles.
        navigationItem.largeTitleDisplayMode = .never

        configureNameField()
        configureColorField()

        // Display the initial text of the days labels.
        configureDaysLabels()

        // Display the initial text of the notifications labels.
        displayFireTimes(fireTimes ?? [])

        // Set the done button's initial state.
        configureDoneButton()

        // If there's a passed habit, it means that the controller should edit it.
        if isEditingHabit {
            title = "Edit habit"
            displayHabitProperties()
            configureDeletionButton()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Display the theme color.
        displayThemeColor()

        // Display information about the authorization status.
        displayNotificationAvailability()
    }

    // MARK: Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Declare the theme color to be passed to the controllers.
        let themeColor = self.habitColor?.uiColor ?? defaultThemeColor

        switch segue.identifier {
        case daysSelectionSegue:
            // Associate the DaysSelectionController's delegate.
            if let daysController = segue.destination as? HabitDaysSelectionViewController {
                daysController.delegate = self
                daysController.preSelectedDays = days
                daysController.themeColor = themeColor
            } else {
                assertionFailure("Error: Couldn't get the days selection controller.")
            }

        case notificationSelectionSegue:
            // Associate the NotificationsSelectionController's delegate.
            if let notificationsController = segue.destination as? FireTimesSelectionViewController {
                notificationsController.delegate = self

                if let fireTimes = fireTimes {
                    notificationsController.selectedFireTimes = Set(fireTimes)
                } else if let fireTimes = (habit?.fireTimes as? Set<FireTimeMO>)?.map({ $0.getFireTimeComponents() }) {
                    // In case the habit is being editted and has some fire times to be displayed.
                    notificationsController.selectedFireTimes = Set(fireTimes)
                }
                notificationsController.themeColor = themeColor
            } else {
                assertionFailure("Error: Couldn't get the fire dates selection controller.")
            }
        default:
            break
        }
    }

    // MARK: Actions

    /// Creates the habit.
    @IBAction func storeHabit(_ sender: UIButton) {
        // Make assertions on the required values to create/update a habit.
        // If the habit is being created, make the assertions.
        if !isEditingHabit {
            assert(!(name ?? "").isEmpty, "Error: the habit's name must be a valid value.")
            assert(habitColor != nil, "Error: the habit's color must be a valid value.")
            assert(!(days ?? []).isEmpty, "Error: the habit's days must have a valid value.")
        }

        // If there's no previous habit, create and persist a new one.
        container.performBackgroundTask { context in
            // Retrieve the app's current user before using it.
            guard let user = self.userStore.getUser(using: context) else {
                // It's a bug if there's no user. The user should be created on
                // the first launch.
                assertionFailure("Inconsistency: There's no user in the database. It must be set.")
                return
            }

            if !self.isEditingHabit {
                _ = self.habitStore.create(
                    using: context,
                    user: user,
                    name: self.name!,
                    color: self.habitColor!,
                    days: self.days!,
                    and: self.fireTimes
                )
            } else {
                // If there's a previous habit, update it with the new values.
                guard let habitToEdit = self.habitStore.habit(using: context, and: self.habit!.id!) else {
                    assertionFailure("The habit should be correclty fetched.")
                    return
                }

                _ = self.habitStore.edit(
                    habitToEdit,
                    using: context,
                    name: self.name,
                    color: self.habitColor,
                    days: self.days,
                    and: self.fireTimes
                )
            }

            // TODO: Report any errors to the user.
            do {
                try context.save()
            } catch {
                assertionFailure("Error: Couldn't save the new habit entity.")
            }
        }

        navigationController?.popViewController(
            animated: true
        )
    }

    /// Displays the deletion alert.
    @objc private func deleteHabit(sender: UIBarButtonItem) {
        // Alert the user to see if the deletion is really wanted:
        // Declare the alert.
        let alert = UIAlertController(
            title: "Delete",
            message: """
Are you sure you want to delete this habit? Deleting this habit makes all the history \
information unavailable.
""",
            preferredStyle: .alert
        )
        // Declare its actions.
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
            // If so, delete the habit using the container's viewContext.
            // Pop the current controller.
            self.habitStore.delete(self.habit!, from: self.container.viewContext)
            self.navigationController?.popToRootViewController(animated: true)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .default))

        // Present it.
        present(alert, animated: true)
    }

    // MARK: Imperatives

    /// Enables or disables the button depending on the habit's filled data.
    private func configureDoneButton() {
        if let habitToEdit = habit {
            // Change the button's title if there's a habit to be editted.
            doneButton.setTitle("Edit", for: .normal)

            // Check if anything changed.
            let isNameDifferent = !(name ?? "").isEmpty && name != habitToEdit.name
            let isColorDifferent = habitColor != nil && habitColor != habitToEdit.getColor()
            let isChallengeDifferent = days != nil && !days!.isEmpty
            let areFireTimesDifferent = fireTimes != nil

            doneButton.isEnabled = isNameDifferent || isColorDifferent || isChallengeDifferent || areFireTimesDifferent
        } else {
            // Check if the name and days are correctly set.
            doneButton.isEnabled = !(name ?? "").isEmpty && !(days ?? []).isEmpty && habitColor != nil
        }
    }

    /// Display the provided habit's data for edittion.
    private func displayHabitProperties() {
        // Display the habit's name.
        nameTextField.text = habit!.name

        // Display the habit's color.
        habitColor = habit!.getColor()
        colorPicker.selectedColor = habitColor!.uiColor

        // Display the habit's current days' challenge.

        // Display the habit's fire times.
        if habit!.fireTimes!.count > 0 {
            guard let fireTimesSet = habit?.fireTimes as? Set<FireTimeMO> else {
                assertionFailure("Error: couldn't get the FireTimeMO entities.")
                return
            }
            displayFireTimes(fireTimesSet.map { $0.getFireTimeComponents() })
        }
    }

    /// Configures and displays the deletion nav bar button.
    private func configureDeletionButton() {
        let trashButton = UIBarButtonItem(
            barButtonSystemItem: .trash,
            target: self,
            action: #selector(deleteHabit(sender:))
        )
        trashButton.tintColor = .red
        navigationItem.setRightBarButton(trashButton, animated: false)
    }
}

extension HabitCreationTableViewController {

    // MARK: types

    /// The fields used for creating a new habit.
    private enum Field: Int {
        case name = 0,
            color,
            days,
            fireTimes,
            notificationsNotAuthorized
    }

    // MARK: TableView delegate methods

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if let field = Field(rawValue: indexPath.row) {
            switch field {
            case .name:
                return 130
            case .color:
                // Compute the expected height for the color picker field.
                let marginsValue: CGFloat = 20
                let titleExpectedHeight: CGFloat = 40
                let stackVerticalSpace: CGFloat = 10

                return marginsValue + titleExpectedHeight + stackVerticalSpace + colorPicker.getExpectedHeight()
            case .days:
                return 160
            case .fireTimes:
                return areNotificationsAuthorized ? 172 : 0
            case .notificationsNotAuthorized:
                return !areNotificationsAuthorized ? 140 : 0
            }
        } else {
            return 0
        }
    }
}
