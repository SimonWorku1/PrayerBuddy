class PhoneFormatter {
  // Common country codes with their dialing codes
  static const Map<String, String> countryCodes = {
    'US': '+1',
    'CA': '+1',
    'GB': '+44',
    'DE': '+49',
    'FR': '+33',
    'IT': '+39',
    'ES': '+34',
    'AU': '+61',
    'JP': '+81',
    'CN': '+86',
    'IN': '+91',
    'BR': '+55',
    'MX': '+52',
    'RU': '+7',
    'KR': '+82',
    'NL': '+31',
    'SE': '+46',
    'NO': '+47',
    'DK': '+45',
    'FI': '+358',
    'PL': '+48',
    'CZ': '+420',
    'HU': '+36',
    'RO': '+40',
    'BG': '+359',
    'HR': '+385',
    'SI': '+386',
    'SK': '+421',
    'LT': '+370',
    'LV': '+371',
    'EE': '+372',
    'IE': '+353',
    'PT': '+351',
    'GR': '+30',
    'CY': '+357',
    'MT': '+356',
    'LU': '+352',
    'BE': '+32',
    'AT': '+43',
    'CH': '+41',
    'LI': '+423',
    'IS': '+354',
    'FO': '+298',
    'GL': '+299',
    'NZ': '+64',
    'ZA': '+27',
    'EG': '+20',
    'NG': '+234',
    'KE': '+254',
    'UG': '+256',
    'TZ': '+255',
    'ET': '+251',
    'GH': '+233',
    'CI': '+225',
    'SN': '+221',
    'ML': '+223',
    'BF': '+226',
    'NE': '+227',
    'TD': '+235',
    'CM': '+237',
    'CF': '+236',
    'CG': '+242',
    'CD': '+243',
    'AO': '+244',
    'GW': '+245',
    'GN': '+224',
    'SL': '+232',
    'LR': '+231',
    'TG': '+228',
    'BJ': '+229',
    'ST': '+239',
    'GQ': '+240',
    'GA': '+241',
    'MG': '+261',
    'MU': '+230',
    'SC': '+248',
    'KM': '+269',
    'YT': '+262',
    'RE': '+262',
    'DJ': '+253',
    'SO': '+252',
    'ER': '+291',
    'SD': '+249',
    'SS': '+211',
    'LY': '+218',
    'TN': '+216',
    'DZ': '+213',
    'MA': '+212',
    'EH': '+212',
    'MR': '+222',
  };

  // Get country code by dialing code
  static String? getCountryByDialingCode(String dialingCode) {
    for (var entry in countryCodes.entries) {
      if (entry.value == dialingCode) {
        return entry.key;
      }
    }
    return null;
  }

  // Get dialing code by country code
  static String? getDialingCodeByCountry(String countryCode) {
    return countryCodes[countryCode.toUpperCase()];
  }

  // Format phone number with country code
  static String formatPhoneNumber(String phoneNumber, String countryCode) {
    // Remove all non-digit characters
    String digitsOnly = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    
    String? dialingCode = getDialingCodeByCountry(countryCode);
    if (dialingCode == null) {
      return phoneNumber; // Return original if country not found
    }

    // Remove country code if it's already included
    if (digitsOnly.startsWith(dialingCode.replaceAll('+', ''))) {
      digitsOnly = digitsOnly.substring(dialingCode.replaceAll('+', '').length);
    }

    // Format based on country
    switch (countryCode.toUpperCase()) {
      case 'US':
      case 'CA':
        return _formatUSCanada(digitsOnly, dialingCode);
      case 'GB':
        return _formatUK(digitsOnly, dialingCode);
      case 'DE':
        return _formatGermany(digitsOnly, dialingCode);
      case 'FR':
        return _formatFrance(digitsOnly, dialingCode);
      case 'AU':
        return _formatAustralia(digitsOnly, dialingCode);
      case 'IN':
        return _formatIndia(digitsOnly, dialingCode);
      default:
        // Default formatting for other countries
        return '$dialingCode $digitsOnly';
    }
  }

  // US/Canada format: +1 (555) 123-4567
  static String _formatUSCanada(String digits, String dialingCode) {
    if (digits.length == 10) {
      return '$dialingCode (${digits.substring(0, 3)}) ${digits.substring(3, 6)}-${digits.substring(6)}';
    } else if (digits.length == 11 && digits.startsWith('1')) {
      digits = digits.substring(1);
      return '$dialingCode (${digits.substring(0, 3)}) ${digits.substring(3, 6)}-${digits.substring(6)}';
    }
    return '$dialingCode $digits';
  }

  // UK format: +44 20 7946 0958
  static String _formatUK(String digits, String dialingCode) {
    if (digits.length >= 10) {
      return '$dialingCode ${digits.substring(0, 2)} ${digits.substring(2, 6)} ${digits.substring(6)}';
    }
    return '$dialingCode $digits';
  }

  // Germany format: +49 30 12345678
  static String _formatGermany(String digits, String dialingCode) {
    if (digits.length >= 10) {
      return '$dialingCode ${digits.substring(0, 2)} ${digits.substring(2, 6)} ${digits.substring(6)}';
    }
    return '$dialingCode $digits';
  }

  // France format: +33 1 42 34 56 78
  static String _formatFrance(String digits, String dialingCode) {
    if (digits.length >= 10) {
      return '$dialingCode ${digits.substring(0, 1)} ${digits.substring(1, 3)} ${digits.substring(3, 5)} ${digits.substring(5, 7)} ${digits.substring(7)}';
    }
    return '$dialingCode $digits';
  }

  // Australia format: +61 2 8765 4321
  static String _formatAustralia(String digits, String dialingCode) {
    if (digits.length >= 9) {
      return '$dialingCode ${digits.substring(0, 1)} ${digits.substring(1, 5)} ${digits.substring(5)}';
    }
    return '$dialingCode $digits';
  }

  // India format: +91 98765 43210
  static String _formatIndia(String digits, String dialingCode) {
    if (digits.length == 10) {
      return '$dialingCode ${digits.substring(0, 5)} ${digits.substring(5)}';
    }
    return '$dialingCode $digits';
  }

  // Get clean phone number for Firebase (just digits with country code)
  static String getCleanPhoneNumber(String phoneNumber, String countryCode) {
    String digitsOnly = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    String? dialingCode = getDialingCodeByCountry(countryCode);
    
    if (dialingCode == null) {
      return phoneNumber;
    }

    // Remove country code if it's already included
    if (digitsOnly.startsWith(dialingCode.replaceAll('+', ''))) {
      digitsOnly = digitsOnly.substring(dialingCode.replaceAll('+', '').length);
    }

    return '$dialingCode$digitsOnly';
  }

  // Validate phone number format
  static bool isValidPhoneNumber(String phoneNumber, String countryCode) {
    String cleanNumber = getCleanPhoneNumber(phoneNumber, countryCode);
    String? dialingCode = getDialingCodeByCountry(countryCode);
    
    if (dialingCode == null) return false;

    // Remove the + and country code for length check
    String numberWithoutCode = cleanNumber.replaceAll(dialingCode, '');
    
    // Basic validation - most countries have 7-15 digits
    return numberWithoutCode.length >= 7 && numberWithoutCode.length <= 15;
  }
} 