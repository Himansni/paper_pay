// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'PaperRoute';

  @override
  String get english => 'English';

  @override
  String get hindi => 'हिन्दी';

  @override
  String get language => 'Language';

  @override
  String get switchLanguage => 'Change Language';

  @override
  String goodDay(String name) {
    return 'Good day, $name';
  }

  @override
  String get headWorkspace => 'Head Distributor workspace';

  @override
  String get employeeWorkspace => 'Employee distribution workspace';

  @override
  String get commonSave => 'Save';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonAdd => 'Add';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonClose => 'Close';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonRefresh => 'Refresh';

  @override
  String get commonTryAgain => 'Try again';

  @override
  String get commonSearch => 'Search';

  @override
  String get commonFilter => 'Filter';

  @override
  String get commonClear => 'Clear';

  @override
  String get commonDone => 'Done';

  @override
  String get commonBack => 'Back';

  @override
  String get commonLoading => 'Loading...';

  @override
  String get commonActive => 'Active';

  @override
  String get commonArchived => 'Archived';

  @override
  String get commonUnassigned => 'Unassigned';

  @override
  String get commonSuccess => 'Success';

  @override
  String get commonError => 'Error';

  @override
  String get commonWarning => 'Warning';

  @override
  String get commonNotice => 'Notice';

  @override
  String get commonNoData => 'No records found.';

  @override
  String get authSignIn => 'Sign In';

  @override
  String get authSignOut => 'Sign Out';

  @override
  String get authEmail => 'Email Address';

  @override
  String get authPassword => 'Password';

  @override
  String get authForgotPassword => 'Forgot password?';

  @override
  String get authResetPassword => 'Reset Password';

  @override
  String get authAccountSettings => 'Account Settings';

  @override
  String get authChangePassword => 'Change Password';

  @override
  String get authRequestDeletion => 'Request Account Deletion';

  @override
  String get authAccessPending => 'Account Access Pending';

  @override
  String get authJoinAgency => 'Join Agency';

  @override
  String get authInviteCode => 'Invitation Code';

  @override
  String get authCreateAgency => 'Register New Agency';

  @override
  String get dashboardTitle => 'PaperRoute';

  @override
  String get currentOutstanding => 'Current outstanding';

  @override
  String get todayCollection => 'Today\'s collection';

  @override
  String monthBilled(String month) {
    return '$month billed';
  }

  @override
  String monthNetCollected(String month) {
    return '$month net collected';
  }

  @override
  String get quickActions => 'Quick actions';

  @override
  String get dailyPricing => 'Daily pricing';

  @override
  String get addCustomer => 'Add customer';

  @override
  String get recordPayment => 'Record payment';

  @override
  String get viewReports => 'View reports';

  @override
  String get recentActivity => 'Recent activity';

  @override
  String get recentPayments => 'Recent collections';

  @override
  String get recentBilling => 'Recent billing';

  @override
  String get recentCustomers => 'Recent customers';

  @override
  String get customersTitle => 'Customers';

  @override
  String get customerDetails => 'Customer Profile';

  @override
  String get quickAddCustomer => 'Quick Add Customer';

  @override
  String get saveAndAddNext => 'Save & Add Next';

  @override
  String get customerName => 'Customer Name';

  @override
  String get customerPhone => 'Phone Number';

  @override
  String get alternatePhone => 'Alternate Phone';

  @override
  String get customerAddress => 'Delivery Address';

  @override
  String get customerHouseNumber => 'House / Flat Number';

  @override
  String get customerBuildingInfo => 'Wing / Floor / Tower';

  @override
  String get customerLandmark => 'Landmark';

  @override
  String get customerArea => 'Delivery Area';

  @override
  String get customerPlacement => 'Delivery Placement';

  @override
  String get customerCode => 'Customer ID';

  @override
  String customerSaved(String code, String name) {
    return 'Customer $code ($name) saved successfully';
  }

  @override
  String get locationNotes => 'Location Notes';

  @override
  String get openingBalance => 'Opening Balance (₹)';

  @override
  String get placementDoorstep => 'Doorstep';

  @override
  String get placementHandToCustomer => 'Hand to customer';

  @override
  String get placementReception => 'Security / Reception';

  @override
  String get placementCollectionPoint => 'Collection Point';

  @override
  String get archiveCustomer => 'Archive Customer';

  @override
  String get searchCustomerHint => 'Search name, phone, code or landmark...';

  @override
  String get subscriptionsTitle => 'Newspaper Subscriptions';

  @override
  String get subscriptionDetails => 'Subscription Details';

  @override
  String get addSubscription => 'Add Subscription';

  @override
  String get editSubscription => 'Edit Subscription';

  @override
  String get pauseAllSubscriptions => 'Pause All Subscriptions';

  @override
  String get resumeAllSubscriptions => 'Resume All Subscriptions';

  @override
  String get pauseDelivery => 'Pause Delivery';

  @override
  String get resumeDelivery => 'Resume Delivery';

  @override
  String get stopSubscription => 'End Subscription';

  @override
  String get stopSubscriptionPermanently => 'Stop Subscription Permanently';

  @override
  String pauseNotice(String start, String end, int days, String resume) {
    return 'No delivery from $start to $end ($days days). Delivery resumes on: $resume.';
  }

  @override
  String get pauseReason => 'Reason for pause';

  @override
  String get pauseReasonVacation => 'Out of town / Vacation';

  @override
  String get pauseReasonFestival => 'Festival / Holiday';

  @override
  String get pauseReasonCustomerRequest => 'Customer request';

  @override
  String get pauseReasonOther => 'Other reason';

  @override
  String permanentStopNotice(String date) {
    return 'Historical billing and past collection receipts will be permanently preserved. Delivered days up to $date will be billed normally.';
  }

  @override
  String get newspaperTitle => 'Publication';

  @override
  String get quantity => 'Copies';

  @override
  String get deliveryDays => 'Delivery Days';

  @override
  String get customPrice => 'Custom Price per Day (Optional)';

  @override
  String get allSubscriptionsPaused => 'All subscriptions paused for this household';

  @override
  String get pauseAllSuccess => 'All subscriptions paused successfully';

  @override
  String get resumeAllSuccess => 'All subscriptions resumed successfully';

  @override
  String get morningRouteTitle => 'Morning Route';

  @override
  String morningRouteProgress(int delivered, int total, int percent) {
    return '$delivered of $total drops completed ($percent%)';
  }

  @override
  String get markDelivered => 'Mark Delivered';

  @override
  String get undoDelivered => 'Undo Delivered';

  @override
  String get deliveredBadge => 'Delivered';

  @override
  String get pausedTodayBadge => 'PAUSED TODAY — DO NOT DELIVER';

  @override
  String get logException => 'Report Issue';

  @override
  String get issueBadge => 'Issue';

  @override
  String get selectRouteDate => 'Select Route Date';

  @override
  String get refreshRoute => 'Refresh Route';

  @override
  String filterAll(int count) {
    return 'All ($count)';
  }

  @override
  String filterPending(int count) {
    return 'Pending ($count)';
  }

  @override
  String filterDelivered(int count) {
    return 'Delivered ($count)';
  }

  @override
  String filterPaused(int count) {
    return 'Paused ($count)';
  }

  @override
  String get allDropsCompleted => '🎉 All active drops completed!';

  @override
  String get noMatchingStops => 'No stops match this filter.';

  @override
  String get exceptionHouseLocked => 'House Locked / Gate Closed';

  @override
  String get exceptionRain => 'Heavy Rain / Waterlogged';

  @override
  String get exceptionPaperShortage => 'Newspaper Shortage';

  @override
  String get exceptionCustomerRefused => 'Customer Refused Delivery';

  @override
  String get papersToDeliver => 'PAPERS TO DELIVER:';

  @override
  String get pausedHouseholdNotice => 'No action required for paused household.';

  @override
  String reportIssueFor(String name) {
    return 'Report Issue for $name';
  }

  @override
  String get headTodayTitle => 'Today\'s Operations';

  @override
  String get headTodaySubtitle => 'Live Depot Circulation & Delivery Monitoring';

  @override
  String get depotPickupTally => 'Depot Pickup Circulation';

  @override
  String copiesToPickup(int count) {
    return '$count copies';
  }

  @override
  String orderedCopies(int count) {
    return 'Ordered: $count';
  }

  @override
  String pausedCopies(int count) {
    return 'Paused: $count';
  }

  @override
  String copiesToDistribute(int count) {
    return 'To Distribute: $count';
  }

  @override
  String get routeProgressTitle => 'Route Progress by Hawker';

  @override
  String get todayCollectionsTitle => 'Today\'s Collections';

  @override
  String cashCollected(String amount) {
    return 'Cash in Hand: $amount';
  }

  @override
  String upiCollected(String amount) {
    return 'Direct UPI: $amount';
  }

  @override
  String totalToday(String amount) {
    return 'Total Today: $amount';
  }

  @override
  String get operationalAlertsTitle => 'Operational Exceptions Reported Today';

  @override
  String get noOperationalAlerts => 'No delivery exceptions reported today. All routes running smoothly.';

  @override
  String get billingTitle => 'Monthly Billing';

  @override
  String get generateBills => 'Generate Bills';

  @override
  String get billingMonth => 'Billing Month';

  @override
  String get finalizedBills => 'Finalized Bills';

  @override
  String get openBills => 'Pending Bills';

  @override
  String totalDue(String amount) {
    return 'Total Due: $amount';
  }

  @override
  String get downloadBill => 'Download Bill (PDF)';

  @override
  String get dailyPricingTitle => 'Daily Pricing';

  @override
  String get collectionsTitle => 'Collections & Payments';

  @override
  String get recordPaymentTitle => 'Record Payment';

  @override
  String get amount => 'Amount (₹)';

  @override
  String get paymentMethod => 'Payment Method';

  @override
  String get methodCash => 'Cash';

  @override
  String get methodUpi => 'UPI QR Code';

  @override
  String get upiReference => 'UPI Transaction ID / Ref';

  @override
  String get outstandingTitle => 'Current Outstanding';

  @override
  String get collectPayment => 'Collect Payment';

  @override
  String get paymentReceipt => 'Receipt';

  @override
  String duplicatePaymentWarning(String amount, String time, String collector) {
    return 'Notice: A payment of $amount was already collected today at $time by $collector.';
  }

  @override
  String get ledgerTimelineTitle => 'Ledger Statement';

  @override
  String get shareOnWhatsApp => 'Share Statement on WhatsApp';

  @override
  String runningBalance(String amount) {
    return 'Balance: $amount';
  }

  @override
  String get teamTitle => 'Employees & Hawkers';

  @override
  String get inviteEmployee => 'Invite Employee';

  @override
  String get pendingRemovalRequests => 'Pending Offboarding Requests';

  @override
  String get reassignRoute => 'Reassign Route';

  @override
  String get approveOffboarding => 'Approve Offboarding & Archive';

  @override
  String get leaveAgency => 'Request to Leave Agency';

  @override
  String get areasTitle => 'Delivery Areas';

  @override
  String get addArea => 'Add Delivery Area';

  @override
  String get newspapersTitle => 'Newspapers & Publications';

  @override
  String get addNewspaper => 'Add Publication';
}
