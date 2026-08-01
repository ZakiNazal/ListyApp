/// Phone number normalisation used to match device contacts against registered
/// Listy users.
///
/// Contacts are stored inconsistently on a device -- "0501234567",
/// "+966 50 123 4567", "00966-50-123-4567" and "(050) 123 4567" can all be the
/// same person. Firestore can only match on exact string equality, so every
/// number is folded to E.164 (`+<country><subscriber>`) before it is written or
/// queried.
///
/// NOTE: this is a deliberately dependency-free heuristic, not a full
/// libphonenumber implementation. It handles the common cases (international
/// prefix, trunk `0`, punctuation) but does not validate that a number is
/// actually assignable in a given country. If you later need strict validation,
/// swap [normalize] for the `phone_numbers_parser` package -- everything else
/// in the app goes through this one function.
abstract final class PhoneUtils {
  /// Fallback country dialling code, used when a contact is stored in local
  /// format and we cannot infer the region any other way.
  static const String defaultDialCode = '+966';

  /// Folds [raw] into E.164, e.g. `050 123 4567` -> `+966501234567`.
  ///
  /// [dialCode] should be the current user's country code (derived from their
  /// own signed-in number) so local-format contacts resolve to the same region.
  /// Returns `null` when [raw] cannot plausibly be a phone number.
  static String? normalize(String? raw, {String dialCode = defaultDialCode}) {
    if (raw == null) return null;

    // Keep digits and a single leading '+'.
    final hasPlus = raw.trimLeft().startsWith('+');
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;

    final normalizedDialCode =
        dialCode.startsWith('+') ? dialCode : '+$dialCode';
    final dialDigits = normalizedDialCode.replaceAll(RegExp(r'\D'), '');

    String result;
    if (hasPlus) {
      // Already international.
      result = '+$digits';
    } else if (digits.startsWith('00')) {
      // 00 is the international access prefix in most of the world.
      result = '+${digits.substring(2)}';
    } else if (digits.startsWith('0')) {
      // National format with a trunk prefix -> strip the 0, add the country.
      result = '+$dialDigits${digits.substring(1)}';
    } else if (digits.startsWith(dialDigits)) {
      // Already carries the country code but no '+'.
      result = '+$digits';
    } else {
      result = '+$dialDigits$digits';
    }

    // E.164 allows at most 15 digits; anything shorter than 8 is not a real
    // mobile number (it is usually a short code or a mangled contact entry).
    final resultDigits = result.length - 1;
    if (resultDigits < 8 || resultDigits > 15) return null;

    return result;
  }

  /// Extracts the dialling code from an E.164 number so contacts stored in
  /// local format resolve to the signed-in user's own region.
  ///
  /// Uses the longest-match-first list of common multi-digit codes, then falls
  /// back to the ITU convention that a leading 1 or 7 is a single-digit code.
  static String dialCodeOf(String? e164) {
    if (e164 == null || !e164.startsWith('+')) return defaultDialCode;
    final digits = e164.substring(1);

    const threeDigit = <String>{
      '966', '971', '974', '973', '968', '965', '962', '961', '963', '964',
      '970', '212', '213', '216', '218', '220', '234', '254', '255', '256',
      '351', '352', '353', '358', '359', '370', '371', '372', '380', '381',
      '385', '386', '387', '389', '420', '421', '852', '853', '855', '856',
      '880', '886', '960', '977', '992', '993', '994', '995', '998',
    };
    const twoDigit = <String>{
      '20', '27', '30', '31', '32', '33', '34', '36', '39', '40', '41', '43',
      '44', '45', '46', '47', '48', '49', '51', '52', '53', '54', '55', '56',
      '57', '58', '60', '61', '62', '63', '64', '65', '66', '81', '82', '84',
      '86', '90', '91', '92', '93', '94', '95', '98',
    };

    if (digits.length >= 3 && threeDigit.contains(digits.substring(0, 3))) {
      return '+${digits.substring(0, 3)}';
    }
    if (digits.length >= 2 && twoDigit.contains(digits.substring(0, 2))) {
      return '+${digits.substring(0, 2)}';
    }
    if (digits.isNotEmpty &&
        (digits.startsWith('1') || digits.startsWith('7'))) {
      return '+${digits.substring(0, 1)}';
    }
    return defaultDialCode;
  }

  /// Renders an E.164 number for display, e.g. `+966501234567` -> `+966 50 123 4567`.
  static String pretty(String? e164) {
    if (e164 == null || e164.isEmpty) return '';
    if (!e164.startsWith('+')) return e164;

    final dial = dialCodeOf(e164);
    final rest = e164.substring(dial.length);
    if (rest.isEmpty) return e164;

    final buffer = StringBuffer(dial);
    // Group the subscriber number in 2-3-4 style chunks for legibility.
    var i = 0;
    for (final size in const [2, 3, 4, 4]) {
      if (i >= rest.length) break;
      final end = (i + size).clamp(0, rest.length);
      buffer
        ..write(' ')
        ..write(rest.substring(i, end));
      i = end;
    }
    if (i < rest.length) buffer.write(rest.substring(i));
    return buffer.toString();
  }

  /// Cheap sanity check for the login form.
  static bool isPlausible(String? raw, {String dialCode = defaultDialCode}) =>
      normalize(raw, dialCode: dialCode) != null;

  /// Normalises a number the user typed at sign-in, requiring an explicit
  /// country code.
  ///
  /// [normalize] deliberately guesses a country for local-format input, which
  /// is right for address-book entries but wrong here: guessing at sign-in
  /// means someone typing `1234567890` silently authenticates as
  /// `+9661234567890`, and the resulting failure looks like a bad SMS code
  /// rather than a bad number. Better to refuse and ask.
  ///
  /// Accepts `+9665...`, `009665...` and the same with punctuation. Returns
  /// null for anything without an international prefix.
  static String? normalizeSignIn(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (!trimmed.startsWith('+') && !trimmed.replaceAll(RegExp(r'\D'), '').startsWith('00')) {
      return null;
    }
    return normalize(trimmed);
  }
}
