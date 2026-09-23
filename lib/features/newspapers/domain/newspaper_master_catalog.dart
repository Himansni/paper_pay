import 'package:paper_route/features/business/domain/business_profile.dart';

enum PublicationType {
  newspaper('newspaper', 'Newspaper'),
  magazine('magazine', 'Magazine');

  const PublicationType(this.value, this.label);

  final String value;
  final String label;

  static PublicationType fromValue(Object? value) =>
      value == magazine.value ? magazine : newspaper;
}

enum PublicationFrequency {
  daily('daily', 'Daily'),
  weekly('weekly', 'Weekly'),
  fortnightly('fortnightly', 'Fortnightly'),
  monthly('monthly', 'Monthly'),
  biMonthly('biMonthly', 'Bi-Monthly'),
  quarterly('quarterly', 'Quarterly'),
  custom('custom', 'Custom');

  const PublicationFrequency(this.value, this.label);

  final String value;
  final String label;

  static PublicationFrequency fromValue(Object? value) =>
      values.firstWhere((f) => f.value == value, orElse: () => daily);
}

class MasterNewspaperEntry {
  const MasterNewspaperEntry({
    required this.id,
    required this.state,
    required this.districtCity,
    required this.name,
    this.hindiName = '',
    required this.edition,
    required this.language,
    this.aliases = const [],
    this.type = PublicationType.newspaper,
    this.frequency = PublicationFrequency.daily,
    this.defaultPricePaise = 500,
  });

  final String id;
  final String state;
  final String districtCity;
  final String name;
  final String hindiName;
  final String edition;
  final String language;
  final List<String> aliases;
  final PublicationType type;
  final PublicationFrequency frequency;
  final int defaultPricePaise;

  String get displayNameWithHindi =>
      hindiName.isNotEmpty ? '$name ($hindiName)' : name;

  bool matchesQuery(String query) {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) return true;

    if (name.toLowerCase().contains(clean)) return true;
    if (hindiName.toLowerCase().contains(clean)) return true;
    if (edition.toLowerCase().contains(clean)) return true;
    if (language.toLowerCase().contains(clean)) return true;
    if (state.toLowerCase().contains(clean)) return true;
    if (districtCity.toLowerCase().contains(clean)) return true;

    for (final alias in aliases) {
      if (alias.toLowerCase().contains(clean)) return true;
    }
    return false;
  }
}

/// Interface for master catalogue lookup.
abstract interface class NewspaperMasterCatalog {
  Future<List<MasterNewspaperEntry>> suggestionsFor(PricingRegion region);
  Future<List<MasterNewspaperEntry>> search({
    String query = '',
    String? state,
    String? language,
    PublicationType? type,
  });
}

/// Bundled comprehensive offline Indian publication catalogue.
class LocalNewspaperMasterCatalog implements NewspaperMasterCatalog {
  const LocalNewspaperMasterCatalog();

