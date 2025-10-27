//
//  NotificationManager.swift
//  CookieNotes
//
//  Created by Christopher Ogbonnaya on 2025-10-26.
//

import Foundation
import UserNotifications
import SwiftUI

class NotificationManager: ObservableObject {
    @Published var shouldShowLoginPrompt = false
    @Published var lastLoginDate: Date?
    
    private let userDefaults = UserDefaults.standard
    private let lastLoginKey = "last_login_date"
    private let notificationInterval: TimeInterval = 7 * 24 * 60 * 60 // 7 days in seconds
    
    init() {
        loadLastLoginDate()
        checkIfShouldShowPrompt()
        requestNotificationPermission()
    }
    
    func markUserAsActive() {
        lastLoginDate = Date()
        saveLastLoginDate()
        shouldShowLoginPrompt = false
        scheduleNextNotification()
    }
    
    func checkIfShouldShowPrompt() {
        guard let lastLogin = lastLoginDate else {
            // First time user - don't show prompt immediately
            return
        }
        
        let timeSinceLastLogin = Date().timeIntervalSince(lastLogin)
        if timeSinceLastLogin >= notificationInterval {
            shouldShowLoginPrompt = true
        }
    }
    
    private func loadLastLoginDate() {
        if let savedDate = userDefaults.object(forKey: lastLoginKey) as? Date {
            lastLoginDate = savedDate
        }
    }
    
    private func saveLastLoginDate() {
        if let date = lastLoginDate {
            userDefaults.set(date, forKey: lastLoginKey)
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                self.scheduleNextNotification()
            }
        }
    }
    
    private func scheduleNextNotification() {
        // Cancel existing notifications
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        // Schedule notification for next week
        let content = UNMutableNotificationContent()
        content.title = "Missing Your Recipes?"
        content.body = "Come back to CookieNotes and add some delicious recipes to your collection!"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: notificationInterval, repeats: false)
        let request = UNNotificationRequest(identifier: "login_prompt", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            }
        }
    }
    
    func dismissPrompt() {
        shouldShowLoginPrompt = false
        // Don't update lastLoginDate - user dismissed without being active
    }
}
