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

  @override
  String get arrangeDeliveryRoute => 'Arrange Delivery Route';

  @override
  String get routeOrderSaved => 'Route order saved successfully.';

  @override
  String get placeInRoute => 'Place in delivery route';

  @override
  String get placeInRouteFirst => 'At start of route (First)';

  @override
  String get placeInRouteAfter => 'After an existing customer';

  @override
  String get placeInRouteLast => 'At end of route (Last)';

  @override
  String get precedingCustomer => 'Preceding customer';

  @override
  String get selectAreaFirst => 'Select an area first to choose preceding customer.';

  @override
  String get noCustomersInArea => 'No existing customers in this area.';

  @override
  String get dragHandleHint => 'Long-press or drag the handle on the right to reorder delivery stops.';

  @override
  String get permissionDeniedArrangeRoute => 'You do not have permission to rearrange route stops for this area.';

  @override
  String get noCustomersToArrange => 'No active customers in this area to arrange.';

  @override
  String get customerEditTitle => 'Edit Customer';

  @override
  String get customerNewTitle => 'New Customer';

  @override
  String get customerDetailsTitle => 'Customer Details';

  @override
  String get customerNotFound => 'Customer not found';

  @override
  String get customerNotFoundMessage => 'The record may no longer be available.';

  @override
  String customerCreated(String code) {
    return 'Customer $code created.';
  }

  @override
  String get customerDetailsUpdated => 'Customer details updated.';

  @override
  String get customerAssignmentUpdated => 'Customer assignment updated.';

  @override
  String assignCustomerTitle(String name) {
    return 'Assign $name';
  }

  @override
  String get selectAnArea => 'Select an area';

  @override
  String get keepUnassigned => 'Keep unassigned';

  @override
  String get saveAssignment => 'Save assignment';

  @override
  String get loadMoreCustomers => 'Load more customers';

  @override
  String get allAreas => 'All areas';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get customerConsentRecorded => 'Customer consent recorded';

  @override
  String get changeAssignment => 'Change assignment';

  @override
  String get upiSettingsTitle => 'UPI Settings';

  @override
  String get enableUpiRequests => 'Enable UPI collection requests';

  @override
  String get upiSettingsUpdated => 'UPI collection settings updated.';

  @override
  String get collectFromCustomerRecord => 'Collect from a customer record';

  @override
  String get loadMorePayments => 'Load more payments';

  @override
  String get oldestOutstandingFirst => 'Oldest outstanding first';

  @override
  String get receiptMustBeVerified => 'Receipt must be verified manually';

  @override
  String get retryConfirmation => 'Retry confirmation';

  @override
  String get confirmReceiptOfPayment => 'Confirm receipt of payment?';

  @override
  String get goBack => 'Go back';

  @override
  String get iVerifiedReceipt => 'I verified receipt';

  @override
  String get generateAmountUpiQr => 'Generate amount-specific UPI QR';

  @override
  String get paymentReceiptTitle => 'Payment Receipt';

  @override
  String get notYetConfirmedReceipt => 'Not yet a confirmed receipt';

  @override
  String get serverConfirmedLedger => 'Server-confirmed ledger entry';

  @override
  String get remainingOutstanding => 'Remaining outstanding';

  @override
  String get recordPaymentReversal => 'Record Payment Reversal';

  @override
  String get recordReversal => 'Record reversal';

  @override
  String get finalizedBill => 'Finalized Bill';

  @override
  String get immutableFinancialSnapshot => 'Immutable financial snapshot';

  @override
  String deliveryLinesCount(int count) {
    return '$count delivery lines';
  }

  @override
  String get noAdjustmentsApplied => 'No adjustments were applied.';

  @override
  String get loadMoreDailyLines => 'Load more daily lines';

  @override
  String get finalizeBillQuestion => 'Finalize immutable bill?';

  @override
  String get finalizeBillAction => 'Finalize bill';

  @override
  String get finalizeImmutableBill => 'Finalize immutable bill';

  @override
  String get readOnlyCalculation => 'Read-only calculation';

  @override
  String get signedBillingAdjustment => 'Signed billing adjustment';

  @override
  String get recordAdjustment => 'Record adjustment';

  @override
  String get adjustmentRecorded => 'Adjustment recorded with audit history.';

  @override
  String monthPreview(String month) {
    return '$month preview';
  }

  @override
  String monthBill(String month) {
    return '$month bill';
  }

  @override
  String get todayOperationsTitle => 'Today\'s Operations';

  @override
  String get circulationSummaryTitle => 'Circulation Tally';

  @override
  String get findTheHouse => 'Find the house';

  @override
  String get landmarkPrefix => 'LANDMARK: ';

  @override
  String get contactSection => 'Contact';

  @override
  String get primaryPhone => 'Primary phone';

  @override
  String get deliveryAssignment => 'Delivery assignment';

  @override
  String get areaLabel => 'Area';

  @override
  String get employeeLabel => 'Employee';

  @override
  String get placementLabel => 'Placement';

  @override
  String get billingPreference => 'Billing preference';

  @override
  String get consentedGpsLocation => 'Consented GPS location';

  @override
  String get latitude => 'Latitude';

  @override
  String get longitude => 'Longitude';

  @override
  String get operationalNotes => 'Operational notes';

  @override
  String get financialOpening => 'Financial opening';

  @override
  String get immutableOpeningNotice => 'Immutable after creation; future corrections require an audited adjustment.';

  @override
  String get assignmentAndChangeHistory => 'Assignment and change history';

  @override
  String get noCustomerAuditEntries => 'No customer audit entries are available yet.';

  @override
  String couldNotLoadAuditHistory(String error) {
    return 'Could not load audit history: $error';
  }

  @override
  String get reactivateCustomer => 'Reactivate customer';

  @override
  String get reactivateCustomerConfirm => 'Reactivate customer?';

  @override
  String get archiveCustomerConfirm => 'Archive customer?';

  @override
  String get reactivateCustomerDesc => 'The customer will return to active operational lists.';

  @override
  String get archiveCustomerDesc => 'The record and all history will be preserved. Delivery and billing records will not be deleted.';

  @override
  String get customerReactivated => 'Customer reactivated.';

  @override
  String get customerArchivedNotice => 'Customer archived without deleting history.';

  @override
  String get auditCustomerCreated => 'Customer created';

  @override
  String get auditCustomerUpdated => 'Customer details updated';

  @override
  String get auditCustomerArchived => 'Customer archived';

  @override
  String get auditCustomerReactivated => 'Customer reactivated';

  @override
  String get auditCustomerAssignmentTransferred => 'Assignment transferred';

  @override
  String get customerPaymentHistory => 'Customer payment history';

  @override
  String get paymentHistory => 'Payment history';

  @override
  String get myCollections => 'My collections';

  @override
  String get customerPaymentHistorySubtitle => 'Confirmed payments for this customer, including reversal status and immutable allocations.';

  @override
  String get headPaymentHistorySubtitle => 'Confirmed payments and reversals are retained as an immutable financial trail.';

  @override
  String get employeeCollectionsSubtitle => 'Your own immutable collection receipts remain available after a customer is reassigned.';

  @override
  String get collectFromCustomerRecordSubtitle => 'Open an active customer to confirm cash, UPI, bank-transfer, or other manual collection.';

  @override
  String get noConfirmedPayments => 'No confirmed payments';

  @override
  String get noConfirmedPaymentsMessage => 'A payment appears here only after an authorized collector confirms receipt.';

  @override
  String get paymentReversedBadge => 'REVERSED';

  @override
  String reversalReasonPrefix(String reason) {
    return 'Reversal reason: $reason';
  }

  @override
  String collectedByPrefix(String name, String method) {
    return 'Collected by $name • $method';
  }

  @override
  String get paymentReversalSuccess => 'Payment reversed with immutable financial audit record.';

  @override
  String get collectionUnavailable => 'Collection unavailable';

  @override
  String get billingWorkspace => 'Billing workspace';

  @override
  String get assignedBills => 'Assigned bills';

  @override
  String get billingWorkspaceSubtitle => 'Review deterministic daily charges before finalization. Previews never write data.';

  @override
  String get assignedBillsSubtitle => 'You can read finalized bills only for customers currently assigned to you.';

  @override
  String get noActiveCustomers => 'No active customers';

  @override
  String get noActiveCustomersDesc => 'There are no accessible active customers to bill.';

  @override
  String get routeCoverage => 'Route coverage';

  @override
  String get routeCoverageSubtitle => 'Create operational areas and keep employee coverage synchronized with authoritative member records.';

  @override
  String get newArea => 'New area';

  @override
  String get editArea => 'Edit area';

  @override
  String get areaName => 'Area name';

  @override
  String get areaDescription => 'Description (optional)';

  @override
  String get assignEmployees => 'Assign employees';

  @override
  String get noAreasConfigured => 'No areas configured';

  @override
  String get noAreasConfiguredSubtitle => 'Create delivery areas to organize customer stops and route assignments.';

  @override
  String get publicationsSubtitle => 'Manage newspapers, periodicals, and standard weekday/weekend pricing schedules.';

  @override
  String get dailyPricingSubtitle => 'Set single-day or holiday paper prices that override recurring subscription rates for that morning.';

  @override
  String get recordPrice => 'Record price';

  @override
  String get standardPrice => 'Standard price';

  @override
  String get teamSubtitle => 'Manage agency staff, invitation codes, and operational permissions.';

  @override
  String get manageEmployee => 'Manage employee';

  @override
  String get employeeAccessUpdated => 'Employee access updated.';

  @override
  String get invitationCreated => 'Invitation created';

  @override
  String get invitationCodeCopied => 'Invitation code copied.';

  @override
  String get invitationRevoked => 'Invitation revoked.';

  @override
  String get copyCode => 'Copy code';

  @override
  String get createInvitation => 'Create invitation';

  @override
  String get permissionsLabel => 'Permissions';

  @override
  String get initialAreasLabel => 'Initial areas';

  @override
  String get activeAccess => 'Active access';

  @override
  String get businessReports => 'Business reports';

  @override
  String get reportsSubtitle => 'Server-side totals and paginated records respect the selected filters. CSV exports use the same query scope.';

  @override
  String get exportFilteredCsv => 'Export filtered CSV';

  @override
  String get loadMoreResults => 'Load more results';

  @override
  String get applyFilters => 'Apply filters';

  @override
  String get allEmployees => 'All employees';

  @override
  String get allNewspapers => 'All newspapers';

  @override
  String get allMethods => 'All methods';

  @override
  String get allBalances => 'All balances';

  @override
  String get allSubscriptions => 'All subscriptions';

  @override
  String get detailedCustomerMode => 'Detailed Mode';

  @override
  String get saveCustomer => 'Save Customer';

  @override
  String get bulkImportCustomers => 'Bulk Import Customers (CSV)';

  @override
  String get masterCatalogTitle => 'Indian Publication Catalogue';

  @override
  String get browseMasterCatalog => 'Browse Indian Master Catalogue';

  @override
  String get magazinesTab => 'Magazines';

  @override
  String get newspapersTab => 'Newspapers';

  @override
  String get frequencyDaily => 'Daily';

  @override
  String get frequencyWeekly => 'Weekly';

  @override
  String get frequencyFortnightly => 'Fortnightly';

  @override
  String get frequencyMonthly => 'Monthly';
}
