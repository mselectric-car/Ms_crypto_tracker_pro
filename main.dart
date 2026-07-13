import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const CryptoApp());
}

class CryptoApp extends StatefulWidget {
  const CryptoApp({super.key});

  @override
  State<CryptoApp> createState() => _CryptoAppState();
}

class _CryptoAppState extends State<CryptoApp> {
  ThemeMode _themeMode = ThemeMode.dark;
  String _currency = 'eur';
  String _accent = 'teal';
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final theme = prefs.getString('theme') ?? 'dark';
    _currency = prefs.getString('currency') ?? 'eur';
    _accent = prefs.getString('accent') ?? 'teal';
    _themeMode = theme == 'light'
        ? ThemeMode.light
        : theme == 'system'
            ? ThemeMode.system
            : ThemeMode.dark;
    if (mounted) setState(() => _ready = true);
  }

  Color get _seedColor {
    switch (_accent) {
      case 'blue':
        return Colors.blue;
      case 'green':
        return Colors.green;
      case 'purple':
        return Colors.deepPurple;
      default:
        return Colors.teal;
    }
  }

  Future<void> _setTheme(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    final value = mode == ThemeMode.light
        ? 'light'
        : mode == ThemeMode.system
            ? 'system'
            : 'dark';
    await prefs.setString('theme', value);
    setState(() => _themeMode = mode);
  }

  Future<void> _setCurrency(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currency', value);
    setState(() => _currency = value);
  }

  Future<void> _setAccent(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('accent', value);
    setState(() => _accent = value);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MS Crypto Tracker Pro',
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: _seedColor,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: _seedColor,
      ),
      home: HomePage(
        themeMode: _themeMode,
        currency: _currency,
        accent: _accent,
        onThemeChanged: _setTheme,
        onCurrencyChanged: _setCurrency,
        onAccentChanged: _setAccent,
      ),
    );
  }
}

class Coin {
  final String id;
  final String name;
  final String symbol;
  final String image;
  final double price;
  final double change24h;
  final double marketCap;
  final double volume;

  const Coin({
    required this.id,
    required this.name,
    required this.symbol,
    required this.image,
    required this.price,
    required this.change24h,
    required this.marketCap,
    required this.volume,
  });

  factory Coin.fromJson(Map<String, dynamic> json) {
    double asDouble(dynamic value) => (value as num?)?.toDouble() ?? 0;
    return Coin(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? ''}',
      symbol: '${json['symbol'] ?? ''}',
      image: '${json['image'] ?? ''}',
      price: asDouble(json['current_price']),
      change24h: asDouble(json['price_change_percentage_24h']),
      marketCap: asDouble(json['market_cap']),
      volume: asDouble(json['total_volume']),
    );
  }
}

class SearchCoin {
  final String id;
  final String name;
  final String symbol;
  final String image;

  const SearchCoin({
    required this.id,
    required this.name,
    required this.symbol,
    required this.image,
  });

  factory SearchCoin.fromJson(Map<String, dynamic> json) {
    return SearchCoin(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? ''}',
      symbol: '${json['symbol'] ?? ''}',
      image: '${json['large'] ?? json['thumb'] ?? ''}',
    );
  }
}

class Holding {
  final String coinId;
  final String name;
  final String symbol;
  final double amount;
  final double buyPrice;

  const Holding({
    required this.coinId,
    required this.name,
    required this.symbol,
    required this.amount,
    required this.buyPrice,
  });

  Map<String, dynamic> toJson() => {
        'coinId': coinId,
        'name': name,
        'symbol': symbol,
        'amount': amount,
        'buyPrice': buyPrice,
      };

  factory Holding.fromJson(Map<String, dynamic> json) => Holding(
        coinId: '${json['coinId']}',
        name: '${json['name']}',
        symbol: '${json['symbol']}',
        amount: (json['amount'] as num).toDouble(),
        buyPrice: (json['buyPrice'] as num).toDouble(),
      );
}

class AlertItem {
  final String id;
  final String coinId;
  final String symbol;
  final double target;
  final bool above;

