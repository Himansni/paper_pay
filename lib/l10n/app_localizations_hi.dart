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
}
