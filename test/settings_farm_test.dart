import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rearticle_app/services/settings_service.dart';
import 'package:rearticle_app/services/format_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Farm Address in SettingsService', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await SettingsService.instance.init();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    });

    test('Structured address fields can be set and retrieved individually', () async {
      final settings = SettingsService.instance;

      await settings.setFarmAddressLine1('Suite 400');
      await settings.setFarmAddressLine2('Building C');
      await settings.setFarmStreetName('123 Meadow Lane');
      await settings.setFarmCity('Amaranth');
      await settings.setFarmState('Ontario');
      await settings.setFarmZip('L9W 3Y4');

      expect(settings.farmAddressLine1, 'Suite 400');
      expect(settings.farmAddressLine2, 'Building C');
      expect(settings.farmStreetName, '123 Meadow Lane');
      expect(settings.farmCity, 'Amaranth');
      expect(settings.farmState, 'Ontario');
      expect(settings.farmZip, 'L9W 3Y4');
    });

    test('farmAddress composite getter combines all fields cleanly', () async {
      final settings = SettingsService.instance;

      await settings.setFarmAddressLine1('123 Farm Road');
      await settings.setFarmAddressLine2('Apt 2B');
      await settings.setFarmStreetName('Meadow Lane');
      await settings.setFarmCity('Amaranth');
      await settings.setFarmState('ON');
      await settings.setFarmZip('L9W 3Y4');

      expect(settings.farmAddress, '123 Farm Road, Apt 2B, Meadow Lane, Amaranth, ON L9W 3Y4');
    });

    test('farmAddress falls back to legacy string if structured fields are unset', () async {
      final settings = SettingsService.instance;
      await settings.setFarmAddressLine1('');
      await settings.setFarmAddressLine2('');
      await settings.setFarmStreetName('');
      await settings.setFarmCity('');
      await settings.setFarmState('');
      await settings.setFarmZip('');
      await settings.setFarmAddress('Legacy Address String');

      expect(settings.farmAddressLine1, '');
      expect(settings.farmAddress, 'Legacy Address String');
    });
  });

  group('Phone Number Formatting (xxx-xxx-xxxx)', () {
    test('FormatUtils.formatPhoneNumber formats 10-digit numbers to xxx-xxx-xxxx', () {
      expect(FormatUtils.formatPhoneNumber('5551234567', countryCode: 'usd'), '555-123-4567');
      expect(FormatUtils.formatPhoneNumber('555-123-4567', countryCode: 'usd'), '555-123-4567');
      expect(FormatUtils.formatPhoneNumber('(555) 123-4567', countryCode: 'usd'), '555-123-4567');
      expect(FormatUtils.formatPhoneNumber('555 123 4567', countryCode: 'usd'), '555-123-4567');
      expect(FormatUtils.formatPhoneNumber('15551234567', countryCode: 'usd'), '555-123-4567');
    });

    test('PhoneNumberFormatter formats partially typed numbers progressively', () {
      final formatter = PhoneNumberFormatter(countryCode: 'usd');

      var val = formatter.formatEditUpdate(
        const TextEditingValue(text: ''),
        const TextEditingValue(text: '555'),
      );
      expect(val.text, '555');

      val = formatter.formatEditUpdate(
        const TextEditingValue(text: '555'),
        const TextEditingValue(text: '5551'),
      );
      expect(val.text, '555-1');

      val = formatter.formatEditUpdate(
        const TextEditingValue(text: '555-123'),
        const TextEditingValue(text: '555-1234'),
      );
      expect(val.text, '555-123-4');

      val = formatter.formatEditUpdate(
        const TextEditingValue(text: '555-123-456'),
        const TextEditingValue(text: '555-123-4567'),
      );
      expect(val.text, '555-123-4567');
    });
  });
}
