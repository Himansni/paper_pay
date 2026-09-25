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

  /// No description provided for @arrangeDeliveryRoute.
  ///
  /// In en, this message translates to:
  /// **'Arrange Delivery Route'**
  String get arrangeDeliveryRoute;

  /// No description provided for @routeOrderSaved.
  ///
  /// In en, this message translates to:
  /// **'Route order saved successfully.'**
  String get routeOrderSaved;

  /// No description provided for @placeInRoute.
  ///
  /// In en, this message translates to:
  /// **'Place in delivery route'**
  String get placeInRoute;

  /// No description provided for @placeInRouteFirst.
  ///
  /// In en, this message translates to:
  /// **'At start of route (First)'**
  String get placeInRouteFirst;

  /// No description provided for @placeInRouteAfter.
  ///
  /// In en, this message translates to:
  /// **'After an existing customer'**
  String get placeInRouteAfter;

  /// No description provided for @placeInRouteLast.
  ///
  /// In en, this message translates to:
  /// **'At end of route (Last)'**
  String get placeInRouteLast;

  /// No description provided for @precedingCustomer.
  ///
  /// In en, this message translates to:
  /// **'Preceding customer'**
  String get precedingCustomer;

  /// No description provided for @selectAreaFirst.
  ///
  /// In en, this message translates to:
  /// **'Select an area first to choose preceding customer.'**
  String get selectAreaFirst;

  /// No description provided for @noCustomersInArea.
  ///
  /// In en, this message translates to:
  /// **'No existing customers in this area.'**
  String get noCustomersInArea;

  /// No description provided for @dragHandleHint.
  ///
  /// In en, this message translates to:
  /// **'Long-press or drag the handle on the right to reorder delivery stops.'**
  String get dragHandleHint;

  /// No description provided for @permissionDeniedArrangeRoute.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission to rearrange route stops for this area.'**
  String get permissionDeniedArrangeRoute;

  /// No description provided for @noCustomersToArrange.
  ///
  /// In en, this message translates to:
  /// **'No active customers in this area to arrange.'**
  String get noCustomersToArrange;

  /// No description provided for @customerEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Customer'**
  String get customerEditTitle;

  /// No description provided for @customerNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New Customer'**
  String get customerNewTitle;

  /// No description provided for @customerDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Customer Details'**
  String get customerDetailsTitle;

  /// No description provided for @customerNotFound.
  ///
  /// In en, this message translates to:
  /// **'Customer not found'**
  String get customerNotFound;

  /// No description provided for @customerNotFoundMessage.
  ///
  /// In en, this message translates to:
  /// **'The record may no longer be available.'**
  String get customerNotFoundMessage;

  /// No description provided for @customerCreated.
  ///
  /// In en, this message translates to:
  /// **'Customer {code} created.'**
  String customerCreated(String code);

  /// No description provided for @customerDetailsUpdated.
  ///
  /// In en, this message translates to:
  /// **'Customer details updated.'**
  String get customerDetailsUpdated;

  /// No description provided for @customerAssignmentUpdated.
  ///
  /// In en, this message translates to:
  /// **'Customer assignment updated.'**
  String get customerAssignmentUpdated;

  /// No description provided for @assignCustomerTitle.
  ///
  /// In en, this message translates to:
  /// **'Assign {name}'**
  String assignCustomerTitle(String name);

  /// No description provided for @selectAnArea.
  ///
  /// In en, this message translates to:
  /// **'Select an area'**
  String get selectAnArea;

  /// No description provided for @keepUnassigned.
  ///
  /// In en, this message translates to:
  /// **'Keep unassigned'**
  String get keepUnassigned;

  /// No description provided for @saveAssignment.
  ///
  /// In en, this message translates to:
  /// **'Save assignment'**
  String get saveAssignment;

  /// No description provided for @loadMoreCustomers.
  ///
  /// In en, this message translates to:
  /// **'Load more customers'**
  String get loadMoreCustomers;

  /// No description provided for @allAreas.
  ///
  /// In en, this message translates to:
  /// **'All areas'**
  String get allAreas;

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// No description provided for @customerConsentRecorded.
  ///
  /// In en, this message translates to:
  /// **'Customer consent recorded'**
  String get customerConsentRecorded;

  /// No description provided for @changeAssignment.
  ///
  /// In en, this message translates to:
  /// **'Change assignment'**
  String get changeAssignment;

  /// No description provided for @upiSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'UPI Settings'**
  String get upiSettingsTitle;

  /// No description provided for @enableUpiRequests.
  ///
  /// In en, this message translates to:
  /// **'Enable UPI collection requests'**
  String get enableUpiRequests;

  /// No description provided for @upiSettingsUpdated.
  ///
  /// In en, this message translates to:
  /// **'UPI collection settings updated.'**
  String get upiSettingsUpdated;

  /// No description provided for @collectFromCustomerRecord.
  ///
  /// In en, this message translates to:
  /// **'Collect from a customer record'**
  String get collectFromCustomerRecord;

  /// No description provided for @loadMorePayments.
  ///
  /// In en, this message translates to:
  /// **'Load more payments'**
  String get loadMorePayments;

  /// No description provided for @oldestOutstandingFirst.
  ///
  /// In en, this message translates to:
  /// **'Oldest outstanding first'**
  String get oldestOutstandingFirst;

  /// No description provided for @receiptMustBeVerified.
  ///
  /// In en, this message translates to:
  /// **'Receipt must be verified manually'**
  String get receiptMustBeVerified;

  /// No description provided for @retryConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Retry confirmation'**
  String get retryConfirmation;

  /// No description provided for @confirmReceiptOfPayment.
  ///
  /// In en, this message translates to:
  /// **'Confirm receipt of payment?'**
  String get confirmReceiptOfPayment;

  /// No description provided for @goBack.
  ///
  /// In en, this message translates to:
  /// **'Go back'**
  String get goBack;

  /// No description provided for @iVerifiedReceipt.
  ///
  /// In en, this message translates to:
  /// **'I verified receipt'**
  String get iVerifiedReceipt;

  /// No description provided for @generateAmountUpiQr.
  ///
  /// In en, this message translates to:
  /// **'Generate amount-specific UPI QR'**
  String get generateAmountUpiQr;

  /// No description provided for @paymentReceiptTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment Receipt'**
  String get paymentReceiptTitle;

  /// No description provided for @notYetConfirmedReceipt.
  ///
  /// In en, this message translates to:
  /// **'Not yet a confirmed receipt'**
  String get notYetConfirmedReceipt;

  /// No description provided for @serverConfirmedLedger.
  ///
  /// In en, this message translates to:
  /// **'Server-confirmed ledger entry'**
  String get serverConfirmedLedger;

  /// No description provided for @remainingOutstanding.
  ///
  /// In en, this message translates to:
  /// **'Remaining outstanding'**
  String get remainingOutstanding;

  /// No description provided for @recordPaymentReversal.
  ///
  /// In en, this message translates to:
  /// **'Record Payment Reversal'**
  String get recordPaymentReversal;

  /// No description provided for @recordReversal.
  ///
  /// In en, this message translates to:
  /// **'Record reversal'**
  String get recordReversal;

  /// No description provided for @finalizedBill.
  ///
  /// In en, this message translates to:
  /// **'Finalized Bill'**
  String get finalizedBill;

  /// No description provided for @immutableFinancialSnapshot.
  ///
  /// In en, this message translates to:
  /// **'Immutable financial snapshot'**
  String get immutableFinancialSnapshot;

  /// No description provided for @deliveryLinesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} delivery lines'**
  String deliveryLinesCount(int count);

  /// No description provided for @noAdjustmentsApplied.
  ///
  /// In en, this message translates to:
  /// **'No adjustments were applied.'**
  String get noAdjustmentsApplied;

  /// No description provided for @loadMoreDailyLines.
  ///
  /// In en, this message translates to:
  /// **'Load more daily lines'**
  String get loadMoreDailyLines;

  /// No description provided for @finalizeBillQuestion.
  ///
  /// In en, this message translates to:
  /// **'Finalize immutable bill?'**
  String get finalizeBillQuestion;

  /// No description provided for @finalizeBillAction.
  ///
  /// In en, this message translates to:
  /// **'Finalize bill'**
  String get finalizeBillAction;

  /// No description provided for @finalizeImmutableBill.
  ///
  /// In en, this message translates to:
  /// **'Finalize immutable bill'**
  String get finalizeImmutableBill;

  /// No description provided for @readOnlyCalculation.
  ///
  /// In en, this message translates to:
  /// **'Read-only calculation'**
  String get readOnlyCalculation;

  /// No description provided for @signedBillingAdjustment.
  ///
  /// In en, this message translates to:
  /// **'Signed billing adjustment'**
  String get signedBillingAdjustment;

  /// No description provided for @recordAdjustment.
  ///
  /// In en, this message translates to:
  /// **'Record adjustment'**
  String get recordAdjustment;

  /// No description provided for @adjustmentRecorded.
  ///
  /// In en, this message translates to:
  /// **'Adjustment recorded with audit history.'**
  String get adjustmentRecorded;

  /// No description provided for @monthPreview.
  ///
  /// In en, this message translates to:
  /// **'{month} preview'**
  String monthPreview(String month);

  /// No description provided for @monthBill.
  ///
  /// In en, this message translates to:
  /// **'{month} bill'**
  String monthBill(String month);

  /// No description provided for @todayOperationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Operations'**
  String get todayOperationsTitle;

  /// No description provided for @circulationSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Circulation Tally'**
  String get circulationSummaryTitle;

  /// No description provided for @findTheHouse.
  ///
  /// In en, this message translates to:
  /// **'Find the house'**
  String get findTheHouse;

  /// No description provided for @landmarkPrefix.
  ///
  /// In en, this message translates to:
  /// **'LANDMARK: '**
  String get landmarkPrefix;

  /// No description provided for @contactSection.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get contactSection;

  /// No description provided for @primaryPhone.
  ///
  /// In en, this message translates to:
  /// **'Primary phone'**
  String get primaryPhone;

  /// No description provided for @deliveryAssignment.
  ///
  /// In en, this message translates to:
  /// **'Delivery assignment'**
  String get deliveryAssignment;

  /// No description provided for @areaLabel.
  ///
  /// In en, this message translates to:
  /// **'Area'**
  String get areaLabel;

  /// No description provided for @employeeLabel.
  ///
  /// In en, this message translates to:
  /// **'Employee'**
  String get employeeLabel;

  /// No description provided for @placementLabel.
  ///
  /// In en, this message translates to:
  /// **'Placement'**
  String get placementLabel;

  /// No description provided for @billingPreference.
  ///
  /// In en, this message translates to:
  /// **'Billing preference'**
  String get billingPreference;

  /// No description provided for @consentedGpsLocation.
  ///
  /// In en, this message translates to:
  /// **'Consented GPS location'**
  String get consentedGpsLocation;

  /// No description provided for @latitude.
  ///
  /// In en, this message translates to:
  /// **'Latitude'**
  String get latitude;

  /// No description provided for @longitude.
  ///
  /// In en, this message translates to:
  /// **'Longitude'**
  String get longitude;

  /// No description provided for @operationalNotes.
  ///
  /// In en, this message translates to:
  /// **'Operational notes'**
  String get operationalNotes;

  /// No description provided for @financialOpening.
  ///
  /// In en, this message translates to:
  /// **'Financial opening'**
  String get financialOpening;

  /// No description provided for @immutableOpeningNotice.
  ///
  /// In en, this message translates to:
  /// **'Immutable after creation; future corrections require an audited adjustment.'**
  String get immutableOpeningNotice;

  /// No description provided for @assignmentAndChangeHistory.
  ///
  /// In en, this message translates to:
  /// **'Assignment and change history'**
  String get assignmentAndChangeHistory;

  /// No description provided for @noCustomerAuditEntries.
  ///
  /// In en, this message translates to:
  /// **'No customer audit entries are available yet.'**
  String get noCustomerAuditEntries;

  /// No description provided for @couldNotLoadAuditHistory.
  ///
  /// In en, this message translates to:
  /// **'Could not load audit history: {error}'**
  String couldNotLoadAuditHistory(String error);

  /// No description provided for @reactivateCustomer.
  ///
  /// In en, this message translates to:
  /// **'Reactivate customer'**
  String get reactivateCustomer;

  /// No description provided for @reactivateCustomerConfirm.
  ///
  /// In en, this message translates to:
  /// **'Reactivate customer?'**
  String get reactivateCustomerConfirm;

  /// No description provided for @archiveCustomerConfirm.
  ///
  /// In en, this message translates to:
  /// **'Archive customer?'**
  String get archiveCustomerConfirm;

  /// No description provided for @reactivateCustomerDesc.
  ///
  /// In en, this message translates to:
  /// **'The customer will return to active operational lists.'**
  String get reactivateCustomerDesc;

  /// No description provided for @archiveCustomerDesc.
  ///
  /// In en, this message translates to:
  /// **'The record and all history will be preserved. Delivery and billing records will not be deleted.'**
  String get archiveCustomerDesc;

  /// No description provided for @customerReactivated.
  ///
  /// In en, this message translates to:
  /// **'Customer reactivated.'**
  String get customerReactivated;

  /// No description provided for @customerArchivedNotice.
  ///
  /// In en, this message translates to:
  /// **'Customer archived without deleting history.'**
  String get customerArchivedNotice;

  /// No description provided for @auditCustomerCreated.
  ///
  /// In en, this message translates to:
  /// **'Customer created'**
  String get auditCustomerCreated;

  /// No description provided for @auditCustomerUpdated.
  ///
  /// In en, this message translates to:
  /// **'Customer details updated'**
  String get auditCustomerUpdated;

  /// No description provided for @auditCustomerArchived.
  ///
  /// In en, this message translates to:
  /// **'Customer archived'**
  String get auditCustomerArchived;

  /// No description provided for @auditCustomerReactivated.
  ///
  /// In en, this message translates to:
  /// **'Customer reactivated'**
  String get auditCustomerReactivated;

  /// No description provided for @auditCustomerAssignmentTransferred.
  ///
  /// In en, this message translates to:
  /// **'Assignment transferred'**
  String get auditCustomerAssignmentTransferred;

  /// No description provided for @customerPaymentHistory.
  ///
  /// In en, this message translates to:
  /// **'Customer payment history'**
  String get customerPaymentHistory;

  /// No description provided for @paymentHistory.
  ///
  /// In en, this message translates to:
  /// **'Payment history'**
  String get paymentHistory;

  /// No description provided for @myCollections.
  ///
  /// In en, this message translates to:
  /// **'My collections'**
  String get myCollections;

  /// No description provided for @customerPaymentHistorySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Confirmed payments for this customer, including reversal status and immutable allocations.'**
  String get customerPaymentHistorySubtitle;

  /// No description provided for @headPaymentHistorySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Confirmed payments and reversals are retained as an immutable financial trail.'**
  String get headPaymentHistorySubtitle;

  /// No description provided for @employeeCollectionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your own immutable collection receipts remain available after a customer is reassigned.'**
  String get employeeCollectionsSubtitle;

  /// No description provided for @collectFromCustomerRecordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Open an active customer to confirm cash, UPI, bank-transfer, or other manual collection.'**
  String get collectFromCustomerRecordSubtitle;

  /// No description provided for @noConfirmedPayments.
  ///
  /// In en, this message translates to:
  /// **'No confirmed payments'**
  String get noConfirmedPayments;

  /// No description provided for @noConfirmedPaymentsMessage.
  ///
  /// In en, this message translates to:
  /// **'A payment appears here only after an authorized collector confirms receipt.'**
  String get noConfirmedPaymentsMessage;

  /// No description provided for @paymentReversedBadge.
  ///
  /// In en, this message translates to:
  /// **'REVERSED'**
  String get paymentReversedBadge;

  /// No description provided for @reversalReasonPrefix.
  ///
  /// In en, this message translates to:
  /// **'Reversal reason: {reason}'**
  String reversalReasonPrefix(String reason);

  /// No description provided for @collectedByPrefix.
  ///
  /// In en, this message translates to:
  /// **'Collected by {name} • {method}'**
  String collectedByPrefix(String name, String method);

  /// No description provided for @paymentReversalSuccess.
  ///
  /// In en, this message translates to:
  /// **'Payment reversed with immutable financial audit record.'**
  String get paymentReversalSuccess;

  /// No description provided for @collectionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Collection unavailable'**
  String get collectionUnavailable;

  /// No description provided for @billingWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Billing workspace'**
  String get billingWorkspace;

  /// No description provided for @assignedBills.
  ///
  /// In en, this message translates to:
  /// **'Assigned bills'**
  String get assignedBills;

  /// No description provided for @billingWorkspaceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Review deterministic daily charges before finalization. Previews never write data.'**
  String get billingWorkspaceSubtitle;

  /// No description provided for @assignedBillsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You can read finalized bills only for customers currently assigned to you.'**
  String get assignedBillsSubtitle;

  /// No description provided for @noActiveCustomers.
  ///
  /// In en, this message translates to:
  /// **'No active customers'**
  String get noActiveCustomers;

  /// No description provided for @noActiveCustomersDesc.
  ///
  /// In en, this message translates to:
  /// **'There are no accessible active customers to bill.'**
  String get noActiveCustomersDesc;

  /// No description provided for @routeCoverage.
  ///
  /// In en, this message translates to:
  /// **'Route coverage'**
  String get routeCoverage;

  /// No description provided for @routeCoverageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create operational areas and keep employee coverage synchronized with authoritative member records.'**
  String get routeCoverageSubtitle;

  /// No description provided for @newArea.
  ///
  /// In en, this message translates to:
  /// **'New area'**
  String get newArea;

  /// No description provided for @editArea.
  ///
  /// In en, this message translates to:
  /// **'Edit area'**
  String get editArea;

  /// No description provided for @areaName.
  ///
  /// In en, this message translates to:
  /// **'Area name'**
  String get areaName;

  /// No description provided for @areaDescription.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get areaDescription;

  /// No description provided for @assignEmployees.
  ///
  /// In en, this message translates to:
  /// **'Assign employees'**
  String get assignEmployees;

  /// No description provided for @noAreasConfigured.
  ///
  /// In en, this message translates to:
  /// **'No areas configured'**
  String get noAreasConfigured;

  /// No description provided for @noAreasConfiguredSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create delivery areas to organize customer stops and route assignments.'**
  String get noAreasConfiguredSubtitle;

  /// No description provided for @publicationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage newspapers, periodicals, and standard weekday/weekend pricing schedules.'**
  String get publicationsSubtitle;

  /// No description provided for @dailyPricingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Set single-day or holiday paper prices that override recurring subscription rates for that morning.'**
  String get dailyPricingSubtitle;

  /// No description provided for @recordPrice.
  ///
  /// In en, this message translates to:
  /// **'Record price'**
  String get recordPrice;

  /// No description provided for @standardPrice.
  ///
  /// In en, this message translates to:
  /// **'Standard price'**
  String get standardPrice;

  /// No description provided for @teamSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage agency staff, invitation codes, and operational permissions.'**
  String get teamSubtitle;

  /// No description provided for @manageEmployee.
  ///
  /// In en, this message translates to:
  /// **'Manage employee'**
  String get manageEmployee;

  /// No description provided for @employeeAccessUpdated.
  ///
  /// In en, this message translates to:
  /// **'Employee access updated.'**
  String get employeeAccessUpdated;

  /// No description provided for @invitationCreated.
  ///
  /// In en, this message translates to:
  /// **'Invitation created'**
  String get invitationCreated;

  /// No description provided for @invitationCodeCopied.
  ///
  /// In en, this message translates to:
  /// **'Invitation code copied.'**
  String get invitationCodeCopied;

  /// No description provided for @invitationRevoked.
  ///
  /// In en, this message translates to:
  /// **'Invitation revoked.'**
  String get invitationRevoked;

  /// No description provided for @copyCode.
  ///
  /// In en, this message translates to:
  /// **'Copy code'**
  String get copyCode;

  /// No description provided for @createInvitation.
  ///
  /// In en, this message translates to:
  /// **'Create invitation'**
  String get createInvitation;

  /// No description provided for @permissionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get permissionsLabel;

  /// No description provided for @initialAreasLabel.
  ///
  /// In en, this message translates to:
  /// **'Initial areas'**
  String get initialAreasLabel;

  /// No description provided for @activeAccess.
  ///
  /// In en, this message translates to:
  /// **'Active access'**
  String get activeAccess;

  /// No description provided for @businessReports.
  ///
  /// In en, this message translates to:
  /// **'Business reports'**
  String get businessReports;

  /// No description provided for @reportsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Server-side totals and paginated records respect the selected filters. CSV exports use the same query scope.'**
  String get reportsSubtitle;

  /// No description provided for @exportFilteredCsv.
  ///
  /// In en, this message translates to:
  /// **'Export filtered CSV'**
  String get exportFilteredCsv;

  /// No description provided for @loadMoreResults.
  ///
  /// In en, this message translates to:
  /// **'Load more results'**
  String get loadMoreResults;

  /// No description provided for @applyFilters.
  ///
  /// In en, this message translates to:
  /// **'Apply filters'**
  String get applyFilters;

  /// No description provided for @allEmployees.
  ///
  /// In en, this message translates to:
  /// **'All employees'**
  String get allEmployees;

  /// No description provided for @allNewspapers.
  ///
  /// In en, this message translates to:
  /// **'All newspapers'**
  String get allNewspapers;

  /// No description provided for @allMethods.
  ///
  /// In en, this message translates to:
  /// **'All methods'**
  String get allMethods;

  /// No description provided for @allBalances.
  ///
  /// In en, this message translates to:
  /// **'All balances'**
  String get allBalances;

  /// No description provided for @allSubscriptions.
  ///
  /// In en, this message translates to:
  /// **'All subscriptions'**
  String get allSubscriptions;

  /// No description provided for @detailedCustomerMode.
  ///
  /// In en, this message translates to:
  /// **'Detailed Mode'**
  String get detailedCustomerMode;

  /// No description provided for @saveCustomer.
  ///
  /// In en, this message translates to:
  /// **'Save Customer'**
  String get saveCustomer;

  /// No description provided for @bulkImportCustomers.
  ///
  /// In en, this message translates to:
  /// **'Bulk Import Customers (CSV)'**
  String get bulkImportCustomers;

  /// No description provided for @masterCatalogTitle.
  ///
  /// In en, this message translates to:
  /// **'Indian Publication Catalogue'**
  String get masterCatalogTitle;

  /// No description provided for @browseMasterCatalog.
  ///
  /// In en, this message translates to:
  /// **'Browse Indian Master Catalogue'**
  String get browseMasterCatalog;

  /// No description provided for @magazinesTab.
  ///
  /// In en, this message translates to:
  /// **'Magazines'**
  String get magazinesTab;

  /// No description provided for @newspapersTab.
  ///
  /// In en, this message translates to:
  /// **'Newspapers'**
  String get newspapersTab;

  /// No description provided for @frequencyDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get frequencyDaily;

  /// No description provided for @frequencyWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get frequencyWeekly;

  /// No description provided for @frequencyFortnightly.
  ///
  /// In en, this message translates to:
  /// **'Fortnightly'**
  String get frequencyFortnightly;

  /// No description provided for @frequencyMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get frequencyMonthly;

  /// No description provided for @addAnotherNewspaper.
  ///
  /// In en, this message translates to:
  /// **'Add another newspaper'**
  String get addAnotherNewspaper;

  /// No description provided for @removeNewspaper.
  ///
  /// In en, this message translates to:
  /// **'Remove newspaper'**
  String get removeNewspaper;

  /// No description provided for @selectNewspaper.
  ///
  /// In en, this message translates to:
  /// **'Select Newspaper / Magazine'**
  String get selectNewspaper;

  /// No description provided for @noNewspapersSelected.
  ///
  /// In en, this message translates to:
  /// **'No newspapers selected'**
  String get noNewspapersSelected;

  /// No description provided for @multipleNewspapers.
  ///
  /// In en, this message translates to:
  /// **'Multiple newspapers'**
  String get multipleNewspapers;

  /// No description provided for @clearPlannedEndDate.
  ///
  /// In en, this message translates to:
  /// **'Clear planned end date'**
  String get clearPlannedEndDate;

  /// No description provided for @selectStartDate.
  ///
  /// In en, this message translates to:
  /// **'Select start date'**
  String get selectStartDate;

  /// No description provided for @selectPlannedEndDate.
  ///
  /// In en, this message translates to:
  /// **'Select planned end date'**
  String get selectPlannedEndDate;

  /// No description provided for @plannedEndDateBeforeStartDate.
  ///
  /// In en, this message translates to:
  /// **'Planned end date cannot precede start date.'**
  String get plannedEndDateBeforeStartDate;

  /// No description provided for @couldNotLoadOutstanding.
  ///
  /// In en, this message translates to:
  /// **'Could not load current outstanding.'**
  String get couldNotLoadOutstanding;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @customerSubscriptionsSetupFailed.
  ///
  /// In en, this message translates to:
  /// **'Customer created, but some subscriptions could not be set up.'**
  String get customerSubscriptionsSetupFailed;
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
