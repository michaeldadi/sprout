import SwiftUI
import UIKit
import UserNotifications

struct MoneyNotificationPreferencesView: View {
    @EnvironmentObject private var store: MoneyStore
    @Environment(\.dismiss) private var dismiss
    @State private var profile: MoneyProfile
    @State private var quiet: MoneyQuietHours
    @State private var baselineVersion: Int
    @State private var error: String?
    @State private var saving = false
    init(profile: MoneyProfile, version: Int) {
        _profile = State(initialValue: profile)
        _quiet = State(initialValue: profile.quietHours ?? MoneyQuietHours())
        _baselineVersion = State(initialValue: version)
    }
    private var capable: Bool { store.workspace?.capabilities.notifications == true }
    private var zones: [String] { Array(Set([profile.timezone,"America/New_York","America/Chicago","America/Denver","America/Los_Angeles","America/Anchorage","Pacific/Honolulu"])).sorted() }
    var body: some View {
        NavigationStack {
            Form {
                if !capable { Section { Text("Delivery is paused. You can review preferences and set quiet hours; alerts become available after notification setup.").font(.footnote).foregroundStyle(SproutColor.textSecondary) } }
                Section("Topics") {
                    topic("Renewals", value: profile.renewalAlerts, key: "renewals")
                    topic("Price changes", value: profile.priceAlerts, key: "prices")
                    topic("Budget pace", value: profile.budgetAlerts == true, key: "budget")
                    topic("Forecast changes", value: profile.forecastAlerts == true, key: "forecasts")
                    topic("Weekly review", value: profile.weeklyDigest, key: "digest")
                }
                Section {
                    Toggle("Quiet hours", isOn: $quiet.enabled).accessibilityIdentifier("money.notification.quiet")
                    DatePicker("Quiet hours start", selection: time(start: true), displayedComponents: .hourAndMinute).disabled(!quiet.enabled).accessibilityIdentifier("money.notification.start")
                    DatePicker("Quiet hours end", selection: time(start: false), displayedComponents: .hourAndMinute).disabled(!quiet.enabled).accessibilityIdentifier("money.notification.end")
                    Picker("Timezone", selection: $profile.timezone) { ForEach(zones,id: \.self) { Text($0).tag($0) } }.accessibilityIdentifier("money.notification.timezone")
                    if quiet.startMinute == quiet.endMinute { Text("Choose different quiet-hours start and end times.").foregroundStyle(SproutColor.error) }
                } footer: { Text("Quiet hours use your Sprout account timezone across devices. Delivery may also be limited by this device's notification settings.") }
                if let error { Section { Text(error).foregroundStyle(SproutColor.error); if let settings = URL(string: UIApplication.openSettingsURLString) { Link("Open notification settings", destination: settings) } } }
                Section { Button("Save notification preferences") {
                    saving = true
                    do { var reviewed = profile; reviewed.quietHours = quiet; try store.saveProfile(reviewed, expectedVersion: baselineVersion); dismiss() }
                    catch { self.error = error.localizedDescription; saving = false }
                }.disabled(saving || quiet.startMinute == quiet.endMinute) }
            }
            .environment(\.timeZone, TimeZone(identifier: profile.timezone) ?? .current)
            .navigationTitle("Notification preferences").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
    private func topic(_ label: String, value: Bool, key: String) -> some View {
        Toggle(label,isOn: Binding(get:{value},set:{ choose(key,enabled:$0) })).disabled(saving || (!capable && !value))
    }
    private func set(_ key: String, enabled: Bool) {
        switch key { case "renewals":profile.renewalAlerts=enabled;case "prices":profile.priceAlerts=enabled;case "budget":profile.budgetAlerts=enabled;case "forecasts":profile.forecastAlerts=enabled;default:profile.weeklyDigest=enabled }
    }
    @MainActor private func choose(_ key: String, enabled: Bool) {
        guard enabled else { set(key,enabled:false);return }; guard capable else { return }
        Task {
            let center = UNUserNotificationCenter.current(), settings = await center.notificationSettings()
            let granted: Bool
            if settings.authorizationStatus == .notDetermined { granted = (try? await center.requestAuthorization(options:[.alert,.badge,.sound])) == true }
            else { granted = [.authorized,.provisional,.ephemeral].contains(settings.authorizationStatus) }
            if granted { set(key,enabled:true);error=nil }
            else { error="Notifications are off for Sprout in device settings. Your alert choice has not been enabled." }
        }
    }
    private func time(start: Bool) -> Binding<Date> {
        var calendar=Calendar(identifier:.gregorian);calendar.timeZone=TimeZone(identifier:profile.timezone) ?? .current
        return Binding(get:{ let minute=start ? quiet.startMinute : quiet.endMinute;return calendar.date(from:DateComponents(year:2026,month:1,day:15,hour:minute/60,minute:minute%60)) ?? .now },set:{ date in let components=calendar.dateComponents([.hour,.minute],from:date), minute=(components.hour ?? 0)*60+(components.minute ?? 0);if start {quiet.startMinute=minute}else{quiet.endMinute=minute} })
    }
}
