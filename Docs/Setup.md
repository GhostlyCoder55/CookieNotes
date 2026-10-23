# CookieNotes setup

CookieNotes is an iPhone and iPad app with a personal **Library**, online **Discover** (TheMealDB), and illustrated ingredients. Ads use Google AdMob, not AdSense. Debug builds request Google's official sample ads. A release build shows no ads until you add your own AdMob IDs.

Discover uses TheMealDB. Debug builds default to test API key `1` via `COOKIENOTES_MEALDB_API_KEY`. Before a public App Store release, become a TheMealDB supporter and set your production key in `Config/Release.xcconfig`.

## Open and run

1. Install Xcode 16 or newer. The project targets iOS 18.2.
2. Open `CookieNotes.xcodeproj`.
3. Let Xcode resolve the Google Mobile Ads Swift package (already pinned at 12.12.0 or a compatible 12.x).
4. Select the CookieNotes scheme and an iPhone or iPad simulator.
5. Run.

There is no separate install command. Xcode downloads the Swift package.

Useful checks from the project folder:

```sh
xcodebuild -project CookieNotes.xcodeproj -scheme CookieNotes -destination 'platform=iOS Simulator,name=iPhone 16' test
xcodebuild -project CookieNotes.xcodeproj -scheme CookieNotes -destination 'platform=iOS Simulator,name=iPhone 16' -configuration Release build
```

Change the simulator name if yours is different (`xcrun simctl list devices available`).

UI tests launch with `-CookieNotesSkipTutorial`, `-CookieNotesSkipConsent`, and `-CookieNotesSkipWelcome` so the first-run screens do not block them.

## Ads you need to configure

AdMob does not charge a fee to create an account. Google keeps a share of ad revenue and pays the rest under the current AdMob terms. Check that share in your account before you rely on it. Approval is not guaranteed, and these steps do not create a publisher account for you.

1. Create an app in [AdMob](https://admob.google.com/) for iOS bundle ID `com.gc.CookieNotes`.
2. Copy the AdMob app ID (`ca-app-pub-…~…`).
3. Create one banner ad unit (`ca-app-pub-…/…`). CookieNotes only requests banners.
4. Publish a privacy policy at a public `https` address. In AdMob, open Privacy & messaging and use that same address in the GDPR, US state, and other messages you need.
5. **Do not publish an AdMob IDFA explainer** and do not add `NSUserTrackingUsageDescription`. CookieNotes serves non-personalized banners only and never requests App Tracking Transparency. Keep GDPR / US-state consent messages in AdMob Privacy & messaging as needed.
6. Edit `Config/Release.xcconfig`:

```
GAD_APPLICATION_IDENTIFIER = ca-app-pub-yourid~yourapp
COOKIENOTES_BANNER_AD_UNIT_ID = ca-app-pub-yourid/yourbanner
# xcconfig treats // as a comment — write https URLs like this:
COOKIENOTES_PRIVACY_POLICY_URL = https:/$()/your-site.example/privacy
```

Leave `COOKIENOTES_BANNER_AD_UNIT_ID` blank to ship with ads turned off. The release file may keep Google's sample application ID only as an Info.plist placeholder so the SDK can load; CookieNotes still will not request ads until both IDs are your real AdMob values and they share the same publisher prefix. Do not set a sample banner ID in Release. Debug builds ignore release IDs and always use Google's sample banner `ca-app-pub-3940256099942544/2435281174` with sample app ID `ca-app-pub-3940256099942544~1458002511`.

Do not tap your own live ads. Use a Debug run to check layout. A release build with real IDs is only for a store build, not for click testing.

Before you submit, replace `SKAdNetworkItems` in `Config/Info.plist` with the current list from Google's [AdMob iOS quick start](https://developers.google.com/admob/ios/quick-start). The IDs already in the file are published network identifiers. Google adds more over time, and missing ones can reduce measurement without stopping ads from loading.

In App Store Connect, do **not** declare data used for tracking. CookieNotes does not request ATT/IDFA. Declare advertising data as needed for AdMob banners (non-personalized). Recipes are not sent to AdMob as keywords.

## Where ads appear

- On the recipe list, after each group of six recipes, with at most two banners. A shorter list gets one banner after the cards.
- In search, after the results, and only when a search has matches. One banner.
- At the bottom of a recipe, after the steps, notes, and photos. It is hidden while editing.
- At the bottom of About.

Ads are labeled "ADVERTISEMENT" and use a separate yellow outline so they are not recipe cards. They are not on the empty library, a search with no matches, the new-recipe form, the tutorial, the launch screen, or the welcome-back prompt. There are no interstitials, app-open ads, or video popups. If a banner does not fill, the space closes.

People in Canada see an in-app choice before any ad request: personalized, non-personalized, or none. That choice can be changed in About. Google's User Messaging Platform form is also requested on launch for regions AdMob regulates, including the EEA, UK, Switzerland, and regulated US states. Ads load only when both that platform and the in-app choice allow them.

## Share extension and iCloud

The share extension saves a link, text, or photo into an App Group inbox. The app imports it the next time it is open. Both targets use the group `group.com.gc.CookieNotes`.

In the Apple Developer account, which is 99 USD per year for App Store distribution:

1. Enable App Groups for `com.gc.CookieNotes` and `com.gc.CookieNotes.Share`.
2. Use the group ID `group.com.gc.CookieNotes`.
3. Let Xcode refresh the signing profiles. The entitlement files are `Config/CookieNotes.entitlements` and `Config/CookieNotesShare.entitlements`.

iCloud sync is off. To turn it on later:

1. Add the iCloud capability with CloudKit to the CookieNotes App ID.
2. Create the container `iCloud.com.gc.CookieNotes`.
3. Add that container to `Config/CookieNotes.entitlements`.
4. Set `COOKIENOTES_CLOUDKIT_ENABLED = YES` in the xcconfig you are building.
5. Do this before you have a library you need to keep, or confirm the existing store still opens. If CloudKit cannot start, CookieNotes keeps the local library and says so.

SwiftData stores recipes on the device, including photos that are resized before they are saved. An older library saved in UserDefaults is copied across once. If that copy fails, the old data is left in place.

## Privacy checklist before release

- Host the privacy policy and put the URL in both AdMob and `COOKIENOTES_PRIVACY_POLICY_URL`.
- Include a way for people in Canada, including Quebec, to reach you about privacy. The in-app summary explains what stays on device and what an ad can collect. It is not a substitute for the hosted policy.
- In AdMob, create the required consent messages and confirm the app ID matches the release xcconfig.
- Archive with the Release configuration and install that build only to verify your real ad unit loads. Do not click it.