  const AlertItem({
    required this.id,
    required this.coinId,
    required this.symbol,
    required this.target,
    required this.above,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'coinId': coinId,
        'symbol': symbol,
        'target': target,
        'above': above,
      };

  factory AlertItem.fromJson(Map<String, dynamic> json) => AlertItem(
        id: '${json['id']}',
        coinId: '${json['coinId']}',
        symbol: '${json['symbol']}',
        target: (json['target'] as num).toDouble(),
        above: json['above'] == true,
      );
}

class Api {
  static const String host = 'api.coingecko.com';

  static Future<List<Coin>> markets(String currency) async {
    final uri = Uri.https(host, '/api/v3/coins/markets', {
      'vs_currency': currency,
      'order': 'market_cap_desc',
      'per_page': '100',
      'page': '1',
      'sparkline': 'false',
      'price_change_percentage': '24h',
    });
    final response = await http.get(uri).timeout(const Duration(seconds: 25));
    if (response.statusCode != 200) {
      throw Exception('CoinGecko API: ${response.statusCode}');
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((item) => Coin.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static Future<List<SearchCoin>> search(String query) async {
    if (query.trim().length < 2) return [];
    final uri = Uri.https(host, '/api/v3/search', {'query': query.trim()});
    final response = await http.get(uri).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) throw Exception('Pretraga nije dostupna');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final list = (data['coins'] as List<dynamic>? ?? []);
    return list
        .take(40)
        .map((item) => SearchCoin.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static Future<Coin> coinById(String id, String currency) async {
    final uri = Uri.https(host, '/api/v3/coins/markets', {
      'vs_currency': currency,
      'ids': id,
      'sparkline': 'false',
      'price_change_percentage': '24h',
    });
    final response = await http.get(uri).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) throw Exception('Valuta nije dostupna');
    final list = jsonDecode(response.body) as List<dynamic>;
    if (list.isEmpty) throw Exception('Nema podataka');
    return Coin.fromJson(list.first as Map<String, dynamic>);
  }

  static Future<List<double>> chart(
    String id,
    String currency,
    int days,
  ) async {
    final uri = Uri.https(host, '/api/v3/coins/$id/market_chart', {
      'vs_currency': currency,
      'days': '$days',
    });
    final response = await http.get(uri).timeout(const Duration(seconds: 25));
    if (response.statusCode != 200) throw Exception('Grafik nije dostupan');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final prices = data['prices'] as List<dynamic>? ?? [];
    return prices
        .map((item) => ((item as List<dynamic>)[1] as num).toDouble())
        .toList();
  }

  static Future<Map<String, dynamic>> fearGreed() async {
    final response = await http
        .get(Uri.parse('https://api.alternative.me/fng/?limit=1'))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) throw Exception('Nije dostupno');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['data'] as List<dynamic>).first as Map<String, dynamic>;
  }
}

class HomePage extends StatefulWidget {
  final ThemeMode themeMode;
  final String currency;
  final String accent;
  final Future<void> Function(ThemeMode) onThemeChanged;
  final Future<void> Function(String) onCurrencyChanged;
  final Future<void> Function(String) onAccentChanged;

