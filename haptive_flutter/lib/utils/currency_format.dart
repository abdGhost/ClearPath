import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

class CurrencyFormat {
  static Locale _effectiveLocale(BuildContext context) {
    final fromContext = Localizations.localeOf(context);
    if ((fromContext.countryCode ?? '').isNotEmpty) return fromContext;
    final fromPlatform = WidgetsBinding.instance.platformDispatcher.locale;
    return fromPlatform;
  }

  static String? _currencyCodeForLocale(Locale locale) {
    final country = (locale.countryCode ?? '').toUpperCase();
    switch (country) {
      case 'IN':
        return 'INR';
      case 'US':
        return 'USD';
      case 'GB':
        return 'GBP';
      case 'JP':
        return 'JPY';
      case 'EU':
        return 'EUR';
      default:
        return null;
    }
  }

  static String? _forcedCode(String preference) {
    final p = preference.trim().toUpperCase();
    if (p == 'INR' || p == 'USD') return p;
    return null;
  }

  static NumberFormat _formatter(
    BuildContext context, {
    String preferredCurrency = 'auto',
  }) {
    final locale = _effectiveLocale(context);
    final localeTag = locale.toLanguageTag();
    var currencyCode = _forcedCode(preferredCurrency) ?? _currencyCodeForLocale(locale);

    // Fallback for India users when browser locale is generic/US but timezone is IST.
    if (currencyCode == null &&
        DateTime.now().timeZoneOffset == const Duration(hours: 5, minutes: 30)) {
      currencyCode = 'INR';
    }

    return NumberFormat.simpleCurrency(
      locale: localeTag,
      name: currencyCode,
    );
  }

  static String symbol(
    BuildContext context, {
    String preferredCurrency = 'auto',
  }) =>
      _formatter(
        context,
        preferredCurrency: preferredCurrency,
      ).currencySymbol;

  static String amount(
    BuildContext context,
    double value, {
    String preferredCurrency = 'auto',
  }) =>
      _formatter(
        context,
        preferredCurrency: preferredCurrency,
      ).format(value);
}
