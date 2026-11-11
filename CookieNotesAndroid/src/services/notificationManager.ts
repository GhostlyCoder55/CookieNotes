import { Platform } from 'react-native';
import { getSetting, setSetting, SettingKeys } from '../database/settingsRepository';
import { getActiveLanguage, tFor } from '../localization/i18n';

export const WELCOME_PROMPT_INTERVAL_MS = 7 * 24 * 60 * 60 * 1000; // 7 days
export const INACTIVITY_REMINDER_INTERVAL_SECONDS = 5 * 24 * 60 * 60; // 5 days
export const INACTIVITY_REMINDER_ID = 'cookienotes.inactivityReminder';
export const ANDROID_REMINDER_CHANNEL_ID = 'cookienotes-reminders';

export function shouldPromptWelcomeBack(
  lastLoginIso: string | null,
  nowMs: number = Date.now(),
  intervalMs: number = WELCOME_PROMPT_INTERVAL_MS
): boolean {
  if (!lastLoginIso) return false;
  const parsedMs = Date.parse(lastLoginIso);
  if (!Number.isFinite(parsedMs)) return false;
  return nowMs - parsedMs >= intervalMs;
}

class NotificationManager {
  shouldShowWelcomePrompt = false;
  lastLoginDate: string | null = null;
  private listeners = new Set<() => void>();
  private channelConfigured = false;
  private permissionRequestedThisSession = false;

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  private emit(): void {
    for (const listener of this.listeners) {
      listener();
    }
  }

  async initializeOnLaunch(): Promise<void> {
    const stored = await getSetting(SettingKeys.lastLoginDate);
    if (!stored) {
      const nowIso = new Date().toISOString();
      this.lastLoginDate = nowIso;
      this.shouldShowWelcomePrompt = false;
      await setSetting(SettingKeys.lastLoginDate, nowIso);
    } else if (shouldPromptWelcomeBack(stored)) {
      this.lastLoginDate = stored;
      this.shouldShowWelcomePrompt = true;
    } else {
      const nowIso = new Date().toISOString();
      this.lastLoginDate = nowIso;
      this.shouldShowWelcomePrompt = false;
      await setSetting(SettingKeys.lastLoginDate, nowIso);
    }
    this.emit();
  }

  async markUserAsActive(): Promise<void> {
    const nowIso = new Date().toISOString();
    this.lastLoginDate = nowIso;
    this.shouldShowWelcomePrompt = false;
    await setSetting(SettingKeys.lastLoginDate, nowIso);
    this.emit();
    await this.scheduleInactivityReminder();
  }

  async dismissPrompt(): Promise<void> {
    this.shouldShowWelcomePrompt = false;
    const nowIso = new Date().toISOString();
    this.lastLoginDate = nowIso;
    await setSetting(SettingKeys.lastLoginDate, nowIso);
    this.emit();
    await this.scheduleInactivityReminder();
  }

  async scheduleInactivityReminder(): Promise<void> {
    if (Platform.OS === 'web') return;
    try {
      // Dynamic import/require so Node Jest environments cleanly skip native notification setup
      // eslint-disable-next-line @typescript-eslint/no-require-imports
      const Notifications = require('expo-notifications') as typeof import('expo-notifications');

      if (!this.channelConfigured && Platform.OS === 'android') {
        await Notifications.setNotificationChannelAsync(ANDROID_REMINDER_CHANNEL_ID, {
          name: 'CookieNotes',
          importance: Notifications.AndroidImportance.DEFAULT,
        });
        this.channelConfigured = true;
      }

      const existingPerms = await Notifications.getPermissionsAsync();
      let granted = existingPerms.granted;
      if (!granted && existingPerms.canAskAgain && !this.permissionRequestedThisSession) {
        this.permissionRequestedThisSession = true;
        const requested = await Notifications.requestPermissionsAsync();
        granted = requested.granted;
      }
      if (!granted) return;

      await Notifications.cancelScheduledNotificationAsync(INACTIVITY_REMINDER_ID).catch(() => {});

      const lang = getActiveLanguage();
      await Notifications.scheduleNotificationAsync({
        identifier: INACTIVITY_REMINDER_ID,
        content: {
          title: 'CookieNotes',
          body: tFor(lang, 'Your cookbook is waiting. Open CookieNotes when you are ready to cook.'),
          sound: true,
        },
        trigger: {
          type: Notifications.SchedulableTriggerInputTypes.TIME_INTERVAL,
          seconds: INACTIVITY_REMINDER_INTERVAL_SECONDS,
          repeats: false,
          channelId: Platform.OS === 'android' ? ANDROID_REMINDER_CHANNEL_ID : undefined,
        },
      });
    } catch {
      // Safe no-op if notifications are unsupported (e.g. Expo Go restrictions or denied)
    }
  }
}

export const notificationManager = new NotificationManager();