  const HomePage({
    super.key,
    required this.themeMode,
    required this.currency,
    required this.accent,
    required this.onThemeChanged,
    required this.onCurrencyChanged,
    required this.onAccentChanged,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;
  bool _loading = true;
  String? _error;
  List<Coin> _market = [];
  List<Coin> _watchlist = [];
  List<String> _watchIds = ['bitcoin', 'ethereum', 'solana'];
  List<Holding> _holdings = [];
  List<AlertItem> _alerts = [];

  String get symbol {
    if (widget.currency == 'usd') return '\$';
    if (widget.currency == 'gbp') return '£';
    return '€';
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final prefs = await SharedPreferences.getInstance();
    _watchIds = prefs.getStringList('watchIds') ??
        ['bitcoin', 'ethereum', 'solana'];
    _holdings = (prefs.getStringList('holdings') ?? [])
        .map((item) => Holding.fromJson(
            jsonDecode(item) as Map<String, dynamic>))
        .toList();
    _alerts = (prefs.getStringList('alerts') ?? [])
        .map((item) => AlertItem.fromJson(
            jsonDecode(item) as Map<String, dynamic>))
        .toList();

    try {
      _market = await Api.markets(widget.currency);
      final map = <String, Coin>{for (final coin in _market) coin.id: coin};
      final watch = <Coin>[];
      for (final id in _watchIds) {
        if (map.containsKey(id)) {
          watch.add(map[id]!);
        } else {
          try {
            watch.add(await Api.coinById(id, widget.currency));
          } catch (_) {}
        }
      }
      _watchlist = watch;
      await _checkAlerts();
    } catch (error) {
      _error = '$error';
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('watchIds', _watchIds);
    await prefs.setStringList(
      'holdings',
      _holdings.map((item) => jsonEncode(item.toJson())).toList(),
    );
    await prefs.setStringList(
      'alerts',
      _alerts.map((item) => jsonEncode(item.toJson())).toList(),
    );
  }

  Future<void> _checkAlerts() async {
    final current = <String, double>{
      for (final coin in _watchlist) coin.id: coin.price
    };
    final hit = <AlertItem>[];
    for (final alert in _alerts) {
      double? price = current[alert.coinId];
      if (price == null) {
        try {
          price = (await Api.coinById(alert.coinId, widget.currency)).price;
        } catch (_) {}
      }
      if (price == null) continue;
      final triggered =
          alert.above ? price >= alert.target : price <= alert.target;
      if (triggered) hit.add(alert);
    }

    if (hit.isNotEmpty && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Aktivirani alarmi'),
            content: Text(
              hit
                  .map((item) =>
                      '${item.symbol.toUpperCase()}: ${item.above ? 'iznad' : 'ispod'} $symbol${item.target}')
                  .join('\n'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('U redu'),
              ),
            ],
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _marketPage(),
      _portfolioPage(),
      _analysisPage(),
      _alertsPage(),
      _settingsPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('MS Crypto Tracker Pro'),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorPage()
              : pages[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (value) => setState(() => _tab = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.show_chart),
            label: 'Tržište',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet),
            label: 'Portfolio',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome),
            label: 'Analiza',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications),
            label: 'Alarmi',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            label: 'Postavke',
          ),
        ],
      ),
    );
  }

