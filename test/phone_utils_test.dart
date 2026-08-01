import 'package:flutter_test/flutter_test.dart';
import 'package:listyapp/core/utils/phone_utils.dart';

/// Phone normalisation is the load-bearing logic behind the contacts picker:
/// if two representations of the same number do not fold to the same string,
/// a registered friend silently shows up as "Invite" instead.
void main() {
  group('normalize', () {
    test('all common formats of one number fold to the same E.164', () {
      const expected = '+966501234567';
      const variants = [
        '+966501234567',
        '+966 50 123 4567',
        '+966-50-123-4567',
        '00966501234567',
        '0501234567',
        '050 123 4567',
        '(050) 123-4567',
        '966501234567',
      ];

      for (final variant in variants) {
        expect(
          PhoneUtils.normalize(variant),
          expected,
          reason: 'failed for "$variant"',
        );
      }
    });

    test('respects the supplied dial code for local-format numbers', () {
      expect(
        PhoneUtils.normalize('07911 123456', dialCode: '+44'),
        '+447911123456',
      );
      expect(
        PhoneUtils.normalize('(555) 010-1234', dialCode: '+1'),
        '+15550101234',
      );
    });

    test('an explicit international number ignores the dial code', () {
      expect(
        PhoneUtils.normalize('+14155550123', dialCode: '+966'),
        '+14155550123',
      );
    });

    test('rejects junk, short codes and empty input', () {
      expect(PhoneUtils.normalize(null), isNull);
      expect(PhoneUtils.normalize(''), isNull);
      expect(PhoneUtils.normalize('   '), isNull);
      expect(PhoneUtils.normalize('no digits here'), isNull);
      expect(PhoneUtils.normalize('911'), isNull, reason: 'too short');
      expect(
        PhoneUtils.normalize('+1234567890123456789'),
        isNull,
        reason: 'exceeds the 15-digit E.164 limit',
      );
    });
  });

  group('dialCodeOf', () {
    test('extracts three, two and one digit codes', () {
      expect(PhoneUtils.dialCodeOf('+966501234567'), '+966');
      expect(PhoneUtils.dialCodeOf('+447911123456'), '+44');
      expect(PhoneUtils.dialCodeOf('+14155550123'), '+1');
    });

    test('falls back to the default for null or malformed input', () {
      expect(PhoneUtils.dialCodeOf(null), PhoneUtils.defaultDialCode);
      expect(PhoneUtils.dialCodeOf('0501234567'), PhoneUtils.defaultDialCode);
    });

    test('round-trips: a normalized number yields its own dial code', () {
      final normalized = PhoneUtils.normalize('0501234567', dialCode: '+966');
      expect(PhoneUtils.dialCodeOf(normalized), '+966');
    });
  });

  group('pretty', () {
    test('groups the subscriber digits and keeps the dial code intact', () {
      expect(PhoneUtils.pretty('+966501234567'), '+966 50 123 4567');
    });

    test('passes through empty and non-E.164 values unchanged', () {
      expect(PhoneUtils.pretty(null), '');
      expect(PhoneUtils.pretty(''), '');
      expect(PhoneUtils.pretty('0501234567'), '0501234567');
    });
  });

  group('normalizeSignIn', () {
    // Regression guard: a US test number typed without "+1" used to be
    // silently normalised to +966..., producing a sign-in failure that looked
    // like a bad SMS code rather than a bad number.
    const usTestNumber = '+11234567890';

    test('accepts an international number however it is punctuated', () {
      for (final variant in const [
        '+11234567890',
        '+1 1234567890',
        '+1 123 456 7890',
        '+1-123-456-7890',
        '  +11234567890 ',
        '0011234567890',
      ]) {
        expect(
          PhoneUtils.normalizeSignIn(variant),
          usTestNumber,
          reason: 'failed for "$variant"',
        );
      }
    });

    test('refuses local format instead of guessing a country', () {
      expect(PhoneUtils.normalizeSignIn('1234567890'), isNull);
      expect(PhoneUtils.normalizeSignIn('0501234567'), isNull);

      // The permissive variant still guesses -- that behaviour is correct for
      // address-book entries, just not at sign-in.
      expect(PhoneUtils.normalize('1234567890'), '+9661234567890');
    });

    test('refuses empty and malformed input', () {
      expect(PhoneUtils.normalizeSignIn(null), isNull);
      expect(PhoneUtils.normalizeSignIn(''), isNull);
      expect(PhoneUtils.normalizeSignIn('+1'), isNull);
      expect(PhoneUtils.normalizeSignIn('+not a number'), isNull);
    });
  });

  group('isPlausible', () {
    test('accepts real numbers and rejects junk', () {
      expect(PhoneUtils.isPlausible('0501234567'), isTrue);
      expect(PhoneUtils.isPlausible('+966501234567'), isTrue);
      expect(PhoneUtils.isPlausible('123'), isFalse);
      expect(PhoneUtils.isPlausible(''), isFalse);
    });
  });
}
