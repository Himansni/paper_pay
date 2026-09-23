// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appName => 'पेपररूट';

  @override
  String get english => 'English';

  @override
  String get hindi => 'हिन्दी';

  @override
  String get language => 'भाषा';

  @override
  String get switchLanguage => 'भाषा बदलें';

  @override
  String goodDay(String name) {
    return 'नमस्ते, $name';
  }

  @override
  String get headWorkspace => 'एजेंसी मालिक कार्यक्षेत्र';

  @override
  String get employeeWorkspace => 'वितरण साथी कार्यक्षेत्र';

  @override
  String get commonSave => 'सुरक्षित करें';

  @override
  String get commonCancel => 'रद्द करें';

  @override
  String get commonAdd => 'जोड़ें';

  @override
  String get commonEdit => 'संपादित करें';

  @override
  String get commonDelete => 'हटाएं';

  @override
  String get commonClose => 'बंद करें';

  @override
  String get commonConfirm => 'पुष्टि करें';

  @override
  String get commonRefresh => 'ताज़ा करें';

  @override
  String get commonTryAgain => 'पुनः प्रयास करें';

  @override
  String get commonSearch => 'खोजें';

  @override
  String get commonFilter => 'फ़िल्टर';

  @override
  String get commonClear => 'हटाएं';

  @override
  String get commonDone => 'पूर्ण';

  @override
  String get commonBack => 'वापस';

  @override
  String get commonLoading => 'लोड हो रहा है...';

  @override
  String get commonActive => 'सक्रिय';

  @override
  String get commonArchived => 'संग्रहीत';

  @override
  String get commonUnassigned => 'अनावंटित';

  @override
  String get commonSuccess => 'सफल';

  @override
  String get commonError => 'त्रुटि';

  @override
  String get commonWarning => 'चेतावनी';

  @override
  String get commonNotice => 'सूचना';

  @override
  String get commonNoData => 'कोई रिकॉर्ड नहीं मिला।';

  @override
  String get authSignIn => 'लॉग इन करें';

  @override
  String get authSignOut => 'लॉग आउट करें';

  @override
  String get authEmail => 'ईमेल पता';

  @override
  String get authPassword => 'पासवर्ड';

  @override
  String get authForgotPassword => 'पासवर्ड भूल गए?';

  @override
  String get authResetPassword => 'पासवर्ड रीसेट करें';

  @override
  String get authAccountSettings => 'खाता सेटिंग्स';

  @override
  String get authChangePassword => 'पासवर्ड बदलें';

  @override
  String get authRequestDeletion => 'खाता हटाने का अनुरोध करें';

  @override
  String get authAccessPending => 'खाता सक्रियण प्रतीक्षारत';

  @override
  String get authJoinAgency => 'एजेंसी से जुड़ें';

  @override
  String get authInviteCode => 'निमंत्रण कोड';

  @override
  String get authCreateAgency => 'नई एजेंसी पंजीकृत करें';

  @override
  String get dashboardTitle => 'पेपररूट';

  @override
  String get currentOutstanding => 'कुल बकाया राशि';

  @override
  String get todayCollection => 'आज की कुल वसूली';

  @override
  String monthBilled(String month) {
    return '$month का कुल बिल';
  }

  @override
  String monthNetCollected(String month) {
    return '$month शुद्ध वसूली';
  }

  @override
  String get quickActions => 'त्वरित कार्य';

  @override
  String get dailyPricing => 'दैनिक दर निर्धारण';

  @override
  String get addCustomer => 'नया ग्राहक जोड़ें';

  @override
  String get recordPayment => 'भुगतान दर्ज करें';

  @override
  String get viewReports => 'रिपोर्ट्स देखें';

  @override
  String get recentActivity => 'हाल की गतिविधि';

  @override
  String get recentPayments => 'हाल के भुगतान';

  @override
  String get recentBilling => 'हाल के बिल';

  @override
  String get recentCustomers => 'हाल के ग्राहक';

  @override
  String get customersTitle => 'ग्राहक';

  @override
  String get customerDetails => 'ग्राहक प्रोफ़ाइल';

  @override
  String get quickAddCustomer => 'त्वरित ग्राहक जोड़ें';

  @override
  String get saveAndAddNext => 'सहेजें और अगला जोड़ें';

  @override
  String get customerName => 'ग्राहक का नाम';

  @override
  String get customerPhone => 'मोबाइल नंबर';

  @override
  String get alternatePhone => 'वैकल्पिक नंबर';

  @override
  String get customerAddress => 'वितरण का पता';

  @override
  String get customerHouseNumber => 'मकान / फ्लैट नंबर';

  @override
  String get customerBuildingInfo => 'विंग / मंजिल / टॉवर';

  @override
  String get customerLandmark => 'लैंडमार्क (पहचान चिन्ह)';

  @override
  String get customerArea => 'वितरण क्षेत्र';

  @override
  String get customerPlacement => 'अख़बार रखने का स्थान';

  @override
  String get customerCode => 'ग्राहक कोड';

  @override
  String customerSaved(String code, String name) {
    return 'ग्राहक $code ($name) सफलतापूर्वक सहेजा गया';
  }

  @override
  String get locationNotes => 'स्थान संबंधी निर्देश';

  @override
  String get openingBalance => 'प्रारंभिक शेष (₹)';

  @override
  String get placementDoorstep => 'दरवाजे पर';

  @override
  String get placementHandToCustomer => 'हाथ में दें';

  @override
  String get placementReception => 'सिक्योरिटी / रिसेप्शन';

  @override
  String get placementCollectionPoint => 'वितरण केंद्र';

  @override
  String get archiveCustomer => 'ग्राहक को संग्रहित करें';

  @override
  String get searchCustomerHint => 'नाम, फोन, कोड या पहचान चिन्ह से खोजें...';

  @override
  String get subscriptionsTitle => 'अख़बार सदस्यता';

  @override
  String get subscriptionDetails => 'सदस्यता विवरण';

  @override
  String get addSubscription => 'नई सदस्यता जोड़ें';

  @override
  String get editSubscription => 'सदस्यता बदलें';

  @override
  String get pauseAllSubscriptions => 'सभी अख़बार बंद करें (अवकाश)';

  @override
  String get resumeAllSubscriptions => 'सभी अख़बार पुनः शुरू करें';

  @override
  String get pauseDelivery => 'वितरण रोकें';

  @override
  String get resumeDelivery => 'वितरण पुनः प्रारंभ करें';

  @override
  String get stopSubscription => 'सदस्यता समाप्त करें';

  @override
  String get stopSubscriptionPermanently => 'सदस्यता स्थायी रूप से बंद करें';

  @override
  String pauseNotice(String start, String end, int days, String resume) {
    return '$start से $end ($days दिन) तक कोई वितरण नहीं होगा। वितरण पुनः शुरू: $resume।';
  }

  @override
  String get pauseReason => 'अख़बार रोकने का कारण';

  @override
  String get pauseReasonVacation => 'बाहर जाना / अवकाश';

  @override
  String get pauseReasonFestival => 'त्यौहार / पर्व';

  @override
  String get pauseReasonCustomerRequest => 'ग्राहक का अनुरोध';

  @override
  String get pauseReasonOther => 'अन्य कारण';

  @override
  String permanentStopNotice(String date) {
    return 'पिछला लेखा-जोखा और रसीदें सुरक्षित रहेंगी। $date तक बांटे गए दिनों का बिल सामान्य रूप से बनेगा।';
  }

  @override
  String get newspaperTitle => 'प्रकाशन / अख़बार';

  @override
  String get quantity => 'प्रतियां';

  @override
  String get deliveryDays => 'वितरण के दिन';

  @override
  String get customPrice => 'विशेष दैनिक दर (वैकल्पिक)';

  @override
  String get allSubscriptionsPaused => 'इस परिवार के सभी अख़बार आज रुके हुए हैं';

  @override
  String get pauseAllSuccess => 'सभी सदस्यताओं पर अवकाश सफलतापूर्वक दर्ज किया गया';

  @override
  String get resumeAllSuccess => 'सभी सदस्यताओं का वितरण सफलतापूर्वक पुनः प्रारंभ हुआ';

  @override
  String get morningRouteTitle => 'प्रभात वितरण लाइन';

  @override
  String morningRouteProgress(int delivered, int total, int percent) {
    return '$total में से $delivered घरों में वितरण पूर्ण ($percent%)';
  }

  @override
  String get markDelivered => 'वितरण पूर्ण';

  @override
  String get undoDelivered => 'वितरण वापस लें';

  @override
  String get deliveredBadge => 'वितरित';

  @override
  String get pausedTodayBadge => 'आज अवकाश — कृपया अख़बार न डालें';

  @override
  String get logException => 'समस्या दर्ज करें';

  @override
  String get issueBadge => 'समस्या';

  @override
  String get selectRouteDate => 'मार्ग की तारीख चुनें';

  @override
  String get refreshRoute => 'लाइन ताज़ा करें';

  @override
  String filterAll(int count) {
    return 'सभी ($count)';
  }

  @override
  String filterPending(int count) {
    return 'शेष ($count)';
  }

  @override
  String filterDelivered(int count) {
    return 'वितरित ($count)';
  }

  @override
  String filterPaused(int count) {
    return 'अवकाश ($count)';
  }

  @override
  String get allDropsCompleted => '🎉 आज के सभी सक्रिय वितरण पूर्ण हो चुके हैं!';

  @override
  String get noMatchingStops => 'इस फ़िल्टर में कोई घर नहीं मिला।';

  @override
  String get exceptionHouseLocked => 'मकान बंद / गेट बंद';

  @override
  String get exceptionRain => 'भारी बारिश / जलभराव';

  @override
  String get exceptionPaperShortage => 'अख़बार की कमी';

  @override
  String get exceptionCustomerRefused => 'ग्राहक ने लेने से मना किया';

  @override
  String get papersToDeliver => 'वितरण हेतु अख़बार:';

  @override
  String get pausedHouseholdNotice => 'अवकाश वाले घर के लिए किसी कार्रवाई की आवश्यकता नहीं है।';

  @override
  String reportIssueFor(String name) {
    return '$name के लिए समस्या दर्ज करें';
  }

  @override
  String get headTodayTitle => 'आज का संचालन';

  @override
  String get headTodaySubtitle => 'लाइव डिपो उठान और वितरण निगरानी';

  @override
  String get depotPickupTally => 'डिपो से अखबार उठान';

  @override
  String copiesToPickup(int count) {
    return '$count प्रतियां';
  }

  @override
  String orderedCopies(int count) {
    return 'कुल ऑर्डर: $count';
  }

  @override
  String pausedCopies(int count) {
    return 'रुकी हुई: $count';
  }

  @override
  String copiesToDistribute(int count) {
    return 'बांटने योग्य: $count';
  }

  @override
  String get routeProgressTitle => 'हॉकर अनुसार लाइन प्रगति';

  @override
  String get todayCollectionsTitle => 'आज की वसूली';

  @override
  String cashCollected(String amount) {
    return 'नकद संग्रह: $amount';
  }

  @override
  String upiCollected(String amount) {
    return 'सीधा यूपीआई: $amount';
  }

  @override
  String totalToday(String amount) {
    return 'आज का कुल: $amount';
  }

  @override
  String get operationalAlertsTitle => 'आज दर्ज की गई वितरण समस्याएं';

  @override
  String get noOperationalAlerts => 'आज कोई समस्या दर्ज नहीं हुई। सभी वितरण लाइनें सुचारू हैं।';

  @override
  String get billingTitle => 'मासिक बिलिंग';

  @override
  String get generateBills => 'मासिक बिल बनाएं';

  @override
  String get billingMonth => 'बिलिंग का महीना';

  @override
  String get finalizedBills => 'जारी किए गए बिल';

  @override
  String get openBills => 'प्रतीक्षारत बिल';

  @override
  String totalDue(String amount) {
    return 'कुल देय: $amount';
  }

  @override
  String get downloadBill => 'बिल डाउनलोड करें (PDF)';

  @override
  String get dailyPricingTitle => 'दैनिक दर निर्धारण';

  @override
  String get collectionsTitle => 'वसूली एवं भुगतान';

  @override
  String get recordPaymentTitle => 'भुगतान दर्ज करें';

  @override
  String get amount => 'राशि (₹)';

  @override
  String get paymentMethod => 'भुगतान का प्रकार';

  @override
  String get methodCash => 'नकद (Cash)';

  @override
  String get methodUpi => 'यूपीआई क्यूआर (UPI QR)';

  @override
  String get upiReference => 'यूपीआई संदर्भ / ट्रांजैक्शन आईडी';

  @override
  String get outstandingTitle => 'कुल बकाया राशि';

  @override
  String get collectPayment => 'भुगतान प्राप्त करें';

  @override
  String get paymentReceipt => 'रसीद';

  @override
  String duplicatePaymentWarning(String amount, String time, String collector) {
    return 'सूचना: $collector द्वारा आज $time बजे पहले ही $amount का भुगतान लिया जा चुका है।';
  }

  @override
  String get ledgerTimelineTitle => 'लेखा-जोखा विवरण';

  @override
  String get shareOnWhatsApp => 'व्हाट्सएप पर विवरण साझा करें';

  @override
  String runningBalance(String amount) {
    return 'शेष राशि: $amount';
  }

  @override
  String get teamTitle => 'स्टाफ एवं हॉकर साथी';

  @override
  String get inviteEmployee => 'नए साथी को आमंत्रित करें';

  @override
  String get pendingRemovalRequests => 'प्रतीक्षारत विमुक्ति अनुरोध';

  @override
  String get reassignRoute => 'मार्ग पुनः आवंटित करें';

  @override
  String get approveOffboarding => 'विमुक्ति स्वीकृत एवं संग्रहित करें';

  @override
  String get leaveAgency => 'एजेंसी छोड़ने का अनुरोध करें';

  @override
  String get areasTitle => 'वितरण क्षेत्र';

  @override
  String get addArea => 'नया क्षेत्र जोड़ें';

  @override
  String get newspapersTitle => 'अख़बार एवं पत्रिकाएं';

  @override
  String get addNewspaper => 'नया प्रकाशन जोड़ें';

  @override
  String get arrangeDeliveryRoute => 'वितरण मार्ग क्रम व्यवस्थित करें';

  @override
  String get routeOrderSaved => 'मार्ग क्रम सफलतापूर्वक सहेजा गया।';

  @override
  String get placeInRoute => 'वितरण मार्ग में स्थान';

  @override
  String get placeInRouteFirst => 'मार्ग की शुरुआत में (पहला)';

  @override
  String get placeInRouteAfter => 'किसी मौजूदा ग्राहक के बाद';

  @override
  String get placeInRouteLast => 'मार्ग के अंत में (अंतिम)';

  @override
  String get precedingCustomer => 'पूर्ववर्ती ग्राहक';

  @override
  String get selectAreaFirst => 'पूर्ववर्ती ग्राहक चुनने के लिए पहले क्षेत्र चुनें।';

  @override
  String get noCustomersInArea => 'इस क्षेत्र में कोई ग्राहक नहीं हैं।';

  @override
  String get dragHandleHint => 'स्टॉप्स को पुनर्व्यवस्थित करने के लिए दाईं ओर के हैंडल को खींचें।';

  @override
  String get permissionDeniedArrangeRoute => 'आपको इस क्षेत्र के मार्ग क्रम को बदलने की अनुमति नहीं है।';

  @override
  String get noCustomersToArrange => 'इस क्षेत्र में व्यवस्थित करने के लिए कोई सक्रिय ग्राहक नहीं हैं।';

  @override
  String get customerEditTitle => 'ग्राहक संपादित करें';

  @override
  String get customerNewTitle => 'नया ग्राहक';

  @override
  String get customerDetailsTitle => 'ग्राहक विवरण';

  @override
  String get customerNotFound => 'ग्राहक नहीं मिला';

  @override
  String get customerNotFoundMessage => 'रिकॉर्ड अब उपलब्ध नहीं हो सकता है।';

  @override
  String customerCreated(String code) {
    return 'ग्राहक $code बन गया।';
  }

  @override
  String get customerDetailsUpdated => 'ग्राहक विवरण अपडेट कर दिया गया।';

  @override
  String get customerAssignmentUpdated => 'ग्राहक असाइनमेंट अपडेट किया गया।';

  @override
  String assignCustomerTitle(String name) {
    return '$name को असाइन करें';
  }

  @override
  String get selectAnArea => 'एक क्षेत्र चुनें';

  @override
  String get keepUnassigned => 'अनावंटित रखें';

  @override
  String get saveAssignment => 'असाइनमेंट सहेजें';

  @override
  String get loadMoreCustomers => 'और ग्राहक लोड करें';

  @override
  String get allAreas => 'सभी क्षेत्र';

  @override
  String get clearSearch => 'खोज साफ़ करें';

  @override
  String get customerConsentRecorded => 'ग्राहक सहमति दर्ज की गई';

  @override
  String get changeAssignment => 'असाइनमेंट बदलें';

  @override
  String get upiSettingsTitle => 'UPI सेटिंग्स';

  @override
  String get enableUpiRequests => 'UPI संग्रह अनुरोध सक्षम करें';

  @override
  String get upiSettingsUpdated => 'UPI सेटिंग्स अपडेट की गईं।';

  @override
  String get collectFromCustomerRecord => 'ग्राहक रिकॉर्ड से संग्रह करें';

  @override
  String get loadMorePayments => 'और भुगतान लोड करें';

  @override
  String get oldestOutstandingFirst => 'सबसे पुराना बकाया पहले';

  @override
  String get receiptMustBeVerified => 'रसीद मैन्युअल रूप से सत्यापित की जानी चाहिए';

  @override
  String get retryConfirmation => 'पुष्टिकरण पुनः प्रयास करें';

  @override
  String get confirmReceiptOfPayment => 'भुगतान प्राप्ति की पुष्टि करें?';

  @override
  String get goBack => 'वापस जाएं';

  @override
  String get iVerifiedReceipt => 'मैंने प्राप्ति सत्यापित की';

  @override
  String get generateAmountUpiQr => 'राशि-विशिष्ट UPI QR बनाएं';

  @override
  String get paymentReceiptTitle => 'भुगतान रसीद';

  @override
  String get notYetConfirmedReceipt => 'अभी तक पुष्ट रसीद नहीं है';

  @override
  String get serverConfirmedLedger => 'सर्वर-पुष्ट खाता प्रविष्टि';

  @override
  String get remainingOutstanding => 'शेष बकाया';

  @override
  String get recordPaymentReversal => 'भुगतान उलटाव (रिवर्सल) दर्ज करें';

  @override
  String get recordReversal => 'रिवर्सल दर्ज करें';

  @override
  String get finalizedBill => 'अंतिम बिल';

  @override
  String get immutableFinancialSnapshot => 'अपरिवर्तनीय वित्तीय विवरण';

  @override
  String deliveryLinesCount(int count) {
    return '$count वितरण लाइनें';
  }

  @override
  String get noAdjustmentsApplied => 'कोई समायोजन लागू नहीं किया गया।';

  @override
  String get loadMoreDailyLines => 'और दैनिक लाइनें लोड करें';

  @override
  String get finalizeBillQuestion => 'क्या अपरिवर्तनीय बिल को अंतिम रूप दें?';

  @override
  String get finalizeBillAction => 'बिल अंतिम रूप दें';

  @override
  String get finalizeImmutableBill => 'अपरिवर्तनीय बिल अंतिम रूप दें';

  @override
  String get readOnlyCalculation => 'केवल-पठन गणना';

  @override
  String get signedBillingAdjustment => 'हस्ताक्षरित बिलिंग समायोजन';

  @override
  String get recordAdjustment => 'समायोजन दर्ज करें';

  @override
  String get adjustmentRecorded => 'ऑडिट इतिहास के साथ समायोजन दर्ज किया गया।';

  @override
  String monthPreview(String month) {
    return '$month पूर्वावलोकन';
  }

  @override
  String monthBill(String month) {
    return '$month बिल';
  }

  @override
  String get todayOperationsTitle => 'आज का संचालन';

  @override
  String get circulationSummaryTitle => 'वितरण गणना';

  @override
  String get findTheHouse => 'घर का पता';

  @override
  String get landmarkPrefix => 'लैंडमार्क: ';

  @override
  String get contactSection => 'संपर्क';

  @override
  String get primaryPhone => 'मुख्य फ़ोन';

  @override
  String get deliveryAssignment => 'वितरण आवंटन';

  @override
  String get areaLabel => 'क्षेत्र';

  @override
  String get employeeLabel => 'कर्मचारी';

  @override
  String get placementLabel => 'वितरण स्थान';

  @override
  String get billingPreference => 'बिलिंग प्राथमिकता';

  @override
  String get consentedGpsLocation => 'सहमति प्राप्त GPS स्थान';

  @override
  String get latitude => 'अक्षांश';

  @override
  String get longitude => 'देशांतर';

  @override
  String get operationalNotes => 'परिचालन टिप्पणियाँ';

  @override
  String get financialOpening => 'प्रारंभिक वित्तीय विवरण';

  @override
  String get immutableOpeningNotice => 'बनाने के बाद अपरिवर्तनीय; भविष्य के सुधारों के लिए ऑडिट किए गए समायोजन की आवश्यकता है।';

  @override
  String get assignmentAndChangeHistory => 'आवंटन और परिवर्तन इतिहास';

  @override
  String get noCustomerAuditEntries => 'अभी तक कोई ग्राहक ऑडिट प्रविष्टि उपलब्ध नहीं है।';

  @override
  String couldNotLoadAuditHistory(String error) {
    return 'ऑडिट इतिहास लोड नहीं किया जा सका: $error';
  }

  @override
  String get reactivateCustomer => 'ग्राहक पुनः सक्रिय करें';

  @override
  String get reactivateCustomerConfirm => 'क्या ग्राहक को पुनः सक्रिय करें?';

  @override
  String get archiveCustomerConfirm => 'क्या ग्राहक को संग्रहित (आर्काइव) करें?';

  @override
  String get reactivateCustomerDesc => 'ग्राहक सक्रिय परिचालन सूचियों में वापस आ जाएगा।';

  @override
  String get archiveCustomerDesc => 'रिकॉर्ड और सारा इतिहास सुरक्षित रहेगा। वितरण और बिलिंग रिकॉर्ड हटाए नहीं जाएंगे।';

  @override
  String get customerReactivated => 'ग्राहक पुनः सक्रिय किया गया।';

  @override
  String get customerArchivedNotice => 'इतिहास हटाए बिना ग्राहक संग्रहित किया गया।';

  @override
  String get auditCustomerCreated => 'ग्राहक बनाया गया';

  @override
  String get auditCustomerUpdated => 'ग्राहक विवरण अपडेट किया गया';

  @override
  String get auditCustomerArchived => 'ग्राहक संग्रहित किया गया';

  @override
  String get auditCustomerReactivated => 'ग्राहक पुनः सक्रिय किया गया';

  @override
  String get auditCustomerAssignmentTransferred => 'आवंटन स्थानांतरित किया गया';

  @override
  String get customerPaymentHistory => 'ग्राहक भुगतान इतिहास';

  @override
  String get paymentHistory => 'भुगतान इतिहास';

  @override
  String get myCollections => 'मेरी प्राप्तियां';

  @override
  String get customerPaymentHistorySubtitle => 'इस ग्राहक के लिए पुष्ट भुगतान, जिसमें रिवर्सल स्थिति और अपरिवर्तनीय आवंटन शामिल हैं।';

  @override
  String get headPaymentHistorySubtitle => 'पुष्ट भुगतान और रिवर्सल एक अपरिवर्तनीय वित्तीय रिकॉर्ड के रूप में सुरक्षित रखे जाते हैं।';

  @override
  String get employeeCollectionsSubtitle => 'ग्राहक को पुनः आवंटित करने के बाद भी आपकी अपनी अपरिवर्तनीय भुगतान रसीदें उपलब्ध रहती हैं।';

  @override
  String get collectFromCustomerRecordSubtitle => 'नकद, UPI, बैंक ट्रांसफर, या अन्य संग्रह की पुष्टि करने के लिए सक्रिय ग्राहक खोलें।';

  @override
  String get noConfirmedPayments => 'कोई पुष्ट भुगतान नहीं';

  @override
  String get noConfirmedPaymentsMessage => 'अधिकृत संग्रहकर्ता द्वारा प्राप्ति की पुष्टि के बाद ही भुगतान यहां दिखाई देता है।';

  @override
  String get paymentReversedBadge => 'रिवर्स किया गया';

  @override
  String reversalReasonPrefix(String reason) {
    return 'रिवर्सल का कारण: $reason';
  }

  @override
  String collectedByPrefix(String name, String method) {
    return '$name द्वारा प्राप्त • $method';
  }

  @override
  String get paymentReversalSuccess => 'अपरिवर्तनीय वित्तीय ऑडिट रिकॉर्ड के साथ भुगतान रिवर्स किया गया।';

  @override
  String get collectionUnavailable => 'संग्रह अनुपलब्ध';

  @override
  String get billingWorkspace => 'बिलिंग कार्यक्षेत्र';

  @override
  String get assignedBills => 'आवंटित बिल';

  @override
  String get billingWorkspaceSubtitle => 'अंतिम रूप देने से पहले दैनिक शुल्कों की समीक्षा करें। पूर्वावलोकन कभी डेटा नहीं लिखता।';

  @override
  String get assignedBillsSubtitle => 'आप केवल उन ग्राहकों के अंतिम बिल पढ़ सकते हैं जो वर्तमान में आपको आवंटित हैं।';

  @override
  String get noActiveCustomers => 'कोई सक्रिय ग्राहक नहीं';

  @override
  String get noActiveCustomersDesc => 'बिल करने के लिए कोई सुलभ सक्रिय ग्राहक नहीं है।';

  @override
  String get routeCoverage => 'मार्ग कवरेज';

  @override
  String get routeCoverageSubtitle => 'परिचालन क्षेत्र बनाएं और कर्मचारी कवरेज को आधिकारिक सदस्य रिकॉर्ड के साथ समन्वयित रखें।';

  @override
  String get newArea => 'नया क्षेत्र';

  @override
  String get editArea => 'क्षेत्र संपादित करें';

  @override
  String get areaName => 'क्षेत्र का नाम';

  @override
  String get areaDescription => 'विवरण (वैकल्पिक)';

  @override
  String get assignEmployees => 'कर्मचारी आवंटित करें';

  @override
  String get noAreasConfigured => 'कोई क्षेत्र कॉन्फ़िगर नहीं किया गया';

  @override
  String get noAreasConfiguredSubtitle => 'ग्राहक स्टॉप और रूट आवंटन व्यवस्थित करने के लिए वितरण क्षेत्र बनाएं।';

  @override
  String get publicationsSubtitle => 'समाचार पत्रों, पत्रिकाओं और मानक कार्यदिवस/सप्ताहांत मूल्य निर्धारण का प्रबंधन करें।';

  @override
  String get dailyPricingSubtitle => 'एकल-दिन या अवकाश के समाचार पत्र की कीमतें निर्धारित करें जो उस सुबह की सामान्य दरों को ओवरराइड करती हैं।';

  @override
  String get recordPrice => 'कीमत दर्ज करें';

  @override
  String get standardPrice => 'मानक मूल्य';

  @override
  String get teamSubtitle => 'एजेंसी कर्मचारियों, आमंत्रण कोड और परिचालन अनुमतियों का प्रबंधन करें।';

  @override
  String get manageEmployee => 'कर्मचारी प्रबंधित करें';

  @override
  String get employeeAccessUpdated => 'कर्मचारी पहुंच अपडेट की गई।';

  @override
  String get invitationCreated => 'आमंत्रण बनाया गया';

  @override
  String get invitationCodeCopied => 'आमंत्रण कोड कॉपी किया गया।';

  @override
  String get invitationRevoked => 'आमंत्रण रद्द किया गया।';

  @override
  String get copyCode => 'कोड कॉपी करें';

  @override
  String get createInvitation => 'आमंत्रण बनाएं';

  @override
  String get permissionsLabel => 'अनुमतियाँ';

  @override
  String get initialAreasLabel => 'प्रारंभिक क्षेत्र';

  @override
  String get activeAccess => 'सक्रिय पहुंच';

  @override
  String get businessReports => 'व्यावसायिक रिपोर्ट';

  @override
  String get reportsSubtitle => 'सर्वर-साइड कुल और पृष्ठबद्ध रिकॉर्ड चयनित फ़िल्टर का सम्मान करते हैं। CSV निर्यात समान क्वेरी स्कोप का उपयोग करते हैं।';

  @override
  String get exportFilteredCsv => 'फ़िल्टर किया हुआ CSV निर्यात करें';

  @override
  String get loadMoreResults => 'और परिणाम लोड करें';

  @override
  String get applyFilters => 'फ़िल्टर लागू करें';

  @override
  String get allEmployees => 'सभी कर्मचारी';

  @override
  String get allNewspapers => 'सभी समाचार पत्र';

  @override
  String get allMethods => 'सभी विधियाँ';

  @override
  String get allBalances => 'सभी शेष राशियाँ';

  @override
  String get allSubscriptions => 'सभी सदस्यताएँ';

  @override
  String get detailedCustomerMode => 'विस्तृत विवरण मोड';

  @override
  String get saveCustomer => 'ग्राहक सहेजें';

  @override
  String get bulkImportCustomers => 'थोक ग्राहक आयात (CSV)';

  @override
  String get masterCatalogTitle => 'भारतीय प्रकाशन सूची';

  @override
  String get browseMasterCatalog => 'भारतीय मास्टर सूची ब्राउज़ करें';

  @override
  String get magazinesTab => 'पत्रिकाएँ';

  @override
  String get newspapersTab => 'अखबार';

  @override
  String get frequencyDaily => 'दैनिक';

  @override
  String get frequencyWeekly => 'साप्ताहिक';

  @override
  String get frequencyFortnightly => 'पाक्षिक';

  @override
  String get frequencyMonthly => 'मासिक';
}
