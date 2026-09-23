import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_route/features/areas/domain/delivery_area.dart';
import 'package:paper_route/features/customers/data/customer_import_service.dart';
import 'package:paper_route/features/newspapers/domain/newspaper.dart';

void main() {
  group('CustomerImportService & Bulk Onboarding', () {
    final importService = CustomerImportService();
    const testAreas = [
      DeliveryArea(
        id: 'area-1',
        name: 'Main Market',
        isActive: true,
        assignedEmployeeIds: {},
      ),
      DeliveryArea(
        id: 'area-2',
        name: 'Civil Lines',
        isActive: true,
        assignedEmployeeIds: {},
      ),
    ];
    const testNewspapers = [
      Newspaper(
        id: 'N-JAGRAN',
        businessId: 'biz-1',
        newspaperCode: 'N-JAGRAN',
        name: 'Dainik Jagran',
        searchName: 'dainik jagran',
        edition: 'Delhi',
        language: 'Hindi',
        defaultPricePaise: 500,
        status: NewspaperStatus.active,
        createdBy: 'user-1',
        updatedBy: 'user-1',
        lastAuditId: 'audit-1',
      ),
    ];

    test('Parses RFC 4180 CSV with quotes, commas, and multiline cells', () {
      const csv = '''Name,Phone,Area,Address
"Sharma, Ramesh",9876543210,Main Market,"Flat 102,
Tower B"
Suresh Gupta,9876543211,Civil Lines,B-4 Civil Lines''';

      final table = CustomerImportService.parseCsv(csv);
      expect(table.length, 3);
      expect(table[1][0], 'Sharma, Ramesh');
      expect(table[1][1], '9876543210');
      expect(table[1][3], 'Flat 102,\nTower B');
      expect(table[2][0], 'Suresh Gupta');
    });

    test('Maps English and Hindi headers and detects duplicate phone numbers', () async {
      const csv = '''नाम,मोबाइल,इलाका,मकान नं,बैलेंस
राजेश कुमार,9876543210,Main Market,12,150
अमित सिंह,9876543210,Civil Lines,B-4,0
विक्रम वर्मा,9876543212,Main Market,55,50''';

      final table = CustomerImportService.parseCsv(csv);
      final result = await importService.validateRows(
        csvTable: table,
        availableAreas: testAreas,
        availableNewspapers: testNewspapers,
        businessId: 'biz-1',
        isHead: true,
        preloadedExistingPhones: {'9876543212'}, // Vikram is in DB
      );

      expect(result.totalRows, 3);
      // Row 1: Valid
      expect(result.rows[0].isValid, isTrue);
      expect(result.rows[0].name, 'राजेश कुमार');
      expect(result.rows[0].openingBalancePaise, 15000);

      // Row 2: In-file duplicate with Row 1
      expect(result.rows[1].isDuplicateInFile, isTrue);
      expect(result.rows[1].isValid, isFalse);

      // Row 3: In-DB duplicate
      expect(result.rows[2].isDuplicateInDb, isTrue);
      expect(result.rows[2].isValid, isFalse);

      expect(result.validRows, 1);
      expect(result.duplicateRows, 2);
    });

    test('Scales efficiently to 1,000 customer rows stress test', () async {
      final buffer = StringBuffer('Name,Phone,Area,House No,Opening Balance\n');
      for (var i = 1; i <= 1000; i++) {
        final phone = '98${i.toString().padLeft(8, '0')}';
        buffer.writeln('Customer $i,$phone,Main Market,Flat $i,100');
      }

      final stopwatch = Stopwatch()..start();
      final table = CustomerImportService.parseCsv(buffer.toString());
      final result = await importService.validateRows(
        csvTable: table,
        availableAreas: testAreas,
        availableNewspapers: testNewspapers,
        businessId: 'biz-1',
        isHead: true,
        preloadedExistingPhones: {},
      );
      stopwatch.stop();

      expect(result.totalRows, 1000);
      expect(result.validRows, 1000);
      expect(result.invalidRows, 0);
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(3000),
      ); // Fast client-side execution
    });

    test('Accepts and decodes native Excel (.xlsx) file bytes seamlessly', () {
      final excel = Excel.createExcel();
      final defaultSheetName = excel.getDefaultSheet() ?? 'Sheet1';
      final sheet = excel[defaultSheetName];

      // Header row
      sheet.appendRow([
        TextCellValue('Name'),
        TextCellValue('Phone'),
        TextCellValue('Area'),
        TextCellValue('House'),
        TextCellValue('Opening Balance'),
      ]);

      // Data rows
      sheet.appendRow([
        TextCellValue('Anand Verma'),
        TextCellValue('9811223344'),
        TextCellValue('Main Market'),
        TextCellValue('401-A'),
        TextCellValue('250'),
      ]);
      sheet.appendRow([
        TextCellValue('Deepak Joshi'),
        TextCellValue('9822334455'),
        TextCellValue('Civil Lines'),
        TextCellValue('12-B'),
        TextCellValue('0'),
      ]);

      final bytes = excel.encode()!;
      expect(bytes.isNotEmpty, isTrue);

      final table = CustomerImportService.parseBytes(
        bytes,
        fileName: 'customers.xlsx',
      );
      expect(table.length, 3);
      expect(table[0][0], 'Name');
      expect(table[0][1], 'Phone');
      expect(table[1][0], 'Anand Verma');
      expect(table[1][1], '9811223344');
      expect(table[2][0], 'Deepak Joshi');
      expect(table[2][2], 'Civil Lines');
    });

    test('Accepts tab-separated (TSV) clipboard paste from Excel / Google Sheets', () {
      const tsv =
          'Name\tPhone\tArea\tHouse\nHarish Patel\t9833445566\tMain Market\tShop 4\nSunil Jain\t9844556677\tCivil Lines\tPlot 9';

      final table = CustomerImportService.parseCsv(tsv);
      expect(table.length, 3);
      expect(table[1][0], 'Harish Patel');
      expect(table[1][1], '9833445566');
      expect(table[2][0], 'Sunil Jain');
      expect(table[2][2], 'Civil Lines');
    });

    test('Optional Phone: allows missing phone numbers without false duplicate matches', () async {
      const csv = '''Name,Phone,Area,House No
Customer Without Phone 1,,Main Market,Flat 1
Customer Without Phone 2,,Main Market,Flat 2
Customer With Phone,9876543210,Civil Lines,B-1''';

      final table = CustomerImportService.parseCsv(csv);
      final result = await importService.validateRows(
        csvTable: table,
        availableAreas: testAreas,
        availableNewspapers: testNewspapers,
        businessId: 'biz-1',
        isHead: true,
        preloadedExistingPhones: {},
      );

      expect(result.totalRows, 3);
      // Both customers without phone numbers should be valid and NOT collide as duplicates
      expect(result.rows[0].phone, isEmpty);
      expect(result.rows[0].isValid, isTrue);
      expect(result.rows[0].isDuplicateInFile, isFalse);

      expect(result.rows[1].phone, isEmpty);
      expect(result.rows[1].isValid, isTrue);
      expect(result.rows[1].isDuplicateInFile, isFalse);

      expect(result.rows[2].phone, '9876543210');
      expect(result.rows[2].isValid, isTrue);

      expect(result.validRows, 3);
      expect(result.duplicateRows, 0);
      expect(result.invalidRows, 0);
    });
  });
}
