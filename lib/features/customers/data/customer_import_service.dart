import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:paper_route/core/domain/local_date.dart';
import 'package:paper_route/features/areas/domain/delivery_area.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/customers/domain/customer.dart';
import 'package:paper_route/features/customers/domain/customer_import_models.dart';
import 'package:paper_route/features/newspapers/domain/newspaper.dart';
import 'package:uuid/uuid.dart';

class CustomerImportService {
  CustomerImportService({FirebaseFirestore? firestore, Uuid? uuid})
    : _customFirestore = firestore,
      _uuid = uuid ?? const Uuid();

  final FirebaseFirestore? _customFirestore;
  final Uuid _uuid;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  /// Robust RFC-4180 compliant CSV parser with quote, delimiter, newline, and BOM handling.
  static List<List<String>> parseCsv(String rawContent) {
    var content = rawContent;
    if (content.startsWith('\uFEFF')) {
      content = content.substring(1);
    }

    final rows = <List<String>>[];
    final currentField = StringBuffer();
    final currentRow = <String>[];
    var inQuotes = false;
    var i = 0;

    while (i < content.length) {
      final char = content[i];

      if (inQuotes) {
        if (char == '"') {
          if (i + 1 < content.length && content[i + 1] == '"') {
            currentField.write('"');
            i += 2;
            continue;
          } else {
            inQuotes = false;
            i++;
            continue;
          }
        } else {
          currentField.write(char);
          i++;
          continue;
        }
      } else {
        if (char == '"') {
          inQuotes = true;
          i++;
          continue;
        } else if (char == ',' || char == '\t') {
          currentRow.add(currentField.toString().trim());
          currentField.clear();
          i++;
          continue;
        } else if (char == '\r') {
          if (i + 1 < content.length && content[i + 1] == '\n') {
            i++;
          }
          currentRow.add(currentField.toString().trim());
          currentField.clear();
          if (currentRow.any((f) => f.isNotEmpty)) {
            rows.add(List.of(currentRow));
          }
          currentRow.clear();
          i++;
          continue;
        } else if (char == '\n') {
          currentRow.add(currentField.toString().trim());
          currentField.clear();
          if (currentRow.any((f) => f.isNotEmpty)) {
            rows.add(List.of(currentRow));
          }
          currentRow.clear();
          i++;
          continue;
        } else {
          currentField.write(char);
          i++;
          continue;
        }
      }
    }

    currentRow.add(currentField.toString().trim());
    if (currentRow.any((f) => f.isNotEmpty)) {
      rows.add(currentRow);
    }

    return rows;
  }

  /// Parses Excel (.xlsx) file bytes into a 2D string grid.
  static List<List<String>> parseExcelBytes(List<int> bytes) {
    final excel = Excel.decodeBytes(bytes);
    final rows = <List<String>>[];
    for (final table in excel.tables.keys) {
      final sheet = excel.tables[table];
      if (sheet == null || sheet.rows.isEmpty) continue;
      for (final row in sheet.rows) {
        final stringRow =
            row.map((cell) {
              if (cell == null || cell.value == null) return '';
              return cell.value.toString().trim();
            }).toList();
        if (stringRow.any((cell) => cell.isNotEmpty)) {
          rows.add(stringRow);
        }
      }
      if (rows.isNotEmpty) break;
    }
    return rows;
  }

  /// Parses either CSV or XLSX bytes dynamically based on header magic bytes or filename.
  static List<List<String>> parseBytes(List<int> bytes, {String? fileName}) {
    final lowerName = fileName?.toLowerCase() ?? '';
    final isZip = bytes.length >= 4 && bytes[0] == 0x50 && bytes[1] == 0x4B;
    if (lowerName.endsWith('.xlsx') || isZip) {
      return parseExcelBytes(bytes);
    }
    return parseCsv(utf8.decode(bytes, allowMalformed: true));
  }

