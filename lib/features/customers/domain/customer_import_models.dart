import 'package:paper_route/features/customers/domain/customer.dart';

enum CustomerImportField {
  name('name', 'Customer Name / नाम'),
  phone('phone', 'Phone Number / मोबाइल'),
  alternatePhone('alternatePhone', 'Alternate Phone / दूसरा फोन'),
  areaName('areaName', 'Area Name / इलाका'),
  houseNumber('houseNumber', 'House / Flat No / मकान नं'),
  buildingInfo('buildingInfo', 'Building / Floor / मंजिल'),
  address('address', 'Full Address / पूरा पता'),
  landmark('landmark', 'Landmark / लैंडमार्क'),
  deliveryPlacement('deliveryPlacement', 'Delivery Placement / डिलीवरी स्थान'),
  openingBalance('openingBalance', 'Opening Balance (₹) / बैलेंस'),
  notes('notes', 'Notes / टिप्पणी'),
  newspaperName('newspaperName', 'Newspaper / Publication / अखबार');

  const CustomerImportField(this.key, this.label);

  final String key;
  final String label;
}

class CustomerImportRow {
  const CustomerImportRow({
    required this.rowIndex,
    required this.rawData,
    required this.name,
    required this.phone,
    this.alternatePhone = '',
    this.areaName = '',
    this.houseNumber = '',
    this.buildingInfo = '',
    this.address = '',
    this.landmark = '',
    this.deliveryPlacement = DeliveryPlacement.doorstep,
    this.openingBalancePaise = 0,
    this.notes = '',
    this.newspaperName = '',
    this.errors = const [],
    this.isDuplicateInFile = false,
    this.isDuplicateInDb = false,
  });

  final int rowIndex;
  final Map<String, String> rawData;
  final String name;
  final String phone;
  final String alternatePhone;
  final String areaName;
  final String houseNumber;
  final String buildingInfo;
  final String address;
  final String landmark;
  final DeliveryPlacement deliveryPlacement;
  final int openingBalancePaise;
  final String notes;
  final String newspaperName;
  final List<String> errors;
  final bool isDuplicateInFile;
  final bool isDuplicateInDb;

  bool get isValid =>
      errors.isEmpty && !isDuplicateInFile && !isDuplicateInDb;

  CustomerImportRow copyWith({
    List<String>? errors,
    bool? isDuplicateInFile,
    bool? isDuplicateInDb,
  }) => CustomerImportRow(
    rowIndex: rowIndex,
    rawData: rawData,
    name: name,
    phone: phone,
    alternatePhone: alternatePhone,
    areaName: areaName,
    houseNumber: houseNumber,
    buildingInfo: buildingInfo,
    address: address,
    landmark: landmark,
    deliveryPlacement: deliveryPlacement,
    openingBalancePaise: openingBalancePaise,
    notes: notes,
    newspaperName: newspaperName,
    errors: errors ?? this.errors,
    isDuplicateInFile: isDuplicateInFile ?? this.isDuplicateInFile,
    isDuplicateInDb: isDuplicateInDb ?? this.isDuplicateInDb,
  );
}

class CustomerImportValidationResult {
  const CustomerImportValidationResult({
    required this.totalRows,
    required this.validRows,
    required this.duplicateRows,
    required this.invalidRows,
    required this.rows,
  });

  final int totalRows;
  final int validRows;
  final int duplicateRows;
  final int invalidRows;
  final List<CustomerImportRow> rows;

  bool get canImport => validRows > 0;
}

class CustomerImportProgress {
  const CustomerImportProgress({
    required this.total,
    required this.processed,
    required this.successful,
    required this.failed,
    this.isComplete = false,
    this.errorMessage,
  });

  final int total;
  final int processed;
  final int successful;
  final int failed;
  final bool isComplete;
  final String? errorMessage;

  double get fraction => total == 0 ? 1.0 : processed / total;
}