  Widget _errorPage() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 64),
              const SizedBox(height: 12),
              const Text(
                'Nije moguće učitati tržišne podatke.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(_error ?? '', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _reload,
                icon: const Icon(Icons.refresh),
                label: const Text('Pokušaj ponovo'),
              ),
            ],
          ),
        ),
      );

  Widget _marketPage() => ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.search),
              title: const Text('Pretraži i dodaj valutu'),
              subtitle: const Text('Pretraga hiljada CoinGecko valuta'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _openSearch,
            ),
          ),
          const SizedBox(height: 8),
          Text('Watchlista', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          ..._watchlist.map(_coinTile),
          const SizedBox(height: 14),
          Text('Top tržište', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          ..._market.take(30).map(_coinTile),
        ],
      );

  Widget _coinTile(Coin coin) {
    final positive = coin.change24h >= 0;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage:
              coin.image.isEmpty ? null : NetworkImage(coin.image),
          child: coin.image.isEmpty
              ? Text(coin.symbol.isEmpty ? '?' : coin.symbol[0].toUpperCase())
              : null,
        ),
        title: Text('${coin.name} (${coin.symbol.toUpperCase()})'),
        subtitle: Text(
          '${positive ? '+' : ''}${coin.change24h.toStringAsFixed(2)}% / 24h',
          style: TextStyle(
            color: positive ? Colors.green : Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
        trailing: Text(_money(coin.price)),
        onTap: () => _openCoin(coin),
        onLongPress: _watchIds.contains(coin.id)
            ? () async {
                _watchIds.remove(coin.id);
                _watchlist.removeWhere((item) => item.id == coin.id);
                await _save();
                if (mounted) setState(() {});
              }
            : null,
      ),
    );
  }

  Future<void> _openSearch() async {
    final result = await showSearch<SearchCoin?>(
      context: context,
      delegate: CoinSearchDelegate(),
    );
    if (result == null || _watchIds.contains(result.id)) return;

    try {
      final coin = await Api.coinById(result.id, widget.currency);
      _watchIds.add(result.id);
      _watchlist.add(coin);
      await _save();
      if (mounted) setState(() {});
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _openCoin(Coin coin) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => CoinPage(
          coin: coin,
          currency: widget.currency,
          currencySymbol: symbol,
          onHoldingAdded: (holding) async {
            _holdings.add(holding);
            await _save();
            if (mounted) setState(() {});
          },
          onAlertAdded: (alert) async {
            _alerts.add(alert);
            await _save();
            if (mounted) setState(() {});
          },
        ),
      ),
    );
  }

  Widget _portfolioPage() {
    double value = 0;
    double invested = 0;

    for (final holding in _holdings) {
      Coin? coin;
      for (final item in [..._watchlist, ..._market]) {
        if (item.id == holding.coinId) {
          coin = item;
          break;
        }
      }
      value += (coin?.price ?? 0) * holding.amount;
      invested += holding.buyPrice * holding.amount;
    }

    final pnl = value - invested;
    final percent = invested == 0 ? 0.0 : pnl / invested * 100;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Vrijednost portfolija'),
                const SizedBox(height: 6),
                Text(
                  _money(value),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                Text('Uloženo: ${_money(invested)}'),
                Text(
                  'P/L: ${pnl >= 0 ? '+' : ''}${_money(pnl)} '
                  '(${percent >= 0 ? '+' : ''}${percent.toStringAsFixed(2)}%)',
                  style: TextStyle(
                    color: pnl >= 0 ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_holdings.isEmpty)
          const Card(
            child: ListTile(
              title: Text('Portfolio je prazan'),
              subtitle: Text('Otvori valutu i dodaj kupovinu.'),
            ),
          ),
        ..._holdings.asMap().entries.map((entry) {
          final holding = entry.value;
          return Card(
            child: ListTile(
              title: Text(
                '${holding.name} • ${holding.amount} ${holding.symbol.toUpperCase()}',
              ),
              subtitle: Text('Kupovna cijena: ${_money(holding.buyPrice)}'),
              trailing: IconButton(
                onPressed: () async {
                  _holdings.removeAt(entry.key);
                  await _save();
                  if (mounted) setState(() {});
                },
                icon: const Icon(Icons.delete),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _analysisPage() => ListView(
        padding: const EdgeInsets.all(12),
        children: [
          FutureBuilder<Map<String, dynamic>>(
            future: Api.fearGreed(),
            builder: (context, snapshot) {
              final value =
                  int.tryParse('${snapshot.data?['value'] ?? 0}') ?? 0;
              final label = '${snapshot.data?['value_classification'] ?? ''}';
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Fear & Greed Index'),
                      const SizedBox(height: 8),
                      Text(
                        snapshot.hasData ? '$value/100 • $label' : 'Učitavanje…',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      if (snapshot.hasData)
                        LinearProgressIndicator(value: value / 100),
                    ],
                  ),
                ),
              );
            },
          ),
          const Card(
            child: ListTile(
              leading: Icon(Icons.psychology_alt),
              title: Text('Tehnička AI procjena'),
              subtitle: Text(
                'Otvori valutu za RSI, SMA, momentum i informativni trend signal.',
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.candlestick_chart),
              title: const Text('TradingView'),
              subtitle: const Text('Otvori profesionalne kripto grafikone'),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => launchUrl(
                Uri.parse(
                    'https://www.tradingview.com/markets/cryptocurrencies/'),
                mode: LaunchMode.externalApplication,
              ),
            ),
          ),
          const Card(
            child: ListTile(
              leading: Icon(Icons.warning_amber),
              title: Text('Napomena'),
              subtitle: Text(
                'Analiza nije finansijski savjet niti garantovana prognoza cijene.',
              ),
            ),
          ),
        ],
      );

  Widget _alertsPage() => ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Alarmi'),
              subtitle: Text(
                'Provjeravaju se kada otvoriš ili osvježiš aplikaciju.',
              ),
            ),
          ),
          if (_alerts.isEmpty)
            const Card(
              child: ListTile(
                title: Text('Nema alarma'),
                subtitle: Text('Otvori valutu i dodaj ciljnu cijenu.'),
              ),
            ),
          ..._alerts.asMap().entries.map((entry) {
            final alert = entry.value;
            return Card(
              child: ListTile(
                title: Text(alert.symbol.toUpperCase()),
                subtitle: Text(
                  '${alert.above ? 'Iznad' : 'Ispod'} ${_money(alert.target)}',
                ),
                trailing: IconButton(
                  onPressed: () async {
                    _alerts.removeAt(entry.key);
                    await _save();
                    if (mounted) setState(() {});
                  },
                  icon: const Icon(Icons.delete),
                ),
              ),
            );
          }),
        ],
      );

  Widget _settingsPage() => ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text('Tema', style: Theme.of(context).textTheme.titleLarge),
          Card(
            child: Column(
              children: [
                RadioListTile<ThemeMode>(
                  value: ThemeMode.dark,
                  groupValue: widget.themeMode,
                  onChanged: (value) async {
                    if (value != null) await widget.onThemeChanged(value);
                  },
                  title: const Text('Tamna'),
                ),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.light,
                  groupValue: widget.themeMode,
                  onChanged: (value) async {
                    if (value != null) await widget.onThemeChanged(value);
                  },
                  title: const Text('Svijetla'),
                ),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.system,
                  groupValue: widget.themeMode,
                  onChanged: (value) async {
                    if (value != null) await widget.onThemeChanged(value);
                  },
                  title: const Text('Tema telefona'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text('Boja', style: Theme.of(context).textTheme.titleLarge),
          Card(
            child: Column(
              children: [
                for (final item in const {
                  'teal': 'Tirkizna',
                  'blue': 'Plava',
                  'green': 'Zelena',
                  'purple': 'Ljubičasta',
                }.entries)
                  RadioListTile<String>(
                    value: item.key,
                    groupValue: widget.accent,
                    onChanged: (value) async {
                      if (value != null) await widget.onAccentChanged(value);
                    },
                    title: Text(item.value),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text('Valuta', style: Theme.of(context).textTheme.titleLarge),
          Card(
            child: Column(
              children: [
                for (final item in const {
                  'eur': 'EUR (€)',
                  'usd': 'USD (\$)',
                  'gbp': 'GBP (£)',
                }.entries)
                  RadioListTile<String>(
                    value: item.key,
                    groupValue: widget.currency,
                    onChanged: (value) async {
                      if (value == null) return;
                      await widget.onCurrencyChanged(value);
                      await _reload();
                    },
                    title: Text(item.value),
                  ),
              ],
            ),
          ),
          const Card(
            child: ListTile(
              title: Text('MS Crypto Tracker Pro v3.1'),
              subtitle: Text('Podaci se čuvaju lokalno na telefonu.'),
            ),
          ),
        ],
      );

  String _money(double value) {
    final decimals = value.abs() < 1 ? 6 : 2;
    return '$symbol${value.toStringAsFixed(decimals)}';
  }
}

class CoinSearchDelegate extends SearchDelegate<SearchCoin?> {
  Timer? _timer;
  List<SearchCoin> _results = [];
  bool _loading = false;
  String? _error;

  @override
  String get searchFieldLabel => 'BTC, Aleo, Verum, Siren…';

  void _scheduleSearch() {
    _timer?.cancel();
    if (query.trim().length < 2) return;
    _timer = Timer(const Duration(milliseconds: 500), () async {
      _loading = true;
      _error = null;
      notifyListeners();
      try {
        _results = await Api.search(query);
      } catch (error) {
        _error = '$error';
        _results = [];
      }
      _loading = false;
      notifyListeners();
    });
  }

  Widget _body() {
    _scheduleSearch();
    if (query.trim().length < 2) {
      return const Center(child: Text('Upiši najmanje 2 znaka.'));
    }
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));
    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final coin = _results[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundImage:
                coin.image.isEmpty ? null : NetworkImage(coin.image),
          ),
          title: Text(coin.name),
          subtitle: Text(coin.symbol.toUpperCase()),
          trailing: const Icon(Icons.add_circle_outline),
          onTap: () => close(context, coin),
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) => _body();

  @override
  Widget buildResults(BuildContext context) => _body();

  @override
  List<Widget>? buildActions(BuildContext context) => [
        IconButton(onPressed: () => query = '', icon: const Icon(Icons.clear)),
      ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        onPressed: () => close(context, null),
        icon: const Icon(Icons.arrow_back),
      );
}

class CoinPage extends StatefulWidget {
  final Coin coin;
  final String currency;
  final String currencySymbol;
  final Future<void> Function(Holding) onHoldingAdded;
  final Future<void> Function(AlertItem) onAlertAdded;

  const CoinPage({
    super.key,
    required this.coin,
    required this.currency,
    required this.currencySymbol,
    required this.onHoldingAdded,
    required this.onAlertAdded,
  });

  @override
  State<CoinPage> createState() => _CoinPageState();
}

class _CoinPageState extends State<CoinPage> {
  int _days = 30;
  late Future<List<double>> _chart;

  @override
  void initState() {
    super.initState();
    _chart = Api.chart(widget.coin.id, widget.currency, _days);
  }

  void _setDays(int days) {
    setState(() {
      _days = days;
      _chart = Api.chart(widget.coin.id, widget.currency, _days);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(
              '${widget.coin.name} (${widget.coin.symbol.toUpperCase()})'),
        ),
        body: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _money(widget.coin.price),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    Text(
                      '${widget.coin.change24h >= 0 ? '+' : ''}'
                      '${widget.coin.change24h.toStringAsFixed(2)}% / 24h',
                      style: TextStyle(
                        color: widget.coin.change24h >= 0
                            ? Colors.green
                            : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(),
                    Text('Market cap: ${_compact(widget.coin.marketCap)}'),
                    Text('Volume: ${_compact(widget.coin.volume)}'),
                  ],
                ),
              ),
            ),
            Wrap(
              spacing: 6,
              children: [
                for (final days in const [1, 7, 30, 90, 365])
                  ChoiceChip(
                    label: Text(days == 1
                        ? '1D'
                        : days == 365
                            ? '1Y'
                            : '${days}D'),
                    selected: _days == days,
                    onSelected: (_) => _setDays(days),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            FutureBuilder<List<double>>(
              future: _chart,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 260,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final prices = snapshot.data ?? [];
                if (prices.length < 3) {
                  return const Card(
                    child: ListTile(title: Text('Grafik nije dostupan')),
                  );
                }
                return Column(
                  children: [
                    SizedBox(
                      height: 260,
                      child: CustomPaint(
                        painter: LineChartPainter(
                          prices: prices,
                          lineColor: Theme.of(context).colorScheme.primary,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    AnalysisCard(prices: prices),
                  ],
                );
              },
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.candlestick_chart),
                title: const Text('TradingView grafik'),
                trailing: const Icon(Icons.open_in_new),
                onTap: () async {
                  final pair = widget.coin.symbol.toUpperCase();
                  final uri = Uri.parse(
                    'https://www.tradingview.com/chart/?symbol=BINANCE%3A${pair}USDT',
                  );
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                },
              ),
            ),
            FilledButton.icon(
              onPressed: _addHolding,
              icon: const Icon(Icons.account_balance_wallet),
              label: const Text('Dodaj u portfolio'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _addAlert,
              icon: const Icon(Icons.notifications),
              label: const Text('Dodaj alarm'),
            ),
          ],
        ),
      );

  Future<void> _addHolding() async {
    final amount = TextEditingController();
    final price = TextEditingController(text: '${widget.coin.price}');
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dodaj u portfolio'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Količina'),
            ),
            TextField(
              controller: price,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Kupovna cijena'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Otkaži'),
          ),
          FilledButton(
            onPressed: () async {
              final parsedAmount =
                  double.tryParse(amount.text.replaceAll(',', '.'));
              final parsedPrice =
                  double.tryParse(price.text.replaceAll(',', '.'));
              if (parsedAmount == null ||
                  parsedPrice == null ||
                  parsedAmount <= 0) {
                return;
              }
              await widget.onHoldingAdded(
                Holding(
                  coinId: widget.coin.id,
                  name: widget.coin.name,
                  symbol: widget.coin.symbol,
                  amount: parsedAmount,
                  buyPrice: parsedPrice,
                ),
              );
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Sačuvaj'),
          ),
        ],
      ),
    );
  }

  Future<void> _addAlert() async {
    final target = TextEditingController(text: '${widget.coin.price}');
    bool above = true;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Alarm cijene'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Iznad')),
                  ButtonSegment(value: false, label: Text('Ispod')),
                ],
                selected: {above},
                onSelectionChanged: (value) =>
                    setDialogState(() => above = value.first),
              ),
              TextField(
                controller: target,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Ciljna cijena'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Otkaži'),
            ),
            FilledButton(
              onPressed: () async {
                final value =
                    double.tryParse(target.text.replaceAll(',', '.'));
                if (value == null || value <= 0) return;
                await widget.onAlertAdded(
                  AlertItem(
                    id: '${DateTime.now().microsecondsSinceEpoch}',
                    coinId: widget.coin.id,
                    symbol: widget.coin.symbol,
                    target: value,
                    above: above,
                  ),
                );
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Sačuvaj'),
            ),
          ],
        ),
      ),
    );
  }

  String _money(double value) {
    final decimals = value.abs() < 1 ? 8 : 2;
    return '${widget.currencySymbol}${value.toStringAsFixed(decimals)}';
  }

  String _compact(double value) {
    if (value >= 1000000000) {
      return '${widget.currencySymbol}${(value / 1000000000).toStringAsFixed(2)}B';
    }
    if (value >= 1000000) {
      return '${widget.currencySymbol}${(value / 1000000).toStringAsFixed(2)}M';
    }
    if (value >= 1000) {
      return '${widget.currencySymbol}${(value / 1000).toStringAsFixed(2)}K';
    }
    return _money(value);
  }
}

