/// A selectable currency for pricing ingredients.
class Currency {
  final String code;
  final String symbol;
  final String name;

  const Currency({required this.code, required this.symbol, required this.name});
}

class Currencies {
  static const List<Currency> all = [
    Currency(code: 'USD', symbol: '\$', name: 'US Dollar'),
    Currency(code: 'EUR', symbol: '€', name: 'Euro'),
    Currency(code: 'GBP', symbol: '£', name: 'British Pound'),
    Currency(code: 'PHP', symbol: '₱', name: 'Philippine Peso'),
    Currency(code: 'JPY', symbol: '¥', name: 'Japanese Yen'),
    Currency(code: 'CNY', symbol: '¥', name: 'Chinese Yuan'),
    Currency(code: 'INR', symbol: '₹', name: 'Indian Rupee'),
    Currency(code: 'AUD', symbol: '\$', name: 'Australian Dollar'),
    Currency(code: 'CAD', symbol: '\$', name: 'Canadian Dollar'),
    Currency(code: 'SGD', symbol: '\$', name: 'Singapore Dollar'),
    Currency(code: 'HKD', symbol: '\$', name: 'Hong Kong Dollar'),
    Currency(code: 'NZD', symbol: '\$', name: 'New Zealand Dollar'),
    Currency(code: 'KRW', symbol: '₩', name: 'South Korean Won'),
    Currency(code: 'MXN', symbol: '\$', name: 'Mexican Peso'),
    Currency(code: 'BRL', symbol: 'R\$', name: 'Brazilian Real'),
    Currency(code: 'CHF', symbol: 'Fr', name: 'Swiss Franc'),
    Currency(code: 'ZAR', symbol: 'R', name: 'South African Rand'),
    Currency(code: 'AED', symbol: 'د.إ', name: 'UAE Dirham'),
  ];

  static Currency byCode(String code) {
    return all.firstWhere(
      (c) => c.code == code,
      orElse: () => all.first,
    );
  }
}
