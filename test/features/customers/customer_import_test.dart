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
      expect(stopwatch.elapsedMilliseconds, lessThan(3000)); // Fast client-side execution
    });
  });
}