class LineChartPainter extends CustomPainter {
  final List<double> prices;
  final Color lineColor;

  const LineChartPainter({
    required this.prices,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (prices.length < 2) return;

    double minValue = prices.first;
    double maxValue = prices.first;
    for (final value in prices) {
      if (value < minValue) minValue = value;
      if (value > maxValue) maxValue = value;
    }

    final range = maxValue - minValue;
    final safeRange = range == 0 ? 1.0 : range;
    final path = Path();

    for (int i = 0; i < prices.length; i++) {
      final x = i / (prices.length - 1) * size.width;
      final normalized = (prices[i] - minValue) / safeRange;
      final y = size.height - normalized * (size.height - 20) - 10;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final gridPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.15)
      ..strokeWidth = 1;

    for (int i = 1; i < 5; i++) {
      final y = size.height / 5 * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant LineChartPainter oldDelegate) {
    return oldDelegate.prices != prices || oldDelegate.lineColor != lineColor;
  }
}

class AnalysisCard extends StatelessWidget {
  final List<double> prices;

  const AnalysisCard({super.key, required this.prices});

  @override
  Widget build(BuildContext context) {
    final result = calculateAnalysis(prices);
    final color = result['signal'] == 'Bikovski'
        ? Colors.green
        : result['signal'] == 'Medvjeđi'
            ? Colors.red
            : Colors.orange;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AI tehnička procjena',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '${result['signal']} signal',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(color: color, fontWeight: FontWeight.bold),
            ),
            Text('RSI: ${(result['rsi'] as double).toStringAsFixed(1)}'),
            Text(
              'Momentum: ${(result['momentum'] as double).toStringAsFixed(2)}%',
            ),
            Text(
              'Pouzdanost: ${result['confidence']}%',
            ),
            const SizedBox(height: 8),
            const Text(
              'Informativno. Nije finansijski savjet niti garantovana prognoza.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

Map<String, dynamic> calculateAnalysis(List<double> prices) {
  if (prices.length < 15) {
    return {
      'signal': 'Neutralan',
      'rsi': 50.0,
      'momentum': 0.0,
      'confidence': 20,
    };
  }

  final lookback = prices.length - 1 < 14 ? prices.length - 1 : 14;
  double gains = 0;
  double losses = 0;

  for (int i = prices.length - lookback; i < prices.length; i++) {
    final diff = prices[i] - prices[i - 1];
    if (diff >= 0) {
      gains += diff;
    } else {
      losses += diff.abs();
    }
  }

  final avgGain = gains / lookback;
  final avgLoss = losses / lookback;
  final rsi =
      avgLoss == 0 ? 100.0 : 100 - (100 / (1 + avgGain / avgLoss));

  final baseIndex = prices.length > 30 ? prices.length - 30 : 0;
  final base = prices[baseIndex];
  final momentum = base == 0 ? 0.0 : (prices.last - base) / base * 100;

  String signal = 'Neutralan';
  int confidence = 50;

  if (rsi < 35 && momentum > 0) {
    signal = 'Bikovski';
    confidence = 70;
  } else if (rsi > 70 && momentum < 0) {
    signal = 'Medvjeđi';
    confidence = 70;
  } else if (momentum > 4) {
    signal = 'Bikovski';
    confidence = 60;
  } else if (momentum < -4) {
    signal = 'Medvjeđi';
    confidence = 60;
  }

  return {
    'signal': signal,
    'rsi': rsi,
    'momentum': momentum,
    'confidence': confidence,
  };
}