  /// Maps raw CSV/Excel rows to [CustomerImportRow] instances and validates them.
  Future<CustomerImportValidationResult> validateRows({
    required List<List<String>> csvTable,
    required List<DeliveryArea> availableAreas,
    required List<Newspaper> availableNewspapers,
    required String businessId,
    required bool isHead,
    Set<String>? preloadedExistingPhones,
  }) async {
    if (csvTable.isEmpty) {
      return const CustomerImportValidationResult(
        totalRows: 0,
        validRows: 0,
        duplicateRows: 0,
        invalidRows: 0,
        rows: [],
      );
    }

    final headers = csvTable.first.map((h) => h.trim().toLowerCase()).toList();
    final dataRows = csvTable.skip(1).toList();

    // Map column indices
    int findIndex(List<String> synonyms) {
      for (var i = 0; i < headers.length; i++) {
        final h = headers[i];
        if (synonyms.any((s) => h == s || h.contains(s))) {
          return i;
        }
      }
      return -1;
    }

    final nameIdx = findIndex(['customer name', 'name', 'ग्राहक', 'नाम']);
    final phoneIdx = findIndex([
      'mobile',
      'phone',
      'contact',
      'फ़ोन',
      'मोबाइल',
      'फोन',
    ]);
    final altPhoneIdx = findIndex([
      'alt phone',
      'alternate',
      'secondary',
      'दूसरा फोन',
    ]);
    final areaIdx = findIndex(['area', 'route', 'इलाका', 'क्षेत्र']);
    final houseIdx = findIndex([
      'house',
      'flat',
      'flat no',
      'house no',
      'मकान',
      'फ्लैट',
    ]);
    final buildingIdx = findIndex([
      'building',
      'floor',
      'tower',
      'सोसायटी',
      'मंजिल',
    ]);
    final addressIdx = findIndex(['address', 'full address', 'पता', 'पूरा पता']);
    final landmarkIdx = findIndex(['landmark', 'लैंडमार्क']);
    final placementIdx = findIndex([
      'placement',
      'delivery placement',
      'डिलीवरी स्थान',
    ]);
    final balanceIdx = findIndex([
      'opening balance',
      'balance',
      'बैलेंस',
      'बकाया',
    ]);
    final notesIdx = findIndex(['notes', 'remark', 'टिप्पणी']);
    final pubIdx = findIndex([
      'newspaper',
      'publication',
      'paper',
      'अखबार',
      'पत्रिका',
    ]);

    // Load existing phone numbers from DB if not provided
    final existingPhones =
        preloadedExistingPhones ?? await _loadExistingPhones(businessId);
    final seenPhonesInFile = <String, int>{};
    final parsedRows = <CustomerImportRow>[];

    for (var r = 0; r < dataRows.length; r++) {
      final rawRow = dataRows[r];
      if (rawRow.isEmpty || rawRow.every((c) => c.trim().isEmpty)) continue;

      String getField(int idx) =>
          idx >= 0 && idx < rawRow.length ? rawRow[idx].trim() : '';

      final name =
          nameIdx >= 0
              ? getField(nameIdx)
              : (rawRow.isNotEmpty ? rawRow[0] : '');
      final phone =
          phoneIdx >= 0
              ? getField(phoneIdx)
              : (rawRow.length > 1 ? rawRow[1] : '');
      final altPhone = getField(altPhoneIdx);
      final rawArea = getField(areaIdx);
      final house = getField(houseIdx);
      final building = getField(buildingIdx);
      var address = getField(addressIdx);
      var landmark = getField(landmarkIdx);
      final placementStr = getField(placementIdx);
      final balanceStr = getField(balanceIdx);
      final notes = getField(notesIdx);
      final newspaper = getField(pubIdx);

      final rowErrors = <String>[];

      // Name validation
      if (name.length < 2) {
        rowErrors.add('Name must be at least 2 characters.');
      }

      // Phone validation & normalization (optional)
      final cleanPhone = CustomerSearchIndex.normalizePhone(phone);
      if (phone.isNotEmpty &&
          (cleanPhone.length < 7 || cleanPhone.length > 15)) {
        rowErrors.add('Primary phone must be a valid number (7-15 digits).');
      }

      // Alternate phone validation (optional)
      final cleanAltPhone = CustomerSearchIndex.normalizePhone(altPhone);
      if (altPhone.isNotEmpty &&
          (cleanAltPhone.length < 7 || cleanAltPhone.length > 15)) {
        rowErrors.add('Alternate phone must be a valid number (7-15 digits).');
      }
      if (cleanPhone.isNotEmpty &&
          cleanAltPhone.isNotEmpty &&
          cleanPhone == cleanAltPhone) {
        rowErrors.add('Alternate phone must be different from primary phone.');
      }

      // Area resolution
      var resolvedAreaId = '';
      if (rawArea.isNotEmpty) {
        final match = availableAreas.firstWhere(
          (a) =>
              a.name.toLowerCase() == rawArea.toLowerCase() || a.id == rawArea,
          orElse:
              () =>
                  availableAreas.isNotEmpty
                      ? availableAreas.first
                      : const DeliveryArea(
                        id: '',
                        name: '',
                        isActive: true,
                        assignedEmployeeIds: {},
                      ),
        );
        resolvedAreaId = match.id;
      }
      if (resolvedAreaId.isEmpty && availableAreas.isNotEmpty) {
        resolvedAreaId = availableAreas.first.id;
      }
      if (resolvedAreaId.isEmpty) {
        rowErrors.add('No valid delivery area found for this row.');
      }

      // Fallback address & landmark if empty
      final areaName =
          availableAreas
              .firstWhere(
                (a) => a.id == resolvedAreaId,
                orElse: () => availableAreas.first,
              )
              .name;
      if (address.length < 5) {
        address =
            house.isNotEmpty
                ? 'House / Flat $house, $areaName'
                : '$name, $areaName';
      }
      if (landmark.length < 2) {
        landmark = 'Near $areaName';
      }

      // Delivery placement
      final placement = DeliveryPlacement.fromValue(placementStr.toLowerCase());

      // Opening balance
      var balancePaise = 0;
      if (isHead && balanceStr.isNotEmpty) {
        try {
          balancePaise = CustomerMoney.parseRupeesToPaise(balanceStr);
        } catch (_) {
          // ignore invalid balance formatting
        }
      }

      // Duplicate checks (ONLY for non-empty phone numbers)
      var isDuplicateInFile = false;
      if (cleanPhone.isNotEmpty) {
        if (seenPhonesInFile.containsKey(cleanPhone)) {
          isDuplicateInFile = true;
          rowErrors.add('Duplicate phone number within this import file.');
        } else {
          seenPhonesInFile[cleanPhone] = r + 1;
        }
      }

      final isDuplicateInDb =
          cleanPhone.isNotEmpty && existingPhones.contains(cleanPhone);
      if (isDuplicateInDb) {
        rowErrors.add('Phone number already exists in your business database.');
      }

      final rawDataMap = <String, String>{};
      for (var c = 0; c < headers.length && c < rawRow.length; c++) {
        rawDataMap[headers[c]] = rawRow[c];
      }

      parsedRows.add(
        CustomerImportRow(
          rowIndex: r + 1,
          rawData: rawDataMap,
          name: name,
          phone: phone,
          alternatePhone: altPhone,
          areaName: areaName,
          houseNumber: house,
          buildingInfo: building,
          address: address,
          landmark: landmark,
          deliveryPlacement: placement,
          openingBalancePaise: balancePaise,
          notes: notes,
          newspaperName: newspaper,
          errors: rowErrors,
          isDuplicateInFile: isDuplicateInFile,
          isDuplicateInDb: isDuplicateInDb,
        ),
      );
    }

    final validCount = parsedRows.where((r) => r.isValid).length;
    final dupCount = parsedRows.where((r) => r.isDuplicateInFile || r.isDuplicateInDb).length;
    final invalidCount = parsedRows.where((r) => r.errors.isNotEmpty && !r.isDuplicateInFile && !r.isDuplicateInDb).length;

    return CustomerImportValidationResult(
      totalRows: parsedRows.length,
      validRows: validCount,
      duplicateRows: dupCount,
      invalidRows: invalidCount,
      rows: parsedRows,
    );
  }

