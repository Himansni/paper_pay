import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi')
  ];

  /// Application title
  ///
  /// In en, this message translates to:
  /// **'PaperRoute'**
  String get appName;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @hindi.
  ///
  /// In en, this message translates to:
  /// **'हिन्दी'**
  String get hindi;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @switchLanguage.
  ///
  /// In en, this message translates to:
  /// **'Change Language'**
  String get switchLanguage;

  /// No description provided for @goodDay.
  ///
  /// In en, this message translates to:
  /// **'Good day, {name}'**
  String goodDay(String name);

  /// No description provided for @headWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Head Distributor workspace'**
  String get headWorkspace;

  /// No description provided for @employeeWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Employee distribution workspace'**
  String get employeeWorkspace;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get commonAdd;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// No description provided for @commonRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get commonRefresh;

  /// No description provided for @commonTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get commonTryAgain;

  /// No description provided for @commonSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get commonSearch;

  /// No description provided for @commonFilter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get commonFilter;

  /// No description provided for @commonClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get commonClear;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get commonLoading;

  /// No description provided for @commonActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get commonActive;

  /// No description provided for @commonArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get commonArchived;

  /// No description provided for @commonUnassigned.
  ///
  /// In en, this message translates to:
  /// **'Unassigned'**
  String get commonUnassigned;

  /// No description provided for @commonSuccess.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get commonSuccess;

  /// No description provided for @commonError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get commonError;

  /// No description provided for @commonWarning.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get commonWarning;

  /// No description provided for @commonNotice.
  ///
  /// In en, this message translates to:
  /// **'Notice'**
  String get commonNotice;

  /// No description provided for @commonNoData.
  ///
  /// In en, this message translates to:
  /// **'No records found.'**
  String get commonNoData;

  /// No description provided for @authSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get authSignIn;

  /// No description provided for @authSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get authSignOut;

  /// No description provided for @authEmail.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get authEmail;

  /// No description provided for @authPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPassword;

  /// No description provided for @authForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get authForgotPassword;

  /// No description provided for @authResetPassword.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get authResetPassword;

  /// No description provided for @authAccountSettings.
  ///
  /// In en, this message translates to:
  /// **'Account Settings'**
  String get authAccountSettings;

  /// No description provided for @authChangePassword.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get authChangePassword;

  /// No description provided for @authRequestDeletion.
  ///
  /// In en, this message translates to:
  /// **'Request Account Deletion'**
  String get authRequestDeletion;

  /// No description provided for @authAccessPending.
  ///
  /// In en, this message translates to:
  /// **'Account Access Pending'**
  String get authAccessPending;

  /// No description provided for @authJoinAgency.
  ///
  /// In en, this message translates to:
  /// **'Join Agency'**
  String get authJoinAgency;

  /// No description provided for @authInviteCode.
  ///
  /// In en, this message translates to:
  /// **'Invitation Code'**
  String get authInviteCode;

  /// No description provided for @authCreateAgency.
  ///
  /// In en, this message translates to:
  /// **'Register New Agency'**
  String get authCreateAgency;

  /// No description provided for @dashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'PaperRoute'**
  String get dashboardTitle;

  /// No description provided for @currentOutstanding.
  ///
  /// In en, this message translates to:
  /// **'Current outstanding'**
  String get currentOutstanding;

  /// No description provided for @todayCollection.
  ///
  /// In en, this message translates to:
  /// **'Today\'s collection'**
  String get todayCollection;

  /// No description provided for @monthBilled.
  ///
  /// In en, this message translates to:
  /// **'{month} billed'**
  String monthBilled(String month);

  /// No description provided for @monthNetCollected.
  ///
  /// In en, this message translates to:
  /// **'{month} net collected'**
  String monthNetCollected(String month);

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick actions'**
  String get quickActions;

  /// No description provided for @dailyPricing.
  ///
  /// In en, this message translates to:
  /// **'Daily pricing'**
  String get dailyPricing;

  /// No description provided for @addCustomer.
  ///
  /// In en, this message translates to:
  /// **'Add customer'**
  String get addCustomer;

  /// No description provided for @recordPayment.
  ///
  /// In en, this message translates to:
  /// **'Record payment'**
  String get recordPayment;

  /// No description provided for @viewReports.
  ///
  /// In en, this message translates to:
  /// **'View reports'**
  String get viewReports;

  /// No description provided for @recentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent activity'**
  String get recentActivity;

  /// No description provided for @recentPayments.
  ///
  /// In en, this message translates to:
  /// **'Recent collections'**
  String get recentPayments;

  /// No description provided for @recentBilling.
  ///
  /// In en, this message translates to:
  /// **'Recent billing'**
  String get recentBilling;

  /// No description provided for @recentCustomers.
  ///
  /// In en, this message translates to:
  /// **'Recent customers'**
  String get recentCustomers;

  /// No description provided for @customersTitle.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get customersTitle;

  /// No description provided for @customerDetails.
  ///
  /// In en, this message translates to:
  /// **'Customer Profile'**
  String get customerDetails;

  /// No description provided for @quickAddCustomer.
  ///
  /// In en, this message translates to:
  /// **'Quick Add Customer'**
  String get quickAddCustomer;

  /// No description provided for @saveAndAddNext.
  ///
  /// In en, this message translates to:
  /// **'Save & Add Next'**
  String get saveAndAddNext;

  /// No description provided for @customerName.
  ///
  /// In en, this message translates to:
  /// **'Customer Name'**
  String get customerName;

  /// No description provided for @customerPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get customerPhone;

  /// No description provided for @alternatePhone.
  ///
  /// In en, this message translates to:
  /// **'Alternate Phone'**
  String get alternatePhone;

  /// No description provided for @customerAddress.
  ///
  /// In en, this message translates to:
  /// **'Delivery Address'**
  String get customerAddress;

  /// No description provided for @customerHouseNumber.
  ///
  /// In en, this message translates to:
  /// **'House / Flat Number'**
  String get customerHouseNumber;

  /// No description provided for @customerBuildingInfo.
  ///
  /// In en, this message translates to:
  /// **'Wing / Floor / Tower'**
  String get customerBuildingInfo;

  /// No description provided for @customerLandmark.
  ///
  /// In en, this message translates to:
  /// **'Landmark'**
  String get customerLandmark;

  /// No description provided for @customerArea.
  ///
  /// In en, this message translates to:
  /// **'Delivery Area'**
  String get customerArea;

  /// No description provided for @customerPlacement.
  ///
  /// In en, this message translates to:
  /// **'Delivery Placement'**
  String get customerPlacement;

  /// No description provided for @customerCode.
  ///
  /// In en, this message translates to:
  /// **'Customer ID'**
  String get customerCode;

  /// No description provided for @customerSaved.
  ///
  /// In en, this message translates to:
  /// **'Customer {code} ({name}) saved successfully'**
  String customerSaved(String code, String name);

  /// No description provided for @locationNotes.
  ///
  /// In en, this message translates to:
  /// **'Location Notes'**
  String get locationNotes;

  /// No description provided for @openingBalance.
  ///
  /// In en, this message translates to:
  /// **'Opening Balance (₹)'**
  String get openingBalance;

  /// No description provided for @placementDoorstep.
  ///
  /// In en, this message translates to:
  /// **'Doorstep'**
  String get placementDoorstep;

  /// No description provided for @placementHandToCustomer.
  ///
  /// In en, this message translates to:
  /// **'Hand to customer'**
  String get placementHandToCustomer;

  /// No description provided for @placementReception.
  ///
  /// In en, this message translates to:
  /// **'Security / Reception'**
  String get placementReception;

  /// No description provided for @placementCollectionPoint.
  ///
  /// In en, this message translates to:
  /// **'Collection Point'**
  String get placementCollectionPoint;

  /// No description provided for @archiveCustomer.
  ///
  /// In en, this message translates to:
  /// **'Archive Customer'**
  String get archiveCustomer;

  /// No description provided for @searchCustomerHint.
  ///
  /// In en, this message translates to:
  /// **'Search name, phone, code or landmark...'**
  String get searchCustomerHint;

  /// No description provided for @subscriptionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Newspaper Subscriptions'**
  String get subscriptionsTitle;

  /// No description provided for @subscriptionDetails.
  ///
  /// In en, this message translates to:
  /// **'Subscription Details'**
  String get subscriptionDetails;

  /// No description provided for @addSubscription.
  ///
  /// In en, this message translates to:
  /// **'Add Subscription'**
  String get addSubscription;

  /// No description provided for @editSubscription.
  ///
  /// In en, this message translates to:
  /// **'Edit Subscription'**
  String get editSubscription;

  /// No description provided for @pauseAllSubscriptions.
  ///
  /// In en, this message translates to:
  /// **'Pause All Subscriptions'**
  String get pauseAllSubscriptions;

  /// No description provided for @resumeAllSubscriptions.
  ///
  /// In en, this message translates to:
  /// **'Resume All Subscriptions'**
  String get resumeAllSubscriptions;

  /// No description provided for @pauseDelivery.
  ///
  /// In en, this message translates to:
  /// **'Pause Delivery'**
  String get pauseDelivery;

  /// No description provided for @resumeDelivery.
  ///
  /// In en, this message translates to:
  /// **'Resume Delivery'**
  String get resumeDelivery;

  /// No description provided for @stopSubscription.
  ///
  /// In en, this message translates to:
  /// **'End Subscription'**
  String get stopSubscription;

  /// No description provided for @stopSubscriptionPermanently.
  ///
  /// In en, this message translates to:
  /// **'Stop Subscription Permanently'**
  String get stopSubscriptionPermanently;

  /// No description provided for @pauseNotice.
  ///
  /// In en, this message translates to:
  /// **'No delivery from {start} to {end} ({days} days). Delivery resumes on: {resume}.'**
  String pauseNotice(String start, String end, int days, String resume);

  /// No description provided for @pauseReason.
  ///
  /// In en, this message translates to:
  /// **'Reason for pause'**
  String get pauseReason;

  /// No description provided for @pauseReasonVacation.
  ///
  /// In en, this message translates to:
  /// **'Out of town / Vacation'**
  String get pauseReasonVacation;

  /// No description provided for @pauseReasonFestival.
  ///
  /// In en, this message translates to:
  /// **'Festival / Holiday'**
  String get pauseReasonFestival;

  /// No description provided for @pauseReasonCustomerRequest.
  ///
  /// In en, this message translates to:
  /// **'Customer request'**
  String get pauseReasonCustomerRequest;

  /// No description provided for @pauseReasonOther.
  ///
  /// In en, this message translates to:
  /// **'Other reason'**
  String get pauseReasonOther;

  /// No description provided for @permanentStopNotice.
  ///
  /// In en, this message translates to:
  /// **'Historical billing and past collection receipts will be permanently preserved. Delivered days up to {date} will be billed normally.'**
  String permanentStopNotice(String date);

  /// No description provided for @newspaperTitle.
  ///
  /// In en, this message translates to:
  /// **'Publication'**
  String get newspaperTitle;

  /// No description provided for @quantity.
  ///
  /// In en, this message translates to:
  /// **'Copies'**
  String get quantity;

  /// No description provided for @deliveryDays.
  ///
  /// In en, this message translates to:
  /// **'Delivery Days'**
  String get deliveryDays;

  /// No description provided for @customPrice.
  ///
  /// In en, this message translates to:
  /// **'Custom Price per Day (Optional)'**
  String get customPrice;

  /// No description provided for @allSubscriptionsPaused.
  ///
  /// In en, this message translates to:
  /// **'All subscriptions paused for this household'**
  String get allSubscriptionsPaused;

  /// No description provided for @pauseAllSuccess.
  ///
  /// In en, this message translates to:
  /// **'All subscriptions paused successfully'**
  String get pauseAllSuccess;

  /// No description provided for @resumeAllSuccess.
  ///
  /// In en, this message translates to:
  /// **'All subscriptions resumed successfully'**
  String get resumeAllSuccess;

  /// No description provided for @morningRouteTitle.
  ///
  /// In en, this message translates to:
  /// **'Morning Route'**
  String get morningRouteTitle;

  /// No description provided for @morningRouteProgress.
  ///
  /// In en, this message translates to:
  /// **'{delivered} of {total} drops completed ({percent}%)'**
  String morningRouteProgress(int delivered, int total, int percent);

  /// No description provided for @markDelivered.
  ///
  /// In en, this message translates to:
  /// **'Mark Delivered'**
  String get markDelivered;

  /// No description provided for @undoDelivered.
  ///
  /// In en, this message translates to:
  /// **'Undo Delivered'**
  String get undoDelivered;

  /// No description provided for @deliveredBadge.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get deliveredBadge;

  /// No description provided for @pausedTodayBadge.
  ///
  /// In en, this message translates to:
  /// **'PAUSED TODAY — DO NOT DELIVER'**
  String get pausedTodayBadge;

  /// No description provided for @logException.
  ///
  /// In en, this message translates to:
  /// **'Report Issue'**
  String get logException;

  /// No description provided for @issueBadge.
  ///
  /// In en, this message translates to:
  /// **'Issue'**
  String get issueBadge;

  /// No description provided for @selectRouteDate.
  ///
  /// In en, this message translates to:
  /// **'Select Route Date'**
  String get selectRouteDate;

  /// No description provided for @refreshRoute.
  ///
  /// In en, this message translates to:
  /// **'Refresh Route'**
  String get refreshRoute;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All ({count})'**
  String filterAll(int count);

  /// No description provided for @filterPending.
  ///
  /// In en, this message translates to:
  /// **'Pending ({count})'**
  String filterPending(int count);

  /// No description provided for @filterDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered ({count})'**
  String filterDelivered(int count);

  /// No description provided for @filterPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused ({count})'**
  String filterPaused(int count);

  /// No description provided for @allDropsCompleted.
  ///
  /// In en, this message translates to:
  /// **'🎉 All active drops completed!'**
  String get allDropsCompleted;

  /// No description provided for @noMatchingStops.
  ///
  /// In en, this message translates to:
  /// **'No stops match this filter.'**
  String get noMatchingStops;

  /// No description provided for @exceptionHouseLocked.
  ///
  /// In en, this message translates to:
  /// **'House Locked / Gate Closed'**
  String get exceptionHouseLocked;

  /// No description provided for @exceptionRain.
  ///
  /// In en, this message translates to:
  /// **'Heavy Rain / Waterlogged'**
  String get exceptionRain;

  /// No description provided for @exceptionPaperShortage.
  ///
  /// In en, this message translates to:
  /// **'Newspaper Shortage'**
  String get exceptionPaperShortage;

  /// No description provided for @exceptionCustomerRefused.
  ///
  /// In en, this message translates to:
  /// **'Customer Refused Delivery'**
  String get exceptionCustomerRefused;

  /// No description provided for @papersToDeliver.
  ///
  /// In en, this message translates to:
  /// **'PAPERS TO DELIVER:'**
  String get papersToDeliver;

  /// No description provided for @pausedHouseholdNotice.
  ///
  /// In en, this message translates to:
  /// **'No action required for paused household.'**
  String get pausedHouseholdNotice;

  /// No description provided for @reportIssueFor.
  ///
  /// In en, this message translates to:
  /// **'Report Issue for {name}'**
  String reportIssueFor(String name);

  /// No description provided for @headTodayTitle.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Operations'**
  String get headTodayTitle;

  /// No description provided for @headTodaySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Live Depot Circulation & Delivery Monitoring'**
  String get headTodaySubtitle;

  /// No description provided for @depotPickupTally.
  ///
  /// In en, this message translates to:
  /// **'Depot Pickup Circulation'**
  String get depotPickupTally;

  /// No description provided for @copiesToPickup.
  ///
  /// In en, this message translates to:
  /// **'{count} copies'**
  String copiesToPickup(int count);

  /// No description provided for @orderedCopies.
  ///
  /// In en, this message translates to:
  /// **'Ordered: {count}'**
  String orderedCopies(int count);

  /// No description provided for @pausedCopies.
  ///
  /// In en, this message translates to:
  /// **'Paused: {count}'**
  String pausedCopies(int count);

  /// No description provided for @copiesToDistribute.
  ///
  /// In en, this message translates to:
  /// **'To Distribute: {count}'**
  String copiesToDistribute(int count);

  /// No description provided for @routeProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Route Progress by Hawker'**
  String get routeProgressTitle;

  /// No description provided for @todayCollectionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Collections'**
  String get todayCollectionsTitle;

  /// No description provided for @cashCollected.
  ///
  /// In en, this message translates to:
  /// **'Cash in Hand: {amount}'**
  String cashCollected(String amount);

  /// No description provided for @upiCollected.
  ///
  /// In en, this message translates to:
  /// **'Direct UPI: {amount}'**
  String upiCollected(String amount);

  /// No description provided for @totalToday.
  ///
  /// In en, this message translates to:
  /// **'Total Today: {amount}'**
  String totalToday(String amount);

  /// No description provided for @operationalAlertsTitle.
  ///
  /// In en, this message translates to:
  /// **'Operational Exceptions Reported Today'**
  String get operationalAlertsTitle;

  /// No description provided for @noOperationalAlerts.
  ///
  /// In en, this message translates to:
  /// **'No delivery exceptions reported today. All routes running smoothly.'**
  String get noOperationalAlerts;

  /// No description provided for @billingTitle.
  ///
  /// In en, this message translates to:
  /// **'Monthly Billing'**
  String get billingTitle;

  /// No description provided for @generateBills.
  ///
  /// In en, this message translates to:
  /// **'Generate Bills'**
  String get generateBills;

  /// No description provided for @billingMonth.
  ///
  /// In en, this message translates to:
  /// **'Billing Month'**
  String get billingMonth;

  /// No description provided for @finalizedBills.
  ///
  /// In en, this message translates to:
  /// **'Finalized Bills'**
  String get finalizedBills;

  /// No description provided for @openBills.
  ///
  /// In en, this message translates to:
  /// **'Pending Bills'**
  String get openBills;

  /// No description provided for @totalDue.
  ///
  /// In en, this message translates to:
  /// **'Total Due: {amount}'**
  String totalDue(String amount);

  /// No description provided for @downloadBill.
  ///
  /// In en, this message translates to:
  /// **'Download Bill (PDF)'**
  String get downloadBill;

  /// No description provided for @dailyPricingTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily Pricing'**
  String get dailyPricingTitle;

  /// No description provided for @collectionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Collections & Payments'**
  String get collectionsTitle;

  /// No description provided for @recordPaymentTitle.
  ///
  /// In en, this message translates to:
  /// **'Record Payment'**
  String get recordPaymentTitle;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount (₹)'**
  String get amount;

  /// No description provided for @paymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment Method'**
  String get paymentMethod;

  /// No description provided for @methodCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get methodCash;

  /// No description provided for @methodUpi.
  ///
  /// In en, this message translates to:
  /// **'UPI QR Code'**
  String get methodUpi;

  /// No description provided for @upiReference.
  ///
  /// In en, this message translates to:
  /// **'UPI Transaction ID / Ref'**
  String get upiReference;

  /// No description provided for @outstandingTitle.
  ///
  /// In en, this message translates to:
  /// **'Current Outstanding'**
  String get outstandingTitle;

  /// No description provided for @collectPayment.
  ///
  /// In en, this message translates to:
  /// **'Collect Payment'**
  String get collectPayment;

  /// No description provided for @paymentReceipt.
  ///
  /// In en, this message translates to:
  /// **'Receipt'**
  String get paymentReceipt;

  /// No description provided for @duplicatePaymentWarning.
  ///
  /// In en, this message translates to:
  /// **'Notice: A payment of {amount} was already collected today at {time} by {collector}.'**
  String duplicatePaymentWarning(String amount, String time, String collector);

  /// No description provided for @ledgerTimelineTitle.
  ///
  /// In en, this message translates to:
  /// **'Ledger Statement'**
  String get ledgerTimelineTitle;

  /// No description provided for @shareOnWhatsApp.
  ///
  /// In en, this message translates to:
  /// **'Share Statement on WhatsApp'**
  String get shareOnWhatsApp;

  /// No description provided for @runningBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance: {amount}'**
  String runningBalance(String amount);

  /// No description provided for @teamTitle.
  ///
  /// In en, this message translates to:
  /// **'Employees & Hawkers'**
  String get teamTitle;

  /// No description provided for @inviteEmployee.
  ///
  /// In en, this message translates to:
  /// **'Invite Employee'**
  String get inviteEmployee;

  /// No description provided for @pendingRemovalRequests.
  ///
  /// In en, this message translates to:
  /// **'Pending Offboarding Requests'**
  String get pendingRemovalRequests;

  /// No description provided for @reassignRoute.
  ///
  /// In en, this message translates to:
  /// **'Reassign Route'**
  String get reassignRoute;

  /// No description provided for @approveOffboarding.
  ///
  /// In en, this message translates to:
  /// **'Approve Offboarding & Archive'**
  String get approveOffboarding;

  /// No description provided for @leaveAgency.
  ///
  /// In en, this message translates to:
  /// **'Request to Leave Agency'**
  String get leaveAgency;

  /// No description provided for @areasTitle.
  ///
  /// In en, this message translates to:
  /// **'Delivery Areas'**
  String get areasTitle;

  /// No description provided for @addArea.
  ///
  /// In en, this message translates to:
  /// **'Add Delivery Area'**
  String get addArea;

  /// No description provided for @newspapersTitle.
  ///
  /// In en, this message translates to:
  /// **'Newspapers & Publications'**
  String get newspapersTitle;

  /// No description provided for @addNewspaper.
  ///
  /// In en, this message translates to:
  /// **'Add Publication'**
  String get addNewspaper;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'hi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'hi': return AppLocalizationsHi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
