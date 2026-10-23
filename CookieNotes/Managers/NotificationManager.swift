//
//  NotificationManager.swift
//  CookieNotes
//

import Foundation
import SwiftUI
import UserNotifications

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    @Published var shouldShowLoginPrompt = false
    @Published var lastLoginDate: Date?

    private let userDefaults = UserDefaults.standard
    private let lastLoginKey = "last_login_date"
    private let clearedLegacyNotificationsKey = "cookienotes.didClearLegacyNotifications"
    private let reminderID = "cookienotes.inactivityReminder"
    /// In-app welcome prompt after a week away.
    static let promptInterval: TimeInterval = 7 * 24 * 60 * 60
    /// Local notification if the app has not been opened for a while.
    static let reminderInterval: TimeInterval = 5 * 24 * 60 * 60

    private init() {
        loadLastLoginDate()
        if lastLoginDate == nil {
            lastLoginDate = Date()
            saveLastLoginDate()
        }
        if LaunchOptions.skipWelcome {
            shouldShowLoginPrompt = false
            lastLoginDate = Date()
            saveLastLoginDate()
        } else if Self.shouldPrompt(lastLogin: lastLoginDate, now: Date(), interval: Self.promptInterval) {
            shouldShowLoginPrompt = true
        } else {
            lastLoginDate = Date()
            saveLastLoginDate()
        }
        clearLegacyNotificationsIfNeeded()
        scheduleInactivityReminder()
    }

    static func shouldPrompt(lastLogin: Date?, now: Date, interval: TimeInterval) -> Bool {
        guard let lastLogin else { return false }
        return now.timeIntervalSince(lastLogin) >= interval
    }

    func markUserAsActive() {
        lastLoginDate = Date()
        saveLastLoginDate()
        shouldShowLoginPrompt = false
        scheduleInactivityReminder()
    }

    func dismissPrompt() {
        shouldShowLoginPrompt = false
        scheduleInactivityReminder()
    }

    /// Asks for permission once, then schedules a single quiet reminder for later.
    func scheduleInactivityReminder() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    guard granted else { return }
                    self.enqueueReminder(on: center)
                }
            case .authorized, .provisional, .ephemeral:
                self.enqueueReminder(on: center)
            default:
                break
            }
        }
    }

    private func enqueueReminder(on center: UNUserNotificationCenter) {
        center.removePendingNotificationRequests(withIdentifiers: [reminderID])

        let content = UNMutableNotificationContent()
        content.title = "CookieNotes"
        content.body = "Your cookbook is waiting. Open CookieNotes when you are ready to cook."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: Self.reminderInterval,
            repeats: false
        )
        let request = UNNotificationRequest(identifier: reminderID, content: content, trigger: trigger)
        center.add(request)
    }

    private func clearLegacyNotificationsIfNeeded() {
        guard !userDefaults.bool(forKey: clearedLegacyNotificationsKey) else { return }
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
        userDefaults.set(true, forKey: clearedLegacyNotificationsKey)
    }

    private func loadLastLoginDate() {
        lastLoginDate = userDefaults.object(forKey: lastLoginKey) as? Date
    }

    private func saveLastLoginDate() {
        if let date = lastLoginDate {
            userDefaults.set(date, forKey: lastLoginKey)
        }
    }
}
