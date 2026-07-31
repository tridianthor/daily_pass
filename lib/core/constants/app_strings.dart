class AppStrings {
  // App
  static const String appName = 'Daily Pass';

  // Home
  static const String noActivities = 'No activities for this date';
  static const String tapToAdd = 'Tap + to add one';

  // Activity Form
  static const String createActivity = 'Create Activity';
  static const String editActivity = 'Edit Activity';
  static const String activityName = 'Activity Name';
  static const String activityNameHint = 'Enter activity name';
  static const String activityDetail = 'Details (optional)';
  static const String activityDetailHint = 'Add notes or details';
  static const String repeat = 'Repeat';
  static const String startDate = 'Start Date';
  static const String endDate = 'End Date (optional)';
  static const String save = 'Save';
  static const String cancel = 'Cancel';
  static const String delete = 'Delete';
  static const String requiredField = 'This field is required';
  static String maxChars(int count) => 'Maximum $count characters';

  // Settings
  static const String settings = 'Settings';
  static const String appearance = 'Appearance';
  static const String theme = 'Theme';
  static const String themeLight = 'Light';
  static const String themeDark = 'Dark';
  static const String themeSystem = 'System';
  static const String weekStart = 'Week Start';
  static const String defaultView = 'Default View';
  static const String dataManagement = 'Data Management';
  static const String exportData = 'Export Data';
  static const String importData = 'Import Data';
  static const String clearAllData = 'Clear All Data';
  static const String about = 'About';
  static const String version = 'Version';
  static const String offline = 'Offline Mode';

  // Dialogs
  static const String confirmDelete = 'Delete Activity?';
  static const String confirmDeleteMessage = 'This cannot be undone.';
  static const String confirmClear = 'Clear All Data?';
  static const String confirmClearMessage = 'Type DELETE to confirm';
  static const String deleteConfirmationHint = 'Type DELETE';

  // Notifications
  static const String activityAdded = 'Activity added';
  static const String activityDeleted = 'Activity deleted';
  static String activityImported(int count) => 'Data imported: $count activities';
  static const String dataExported = 'Data exported';
  static const String exportFailed = 'Export failed';
  static const String importFailed = 'Invalid file format';
  static const String dataCleared = 'All data cleared';
  static const String greatJob = 'Great job!';
  static const String markedIncomplete = 'Marked incomplete';
  static const String failedToSave = 'Failed to save';
  static const String somethingWentWrong = 'Something went wrong';
}
