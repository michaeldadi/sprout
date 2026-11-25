package com.michaeldadi.sprout.money

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MoneyNotificationPreferences(repo: MoneyRepository, state: MoneyState, close: () -> Unit) {
    val baseline = remember { state.workspace } ?: return
    var profile by remember { mutableStateOf(baseline.profile) }
    var quiet by remember { mutableStateOf(profile.quietHours ?: MoneyQuietHours()) }
    var error by remember { mutableStateOf<String?>(null) }
    var pendingTopic by remember { mutableStateOf<String?>(null) }
    var timeField by remember { mutableStateOf<String?>(null) }
    var zoneMenu by remember { mutableStateOf(false) }
    var saving by remember { mutableStateOf(false) }
    val context = LocalContext.current; val scope = rememberCoroutineScope()
    val capable = state.workspace?.capabilities?.notifications == true
    fun setTopic(topic: String, enabled: Boolean) {
        profile = when(topic) {
            "renewals" -> profile.copy(renewalAlerts = enabled)
            "prices" -> profile.copy(priceAlerts = enabled)
            "budget" -> profile.copy(budgetAlerts = enabled)
            "forecasts" -> profile.copy(forecastAlerts = enabled)
            else -> profile.copy(weeklyDigest = enabled)
        }
    }
    val permission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        pendingTopic?.let { if (granted) { setTopic(it,true); error = null } else error = "Notifications are off for Sprout in device settings. Your alert choice has not been enabled." }; pendingTopic = null
    }
    fun choose(topic: String, enabled: Boolean) {
        if (!enabled) { setTopic(topic,false); return }
        if (!capable) return
        if (Build.VERSION.SDK_INT >= 33 && ContextCompat.checkSelfPermission(context,Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            pendingTopic = topic; permission.launch(Manifest.permission.POST_NOTIFICATIONS)
        } else if (!NotificationManagerCompat.from(context).areNotificationsEnabled()) error = "Enable notifications for Sprout in device settings before choosing alerts."
        else { setTopic(topic,true); error = null }
    }
    @Composable fun Topic(label: String, value: Boolean, topic: String) {
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Text(label,Modifier.weight(1f)); Switch(value,{ choose(topic,it) }, enabled = (capable || value) && !saving, modifier = Modifier.semantics { contentDescription = label })
        }
    }
    ModalBottomSheet(onDismissRequest = close, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)) {
        Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).imePadding().padding(20.dp),verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text("Notification preferences",style = MaterialTheme.typography.headlineSmall)
            if (!capable) Text("Delivery is paused. You can review preferences and set quiet hours; alerts become available after notification setup.",style = MaterialTheme.typography.bodyMedium)
            Topic("Renewals",profile.renewalAlerts,"renewals")
            Topic("Price changes",profile.priceAlerts,"prices")
            Topic("Budget pace",profile.budgetAlerts == true,"budget")
            Topic("Forecast changes",profile.forecastAlerts == true,"forecasts")
            Topic("Weekly review",profile.weeklyDigest,"digest")
            Row(Modifier.fillMaxWidth(),verticalAlignment = Alignment.CenterVertically) {
                Text("Quiet hours",Modifier.weight(1f)); Switch(quiet.enabled,{ quiet = quiet.copy(enabled=it) },modifier = Modifier.semantics { contentDescription = "Quiet hours" })
            }
            fun time(value: Int) = "%02d:%02d".format(value / 60,value % 60)
            TextButton(onClick = { timeField = "start" },enabled = quiet.enabled && !saving, modifier=Modifier.testTag("money.notification.start")) { Text("Quiet hours start: ${time(quiet.startMinute)}") }
            TextButton(onClick = { timeField = "end" },enabled = quiet.enabled && !saving, modifier=Modifier.testTag("money.notification.end")) { Text("Quiet hours end: ${time(quiet.endMinute)}") }
            Box {
                TextButton(onClick = { zoneMenu = true },enabled = !saving) { Text("Timezone: ${profile.timezone}") }
                DropdownMenu(expanded=zoneMenu,onDismissRequest={ zoneMenu=false }) {
                    (listOf(profile.timezone,"America/New_York","America/Chicago","America/Denver","America/Los_Angeles","America/Anchorage","Pacific/Honolulu").distinct()).forEach { zone -> DropdownMenuItem(text={Text(zone)},onClick={profile=profile.copy(timezone=zone);zoneMenu=false}) }
                }
            }
            Text("Quiet hours use your Sprout account timezone across devices. Delivery may also be limited by this device's notification settings.",style=MaterialTheme.typography.bodySmall)
            if (quiet.startMinute == quiet.endMinute) Text("Choose different quiet-hours start and end times.",color=MaterialTheme.colorScheme.error)
            error?.let { Text(it,color=MaterialTheme.colorScheme.error); TextButton(onClick={context.startActivity(android.content.Intent(android.provider.Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(android.provider.Settings.EXTRA_APP_PACKAGE,context.packageName))}) { Text("Open notification settings") } }
            Button(onClick={scope.launch { saving=true;try {repo.saveProfile(profile.copy(quietHours=quiet),baseline.profileVersion);repo.refresh();close()}catch(e:Exception){error=e.message}finally{saving=false} }},enabled=!saving && quiet.startMinute != quiet.endMinute,modifier=Modifier.fillMaxWidth()) { Text("Save notification preferences") }
            TextButton(onClick=close) { Text("Cancel") };Spacer(Modifier.height(24.dp))
        }
    }
    timeField?.let { field ->
        val value=if(field=="start") quiet.startMinute else quiet.endMinute
        val time=rememberTimePickerState(value/60,value%60,is24Hour=true)
        AlertDialog(onDismissRequest={timeField=null},title={Text(if(field=="start")"Quiet hours start" else "Quiet hours end")},text={TimeInput(time)},confirmButton={TextButton(onClick={val selected=time.hour*60+time.minute;quiet=if(field=="start")quiet.copy(startMinute=selected) else quiet.copy(endMinute=selected);timeField=null}){Text("Use time")}},dismissButton={TextButton(onClick={timeField=null}){Text("Cancel")}})
    }
}