  /// Executes chunked Firestore batch writes to import valid customer rows safely.
  Stream<CustomerImportProgress> executeChunkedImport({
    required AppUser actor,
    required List<CustomerImportRow> rowsToImport,
    required List<DeliveryArea> availableAreas,
    required List<Newspaper> availableNewspapers,
    int chunkSize = 50,
  }) async* {
    final businessId = actor.businessId!;
    final total = rowsToImport.length;
    var processed = 0;
    var successful = 0;
    var failed = 0;

    yield CustomerImportProgress(
      total: total,
      processed: 0,
      successful: 0,
      failed: 0,
    );

    for (var i = 0; i < rowsToImport.length; i += chunkSize) {
      final chunk = rowsToImport.skip(i).take(chunkSize).toList();
      final batch = _firestore.batch();
      final now = FieldValue.serverTimestamp();

      try {
        for (final row in chunk) {
          final customerCode = 'C-${_uuid.v4().replaceAll('-', '').toUpperCase()}';
          final customerRef = _firestore
              .collection('businesses')
              .doc(businessId)
              .collection('customers')
              .doc(customerCode);
          final auditRef = _firestore
              .collection('businesses')
              .doc(businessId)
              .collection('auditRecords')
              .doc();

          // Resolve area ID
          final area = availableAreas.firstWhere(
            (a) => a.name.toLowerCase() == row.areaName.toLowerCase(),
            orElse: () => availableAreas.first,
          );

          final input = CustomerInput(
            name: row.name,
            phone: row.phone,
            alternatePhone: row.alternatePhone,
            address: row.address,
            areaId: area.id,
            landmark: row.landmark,
            houseNumber: row.houseNumber,
            buildingInfo: row.buildingInfo,
            locationNotes: '',
            locationConsent: false,
            coordinates: null,
            assignedEmployeeId: actor.isHead ? '' : actor.uid,
            deliveryPlacement: row.deliveryPlacement,
            billingCycle: BillingCyclePreference.monthly,
            openingBalancePaise: actor.isHead ? row.openingBalancePaise : 0,
            notes: row.notes,
          );

          final norm = input.normalized();
          batch.set(customerRef, {
            'businessId': businessId,
            'customerCode': customerCode,
            'name': norm.name,
            'searchName': CustomerSearchIndex.normalizeText(norm.name),
            'phone': norm.phone,
            'searchPhone': CustomerSearchIndex.normalizePhone(norm.phone),
            'alternatePhone': norm.alternatePhone,
            'address': norm.address,
            'areaId': norm.areaId,
            'landmark': norm.landmark,
            'searchLandmark': CustomerSearchIndex.normalizeText(norm.landmark),
            'searchTokens': CustomerSearchIndex.buildTokens(
              customerCode: customerCode,
              name: norm.name,
              phone: norm.phone,
              alternatePhone: norm.alternatePhone,
              landmark: norm.landmark,
            ),
            'houseNumber': norm.houseNumber,
            'buildingInfo': norm.buildingInfo,
            'locationNotes': '',
            'locationConsent': false,
            'assignedEmployeeId': actor.isHead ? '' : actor.uid,
            'status': CustomerStatus.active.value,
            'subscriptionStatus': 'notConfigured',
            'deliveryPreferences': {
              'placement': norm.deliveryPlacement.value,
            },
            'billingPreferences': {
              'cycle': norm.billingCycle.value,
            },
            'openingBalancePaise': norm.openingBalancePaise,
            'notes': norm.notes,
            'createdBy': actor.uid,
            'updatedBy': actor.uid,
            'lastAuditId': auditRef.id,
            'createdAt': now,
            'updatedAt': now,
          });

          batch.set(auditRef, {
            'businessId': businessId,
            'actorId': actor.uid,
            'action': 'customerCreated',
            'entityType': 'customer',
            'entityId': customerCode,
            'employeeId': actor.isHead ? '' : actor.uid,
            'areaId': norm.areaId,
            'openingBalancePaise': norm.openingBalancePaise,
            'createdAt': now,
          });

          // Optional initial subscription if publication is mapped
          if (row.newspaperName.isNotEmpty) {
            final pub = availableNewspapers.firstWhere(
              (p) =>
                  p.name.toLowerCase().contains(row.newspaperName.toLowerCase()) ||
                  row.newspaperName.toLowerCase().contains(p.name.toLowerCase()),
              orElse: () => const Newspaper(
                id: '',
                businessId: '',
                newspaperCode: '',
                name: '',
                searchName: '',
                edition: '',
                language: '',
                defaultPricePaise: 0,
                status: NewspaperStatus.active,
                createdBy: '',
                updatedBy: '',
                lastAuditId: '',
              ),
            );

            if (pub.id.isNotEmpty) {
              final subRef = customerRef.collection('subscriptions').doc(pub.id);
              final versionId = _uuid.v4().replaceAll('-', '').toUpperCase();
              final versionRef = subRef.collection('versions').doc(versionId);
              final today = LocalDate.fromDateTime(DateTime.now());

              batch.set(subRef, {
                'businessId': businessId,
                'customerId': customerCode,
                'newspaperId': pub.id,
                'newspaperName': pub.name,
                'currentVersionId': versionId,
                'currentPauseId': '',
                'status': 'active',
                'startDate': today.toString(),
                'endDate': null,
                'currentEffectiveFrom': today.toString(),
                'quantity': 1,
                'deliveryWeekdays': [1, 2, 3, 4, 5, 6, 7],
                'customPricePaise': null,
                'customPriceReason': '',
                'createdBy': actor.uid,
                'updatedBy': actor.uid,
                'lastAuditId': auditRef.id,
                'createdAt': now,
                'updatedAt': now,
              });

              batch.set(versionRef, {
                'businessId': businessId,
                'customerId': customerCode,
                'subscriptionId': pub.id,
                'versionId': versionId,
                'effectiveFrom': today.toString(),
                'effectiveTo': null,
                'quantity': 1,
                'deliveryWeekdays': [1, 2, 3, 4, 5, 6, 7],
                'customPricePaise': null,
                'customPriceReason': '',
                'supersedesVersionId': '',
                'supersededByVersionId': '',
                'revision': 1,
                'createdBy': actor.uid,
                'lastAuditId': auditRef.id,
                'createdAt': now,
              });
            }
          }
        }

        await batch.commit();
        processed += chunk.length;
        successful += chunk.length;
      } catch (error) {
        processed += chunk.length;
        failed += chunk.length;
      }

      yield CustomerImportProgress(
        total: total,
        processed: processed,
        successful: successful,
        failed: failed,
        isComplete: processed >= total,
      );
    }
  }

  Future<Set<String>> _loadExistingPhones(String businessId) async {
    final snapshot = await _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('customers')
        .where('businessId', isEqualTo: businessId)
        .limit(2000)
        .get();

    return snapshot.docs
        .map((d) => d.data()['searchPhone'] as String? ?? '')
        .where((p) => p.isNotEmpty)
        .toSet();
  }
}