  static const List<MasterNewspaperEntry> bundledEntries = [
    // --- National & Multi-State English Daily Newspapers ---
    MasterNewspaperEntry(
      id: 'toi-delhi',
      state: 'Delhi',
      districtCity: 'Delhi',
      name: 'The Times of India',
      hindiName: 'द टाइम्स ऑफ इंडिया',
      edition: 'Delhi',
      language: 'English',
      aliases: ['TOI', 'Times', 'टाइम्स', 'टाइम्स ऑफ इंडिया'],
      defaultPricePaise: 500,
    ),
    MasterNewspaperEntry(
      id: 'toi-mumbai',
      state: 'Maharashtra',
      districtCity: 'Mumbai',
      name: 'The Times of India',
      hindiName: 'द टाइम्स ऑफ इंडिया',
      edition: 'Mumbai',
      language: 'English',
      aliases: ['TOI', 'Times', 'टाइम्स', 'टाइम्स ऑफ इंडिया'],
      defaultPricePaise: 500,
    ),
    MasterNewspaperEntry(
      id: 'ht-delhi',
      state: 'Delhi',
      districtCity: 'Delhi',
      name: 'Hindustan Times',
      hindiName: 'हिंदुस्तान टाइम्स',
      edition: 'Delhi',
      language: 'English',
      aliases: ['HT', 'एचटी', 'हिंदुस्तान टाइम्स'],
      defaultPricePaise: 500,
    ),
    MasterNewspaperEntry(
      id: 'the-hindu-delhi',
      state: 'Delhi',
      districtCity: 'Delhi',
      name: 'The Hindu',
      hindiName: 'द हिन्दू',
      edition: 'Delhi',
      language: 'English',
      aliases: ['Hindu', 'हिन्दू'],
      defaultPricePaise: 800,
    ),
    MasterNewspaperEntry(
      id: 'the-hindu-chennai',
      state: 'Tamil Nadu',
      districtCity: 'Chennai',
      name: 'The Hindu',
      hindiName: 'द हिन्दू',
      edition: 'Chennai',
      language: 'English',
      aliases: ['Hindu', 'हिन्दू'],
      defaultPricePaise: 700,
    ),
    MasterNewspaperEntry(
      id: 'ie-delhi',
      state: 'Delhi',
      districtCity: 'Delhi',
      name: 'The Indian Express',
      hindiName: 'द इंडियन एक्सप्रेस',
      edition: 'Delhi',
      language: 'English',
      aliases: ['IE', 'Express', 'इंडियन एक्सप्रेस'],
      defaultPricePaise: 600,
    ),
    MasterNewspaperEntry(
      id: 'et-delhi',
      state: 'Delhi',
      districtCity: 'Delhi',
      name: 'The Economic Times',
      hindiName: 'द इकोनॉमिक टाइम्स',
      edition: 'Delhi',
      language: 'English',
      aliases: ['ET', 'Economic Times', 'इकोनॉमिक टाइम्स'],
      defaultPricePaise: 500,
    ),
    MasterNewspaperEntry(
      id: 'telegraph-kolkata',
      state: 'West Bengal',
      districtCity: 'Kolkata',
      name: 'The Telegraph',
      hindiName: 'द टेलीग्राफ',
      edition: 'Kolkata',
      language: 'English',
      aliases: ['Telegraph', 'टेलीग्राफ'],
      defaultPricePaise: 500,
    ),
    MasterNewspaperEntry(
      id: 'deccan-chronicle-hyd',
      state: 'Telangana',
      districtCity: 'Hyderabad',
      name: 'Deccan Chronicle',
      hindiName: 'डेक्कन क्रॉनिकल',
      edition: 'Hyderabad',
      language: 'English',
      aliases: ['DC', 'Deccan'],
      defaultPricePaise: 500,
    ),
    MasterNewspaperEntry(
      id: 'deccan-herald-blr',
      state: 'Karnataka',
      districtCity: 'Bengaluru',
      name: 'Deccan Herald',
      hindiName: 'डेक्कन हेराल्ड',
      edition: 'Bengaluru',
      language: 'English',
      aliases: ['DH', 'Herald'],
      defaultPricePaise: 500,
    ),
    MasterNewspaperEntry(
      id: 'mint-delhi',
      state: 'Delhi',
      districtCity: 'Delhi',
      name: 'Mint',
      hindiName: 'मिंट',
      edition: 'Delhi',
      language: 'English',
      aliases: ['Livemint', 'Mint', 'मिंट'],
      defaultPricePaise: 600,
    ),
    MasterNewspaperEntry(
      id: 'business-standard-delhi',
      state: 'Delhi',
      districtCity: 'Delhi',
      name: 'Business Standard',
      hindiName: 'बिजनेस स्टैंडर्ड',
      edition: 'Delhi',
      language: 'English',
      aliases: ['BS', 'बिजनेस स्टैंडर्ड'],
      defaultPricePaise: 500,
    ),

    // --- Hindi Daily Newspapers ---
    MasterNewspaperEntry(
      id: 'jagran-delhi',
      state: 'Delhi',
      districtCity: 'Delhi',
      name: 'Dainik Jagran',
      hindiName: 'दैनिक जागरण',
      edition: 'Delhi',
      language: 'Hindi',
      aliases: ['Jagran', 'जागरण', 'दैनिक जागरण'],
      defaultPricePaise: 500,
    ),
    MasterNewspaperEntry(
      id: 'jagran-up',
      state: 'Uttar Pradesh',
      districtCity: 'Kanpur',
      name: 'Dainik Jagran',
      hindiName: 'दैनिक जागरण',
      edition: 'Kanpur',
      language: 'Hindi',
      aliases: ['Jagran', 'जागरण', 'दैनिक जागरण'],
      defaultPricePaise: 500,
    ),
    MasterNewspaperEntry(
      id: 'bhaskar-mp',
      state: 'Madhya Pradesh',
      districtCity: 'Bhopal',
      name: 'Dainik Bhaskar',
      hindiName: 'दैनिक भास्कर',
      edition: 'Bhopal',
      language: 'Hindi',
      aliases: ['Bhaskar', 'भास्कर', 'दैनिक भास्कर'],
      defaultPricePaise: 500,
    ),
    MasterNewspaperEntry(
      id: 'bhaskar-rajasthan',
      state: 'Rajasthan',
      districtCity: 'Jaipur',
      name: 'Dainik Bhaskar',
      hindiName: 'दैनिक भास्कर',
      edition: 'Jaipur',
      language: 'Hindi',
      aliases: ['Bhaskar', 'भास्कर', 'दैनिक भास्कर'],
      defaultPricePaise: 500,
    ),
    MasterNewspaperEntry(
      id: 'amar-ujala-up',
      state: 'Uttar Pradesh',
      districtCity: 'Lucknow',
      name: 'Amar Ujala',
      hindiName: 'अमर उजाला',
      edition: 'Lucknow',
      language: 'Hindi',
      aliases: ['Ujala', 'अमर उजाला', 'उजाला'],
      defaultPricePaise: 500,
    ),
    MasterNewspaperEntry(
      id: 'amar-ujala-delhi',
      state: 'Delhi',
      districtCity: 'Delhi',
      name: 'Amar Ujala',
      hindiName: 'अमर उजाला',
      edition: 'Delhi',
      language: 'Hindi',
      aliases: ['Ujala', 'अमर उजाला'],
      defaultPricePaise: 500,
    ),
    MasterNewspaperEntry(
      id: 'hindustan-delhi',
      state: 'Delhi',
      districtCity: 'Delhi',
      name: 'Hindustan Dainik',
      hindiName: 'हिन्दुस्तान',
      edition: 'Delhi',
      language: 'Hindi',
      aliases: ['Hindustan', 'हिन्दुस्तान', 'दैनिक हिन्दुस्तान'],
      defaultPricePaise: 500,
    ),
    MasterNewspaperEntry(
      id: 'hindustan-bihar',
      state: 'Bihar',
      districtCity: 'Patna',
      name: 'Hindustan Dainik',
      hindiName: 'हिन्दुस्तान',
      edition: 'Patna',
      language: 'Hindi',
      aliases: ['Hindustan', 'हिन्दुस्तान', 'दैनिक हिन्दुस्तान'],
      defaultPricePaise: 500,
    ),
    MasterNewspaperEntry(
      id: 'patrika-rajasthan',
      state: 'Rajasthan',
      districtCity: 'Jaipur',
      name: 'Rajasthan Patrika',
      hindiName: 'राजस्थान पत्रिका',
      edition: 'Jaipur',
      language: 'Hindi',
      aliases: ['Patrika', 'पत्रिका', 'राजस्थान पत्रिका'],
      defaultPricePaise: 500,
    ),
    MasterNewspaperEntry(
      id: 'prabhat-khabar-jharkhand',
      state: 'Jharkhand',
      districtCity: 'Ranchi',
      name: 'Prabhat Khabar',
      hindiName: 'प्रभात खबर',
      edition: 'Ranchi',
      language: 'Hindi',
      aliases: ['Prabhat', 'प्रभात खबर'],
      defaultPricePaise: 500,
    ),
    MasterNewspaperEntry(
      id: 'nbt-delhi',
      state: 'Delhi',
      districtCity: 'Delhi',
      name: 'Navbharat Times',
      hindiName: 'नवभारत टाइम्स',
      edition: 'Delhi',
      language: 'Hindi',
      aliases: ['NBT', 'Navbharat', 'नवभारत', 'नवभारत टाइम्स'],
      defaultPricePaise: 400,
    ),
    MasterNewspaperEntry(
      id: 'nbt-mumbai',
      state: 'Maharashtra',
      districtCity: 'Mumbai',
      name: 'Navbharat Times',
      hindiName: 'नवभारत टाइम्स',
      edition: 'Mumbai',
      language: 'Hindi',
      aliases: ['NBT', 'Navbharat', 'नवभारत', 'नवभारत टाइम्स'],
      defaultPricePaise: 400,
    ),
    MasterNewspaperEntry(
      id: 'punjab-kesari-delhi',
      state: 'Delhi',
      districtCity: 'Delhi',
      name: 'Punjab Kesari',
      hindiName: 'पंजाब केसरी',
      edition: 'Delhi',
      language: 'Hindi',
      aliases: ['Kesari', 'पंजाब केसरी', 'केसरी'],
      defaultPricePaise: 400,
    ),
    MasterNewspaperEntry(
      id: 'jansatta-delhi',
      state: 'Delhi',
      districtCity: 'Delhi',
      name: 'Jansatta',
      hindiName: 'जनसत्ता',
      edition: 'Delhi',
      language: 'Hindi',
      aliases: ['Jansatta', 'जनसत्ता'],
      defaultPricePaise: 500,
    ),
    MasterNewspaperEntry(
      id: 'haribhoomi-haryana',
      state: 'Haryana',
      districtCity: 'Rohtak',
      name: 'Hari Bhoomi',
      hindiName: 'हरिभूमि',
      edition: 'Rohtak',
      language: 'Hindi',
      aliases: ['Hari Bhoomi', 'हरिभूमि'],
      defaultPricePaise: 400,
    ),

    // --- Regional Language Daily Newspapers ---
    MasterNewspaperEntry(
      id: 'lokmat-mumbai',
      state: 'Maharashtra',
      districtCity: 'Mumbai',
      name: 'Lokmat',
      hindiName: 'लोकमत',
      edition: 'Mumbai',
      language: 'Marathi',
      aliases: ['Lokmat', 'लोकमत'],
      defaultPricePaise: 500,
    ),
    MasterNewspaperEntry(
      id: 'sakal-pune',
      state: 'Maharashtra',
      districtCity: 'Pune',
      name: 'Sakal',
      hindiName: 'सकाळ',
      edition: 'Pune',
      language: 'Marathi',
      aliases: ['Sakal', 'सकाळ'],
      defaultPricePaise: 500,
    ),
    MasterNewspaperEntry(
      id: 'loksatta-mumbai',
      state: 'Maharashtra',
      districtCity: 'Mumbai',
      name: 'Loksatta',
      hindiName: 'लोकसत्ता',
      edition: 'Mumbai',
      language: 'Marathi',
      aliases: ['Loksatta', 'लोकसत्ता'],
      defaultPricePaise: 500,
    ),
    MasterNewspaperEntry(
      id: 'maharashtra-times-mumbai',
      state: 'Maharashtra',
      districtCity: 'Mumbai',
      name: 'Maharashtra Times',
      hindiName: 'महाराष्ट्र टाइम्स',
      edition: 'Mumbai',
      language: 'Marathi',
      aliases: ['MT', 'Mahatimes', 'महाराष्ट्र टाइम्स'],
      defaultPricePaise: 500,
    ),
    MasterNewspaperEntry(
      id: 'pudhari-kolhapur',
      state: 'Maharashtra',
      districtCity: 'Kolhapur',
      name: 'Pudhari',
      hindiName: 'पुढारी',
      edition: 'Kolhapur',
      language: 'Marathi',
      aliases: ['Pudhari', 'पुढारी'],
      defaultPricePaise: 400,
    ),
    MasterNewspaperEntry(
      id: 'anandabazar-kolkata',
      state: 'West Bengal',
      districtCity: 'Kolkata',
      name: 'Anandabazar Patrika',
      hindiName: 'आनंदबाजार पत्रिका',
      edition: 'Kolkata',
      language: 'Bengali',
      aliases: ['ABP', 'Anandabazar', 'আনন্দবাজার'],
      defaultPricePaise: 500,
    ),
    MasterNewspaperEntry(
      id: 'bartaman-kolkata',
      state: 'West Bengal',
      districtCity: 'Kolkata',
      name: 'Bartaman',
      hindiName: 'वर्तमान',
      edition: 'Kolkata',
      language: 'Bengali',
      aliases: ['Bartaman', 'বর্তমান'],
      defaultPricePaise: 400,
    ),
    MasterNewspaperEntry(
      id: 'eenadu-hyderabad',
      state: 'Telangana',
      districtCity: 'Hyderabad',
      name: 'Eenadu',
      hindiName: 'ईनाडु',
      edition: 'Hyderabad',
      language: 'Telugu',
      aliases: ['Eenadu', 'ईनाडु', 'ఈనాడు'],
      defaultPricePaise: 500,
    ),
    MasterNewspaperEntry(
      id: 'sakshi-hyderabad',
      state: 'Telangana',
      districtCity: 'Hyderabad',
      name: 'Sakshi',
      hindiName: 'साक्षी',
      edition: 'Hyderabad',
      language: 'Telugu',
      aliases: ['Sakshi', 'साक्षी', 'సాక్షి'],
      defaultPricePaise: 500,
    ),
    MasterNewspaperEntry(
      id: 'andhra-jyothi-vijayawada',
      state: 'Andhra Pradesh',
      districtCity: 'Vijayawada',
      name: 'Andhra Jyothi',
      hindiName: 'आंध्र ज्योति',
      edition: 'Vijayawada',
      language: 'Telugu',
      aliases: ['AJ', 'Andhra Jyothi', 'ఆంధ్రజ్యోతి'],
      defaultPricePaise: 500,
    ),
    MasterNewspaperEntry(
      id: 'daily-thanthi-chennai',
      state: 'Tamil Nadu',
      districtCity: 'Chennai',
      name: 'Daily Thanthi',
      hindiName: 'डेली थांती',
      edition: 'Chennai',
      language: 'Tamil',
      aliases: ['Thanthi', 'தினத்தந்தி'],
      defaultPricePaise: 500,
    ),
    MasterNewspaperEntry(
      id: 'dinamalar-chennai',
      state: 'Tamil Nadu',
      districtCity: 'Chennai',
      name: 'Dinamalar',
      hindiName: 'दिनमलर',
      edition: 'Chennai',
      language: 'Tamil',
      aliases: ['Dinamalar', 'தினமலர்'],
      defaultPricePaise: 500,
    ),
    MasterNewspaperEntry(
      id: 'dinakaran-chennai',
      state: 'Tamil Nadu',
      districtCity: 'Chennai',
      name: 'Dinakaran',
      hindiName: 'दिनकरन',
      edition: 'Chennai',
      language: 'Tamil',
      aliases: ['Dinakaran', 'தினகரன்'],
      defaultPricePaise: 500,
    ),
    MasterNewspaperEntry(
      id: 'gujarat-samachar-ahmedabad',
      state: 'Gujarat',
      districtCity: 'Ahmedabad',
      name: 'Gujarat Samachar',
      hindiName: 'गुजरात समाचार',
      edition: 'Ahmedabad',
      language: 'Gujarati',
      aliases: ['Gujarat Samachar', 'ગુજરાત સમાચાર'],
      defaultPricePaise: 500,
    ),
    MasterNewspaperEntry(
      id: 'sandesh-ahmedabad',
      state: 'Gujarat',
      districtCity: 'Ahmedabad',
      name: 'Sandesh',
      hindiName: 'संदेश',
      edition: 'Ahmedabad',
      language: 'Gujarati',
      aliases: ['Sandesh', 'સંદેશ'],
      defaultPricePaise: 500,
    ),
    MasterNewspaperEntry(
      id: 'divya-bhaskar-ahmedabad',
      state: 'Gujarat',
      districtCity: 'Ahmedabad',
      name: 'Divya Bhaskar',
      hindiName: 'दिव्य भास्कर',
      edition: 'Ahmedabad',
      language: 'Gujarati',
      aliases: ['Divya Bhaskar', 'દિવ્ય ભાસ્કર'],
      defaultPricePaise: 500,
    ),
    MasterNewspaperEntry(
      id: 'manorama-kochi',
      state: 'Kerala',
      districtCity: 'Kochi',
      name: 'Malayala Manorama',
      hindiName: 'मलयाला मनोरमा',
      edition: 'Kochi',
      language: 'Malayalam',
      aliases: ['Manorama', 'मनोरमा', 'മലയാള മനോരമ'],
      defaultPricePaise: 600,
    ),
    MasterNewspaperEntry(
      id: 'mathrubhumi-kozhikode',
      state: 'Kerala',
      districtCity: 'Kozhikode',
      name: 'Mathrubhumi',
      hindiName: 'मातृभूमि',
      edition: 'Kozhikode',
      language: 'Malayalam',
      aliases: ['Mathrubhumi', 'മാതൃഭൂമി'],
      defaultPricePaise: 600,
    ),
    MasterNewspaperEntry(
      id: 'prajavani-bengaluru',
      state: 'Karnataka',
      districtCity: 'Bengaluru',
      name: 'Prajavani',
      hindiName: 'प्रजावाणी',
      edition: 'Bengaluru',
      language: 'Kannada',
      aliases: ['Prajavani', 'ಪ್ರಜಾವಾಣಿ'],
      defaultPricePaise: 500,
    ),
    MasterNewspaperEntry(
      id: 'vijayavani-bengaluru',
      state: 'Karnataka',
      districtCity: 'Bengaluru',
      name: 'Vijayavani',
      hindiName: 'विजयवाणी',
      edition: 'Bengaluru',
      language: 'Kannada',
      aliases: ['Vijayavani', 'ವಿಜಯವಾಣಿ'],
      defaultPricePaise: 500,
    ),
    MasterNewspaperEntry(
      id: 'kannada-prabha-bengaluru',
      state: 'Karnataka',
      districtCity: 'Bengaluru',
      name: 'Kannada Prabha',
      hindiName: 'कन्नड़ प्रभा',
      edition: 'Bengaluru',
      language: 'Kannada',
      aliases: ['Kannada Prabha', 'ಕನ್ನಡ ಪ್ರಭ'],
      defaultPricePaise: 500,
    ),
    MasterNewspaperEntry(
      id: 'ajit-jalandhar',
      state: 'Punjab',
      districtCity: 'Jalandhar',
      name: 'Daily Ajit',
      hindiName: 'अजीत',
      edition: 'Jalandhar',
      language: 'Punjabi',
      aliases: ['Ajit', 'ਅਜੀਤ'],
      defaultPricePaise: 500,
    ),
    MasterNewspaperEntry(
      id: 'jag-bani-jalandhar',
      state: 'Punjab',
      districtCity: 'Jalandhar',
      name: 'Jag Bani',
      hindiName: 'जग बाणी',
      edition: 'Jalandhar',
      language: 'Punjabi',
      aliases: ['Jag Bani', 'ਜਗ ਬਾਣੀ'],
      defaultPricePaise: 500,
    ),
    MasterNewspaperEntry(
      id: 'sambad-bhubaneswar',
      state: 'Odisha',
      districtCity: 'Bhubaneswar',
      name: 'Sambad',
      hindiName: 'सम्बाद',
      edition: 'Bhubaneswar',
      language: 'Odia',
      aliases: ['Sambad', 'ସମ୍ବାଦ'],
      defaultPricePaise: 500,
    ),
    MasterNewspaperEntry(
      id: 'samaja-cuttack',
      state: 'Odisha',
      districtCity: 'Cuttack',
      name: 'Samaja',
      hindiName: 'समाज',
      edition: 'Cuttack',
      language: 'Odia',
      aliases: ['Samaja', 'ସମାଜ'],
      defaultPricePaise: 500,
    ),

    // --- Popular Indian Magazines (Weekly / Fortnightly / Monthly) ---
    MasterNewspaperEntry(
      id: 'mag-india-today-en',
      state: 'National',
      districtCity: 'All',
      name: 'India Today',
      hindiName: 'इंडिया टुडे (अंग्रेजी)',
      edition: 'National',
      language: 'English',
      aliases: ['IT', 'India Today', 'इंडिया टुडे'],
      type: PublicationType.magazine,
      frequency: PublicationFrequency.weekly,
      defaultPricePaise: 7500,
    ),
    MasterNewspaperEntry(
      id: 'mag-india-today-hi',
      state: 'National',
      districtCity: 'All',
      name: 'India Today Hindi',
      hindiName: 'इंडिया टुडे (हिन्दी)',
      edition: 'National',
      language: 'Hindi',
      aliases: ['IT Hindi', 'इंडिया टुडे'],
      type: PublicationType.magazine,
      frequency: PublicationFrequency.weekly,
      defaultPricePaise: 5000,
    ),
    MasterNewspaperEntry(
      id: 'mag-pratiyogita-darpan',
      state: 'National',
      districtCity: 'All',
      name: 'Pratiyogita Darpan',
      hindiName: 'प्रतियोगिता दर्पण',
      edition: 'National',
      language: 'Hindi',
      aliases: ['PD', 'Darpan', 'दर्पण', 'प्रतियोगिता दर्पण'],
      type: PublicationType.magazine,
      frequency: PublicationFrequency.monthly,
      defaultPricePaise: 9500,
    ),
    MasterNewspaperEntry(
      id: 'mag-grihshobha-hi',
      state: 'National',
      districtCity: 'All',
      name: 'Grihshobha',
      hindiName: 'गृहशोभा',
      edition: 'National',
      language: 'Hindi',
      aliases: ['Grihshobha', 'गृहशोभा'],
      type: PublicationType.magazine,
      frequency: PublicationFrequency.fortnightly,
      defaultPricePaise: 4500,
    ),
    MasterNewspaperEntry(
      id: 'mag-sarita-hi',
      state: 'National',
      districtCity: 'All',
      name: 'Sarita',
      hindiName: 'सरिता',
      edition: 'National',
      language: 'Hindi',
      aliases: ['Sarita', 'सरिता'],
      type: PublicationType.magazine,
      frequency: PublicationFrequency.fortnightly,
      defaultPricePaise: 4500,
    ),
    MasterNewspaperEntry(
      id: 'mag-champak-hi',
      state: 'National',
      districtCity: 'All',
      name: 'Champak',
      hindiName: 'चंपक',
      edition: 'National',
      language: 'Hindi',
      aliases: ['Champak', 'चंपक'],
      type: PublicationType.magazine,
      frequency: PublicationFrequency.fortnightly,
      defaultPricePaise: 3500,
    ),
    MasterNewspaperEntry(
      id: 'mag-outlook-en',
      state: 'National',
      districtCity: 'All',
      name: 'Outlook',
      hindiName: 'आउटलुक',
      edition: 'National',
      language: 'English',
      aliases: ['Outlook', 'आउटलुक'],
      type: PublicationType.magazine,
      frequency: PublicationFrequency.weekly,
      defaultPricePaise: 6000,
    ),
    MasterNewspaperEntry(
      id: 'mag-frontline-en',
      state: 'National',
      districtCity: 'All',
      name: 'Frontline',
      hindiName: 'फ्रंटलाइन',
      edition: 'National',
      language: 'English',
      aliases: ['Frontline', 'फ्रंटलाइन'],
      type: PublicationType.magazine,
      frequency: PublicationFrequency.fortnightly,
      defaultPricePaise: 12500,
    ),
    MasterNewspaperEntry(
      id: 'mag-sportstar-en',
      state: 'National',
      districtCity: 'All',
      name: 'Sportstar',
      hindiName: 'स्पोर्टस्टार',
      edition: 'National',
      language: 'English',
      aliases: ['Sportstar', 'स्पोर्टस्टार'],
      type: PublicationType.magazine,
      frequency: PublicationFrequency.monthly,
      defaultPricePaise: 10000,
    ),
    MasterNewspaperEntry(
      id: 'mag-business-today-en',
      state: 'National',
      districtCity: 'All',
      name: 'Business Today',
      hindiName: 'बिजनेस टुडे',
      edition: 'National',
      language: 'English',
      aliases: ['BT', 'Business Today', 'बिजनेस टुडे'],
      type: PublicationType.magazine,
      frequency: PublicationFrequency.fortnightly,
      defaultPricePaise: 10000,
    ),
    MasterNewspaperEntry(
      id: 'mag-forbes-india-en',
      state: 'National',
      districtCity: 'All',
      name: 'Forbes India',
      hindiName: 'फ़ोर्ब्स इंडिया',
      edition: 'National',
      language: 'English',
      aliases: ['Forbes', 'फ़ोर्ब्स'],
      type: PublicationType.magazine,
      frequency: PublicationFrequency.fortnightly,
      defaultPricePaise: 15000,
    ),
    MasterNewspaperEntry(
      id: 'mag-yojana-hi',
      state: 'National',
      districtCity: 'All',
      name: 'Yojana (Hindi)',
      hindiName: 'योजना (हिन्दी)',
      edition: 'National',
      language: 'Hindi',
      aliases: ['Yojana', 'योजना'],
      type: PublicationType.magazine,
      frequency: PublicationFrequency.monthly,
      defaultPricePaise: 2200,
    ),
    MasterNewspaperEntry(
      id: 'mag-kurukshetra-hi',
      state: 'National',
      districtCity: 'All',
      name: 'Kurukshetra (Hindi)',
      hindiName: 'कुरुक्षेत्र (हिन्दी)',
      edition: 'National',
      language: 'Hindi',
      aliases: ['Kurukshetra', 'कुरुक्षेत्र'],
      type: PublicationType.magazine,
      frequency: PublicationFrequency.monthly,
      defaultPricePaise: 2200,
    ),
    MasterNewspaperEntry(
      id: 'mag-vanitha-ml',
      state: 'Kerala',
      districtCity: 'Kochi',
      name: 'Vanitha',
      hindiName: 'वनिता',
      edition: 'Kerala',
      language: 'Malayalam',
      aliases: ['Vanitha', 'വനിത'],
      type: PublicationType.magazine,
      frequency: PublicationFrequency.fortnightly,
      defaultPricePaise: 4000,
    ),
  ];

  @override
  Future<List<MasterNewspaperEntry>> suggestionsFor(
    PricingRegion region,
  ) async {
    final regionState = region.state.toLowerCase();
    return bundledEntries.where((entry) {
      if (entry.state == 'National') return true;
      return entry.state.toLowerCase().contains(regionState) ||
          regionState.contains(entry.state.toLowerCase());
    }).toList();
  }

  @override
  Future<List<MasterNewspaperEntry>> search({
    String query = '',
    String? state,
    String? language,
    PublicationType? type,
  }) async {
    return bundledEntries.where((entry) {
      if (type != null && entry.type != type) return false;
      if (state != null &&
          state.isNotEmpty &&
          entry.state != 'National' &&
          entry.state.toLowerCase() != state.toLowerCase()) {
        return false;
      }
      if (language != null &&
          language.isNotEmpty &&
          entry.language.toLowerCase() != language.toLowerCase()) {
        return false;
      }
      return entry.matchesQuery(query);
    }).toList();
  }
}
