import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Payload yang diterima dari deeplink pembayaran merchant.
///
/// Format URL yang didukung:
///   dompetkampus://pay?merchant_id=...&merchant_name=...&amount=...
///                      &description=...&reference=...&callback=...
///   https://dompetkampus.app/pay?merchant_id=...&...  (App Link, opsional)
@immutable
class DeeplinkPaymentData {
  final String merchantId;
  final String merchantName;
  final double amount;
  final String description;
  final String? reference;
  final String? callbackUrl;

  const DeeplinkPaymentData({
    required this.merchantId,
    required this.merchantName,
    required this.amount,
    required this.description,
    this.reference,
    this.callbackUrl,
  });

  factory DeeplinkPaymentData.fromUri(Uri uri) {
    final q = uri.queryParameters;

    final merchantId   = q['merchant_id'];
    final merchantName = q['merchant_name'];
    final amountStr    = q['amount'];

    if (merchantId == null || merchantId.trim().isEmpty) {
      throw const FormatException('Link pembayaran tidak valid: merchant_id tidak ditemukan.');
    }
    if (merchantName == null || merchantName.trim().isEmpty) {
      throw const FormatException('Link pembayaran tidak valid: merchant_name tidak ditemukan.');
    }
    if (amountStr == null || amountStr.trim().isEmpty) {
      throw const FormatException('Link pembayaran tidak valid: amount tidak ditemukan.');
    }

    final amount = double.tryParse(amountStr);
    if (amount == null || amount <= 0) {
      throw const FormatException('Link pembayaran tidak valid: amount harus berupa angka > 0.');
    }

    return DeeplinkPaymentData(
      merchantId:   merchantId,
      merchantName: merchantName,
      amount:       amount,
      description:  q['description']?.trim().isNotEmpty == true
          ? q['description']!.trim()
          : 'Pembayaran ke $merchantName',
      reference:   q['reference'],
      callbackUrl: q['callback'],
    );
  }
}

/// Mendengarkan deeplink pembayaran dan mengarahkan ke halaman /pay.
///
/// ## Dua skenario yang ditangani berbeda:
///
/// **Cold-start** (app dibuka via deeplink dari keadaan mati):
///   `getInitialLink()` dipanggil sebelum `runApp()` sehingga GoRouter
///   belum ter-mount. URI disimpan di [_pendingPayload] dan TIDAK langsung
///   dinavigasi. SplashPage mengambilnya via [consumePending()] setelah
///   autentikasi selesai.
///
/// **In-app** (deeplink masuk saat app sudah berjalan):
///   GoRouter sudah ter-mount → `router.go('/pay')` langsung dijalankan.
class DeeplinkService {
  final GoRouter _router;
  final AppLinks _appLinks;
  StreamSubscription<Uri>? _subscription;

  // URI yang menunggu diproses setelah SplashPage selesai auth check.
  static Uri? _pendingUri;

  /// Ambil dan hapus pending URI (dipanggil dari SplashPage).
  /// Mengembalikan null jika tidak ada deeplink yang menunggu.
  static Uri? consumePending() {
    final uri = _pendingUri;
    _pendingUri = null;
    debugPrint('[DeeplinkService] consumePending: $uri');
    return uri;
  }

  static bool get hasPending => _pendingUri != null;

  DeeplinkService(this._router) : _appLinks = AppLinks();

  Future<void> init() async {
    debugPrint('[DeeplinkService] init() dipanggil');

    // Cold-start: simpan URI sebagai pending, JANGAN navigasi sekarang
    // karena GoRouter belum ter-mount (runApp belum dipanggil).
    try {
      final initialUri = await _appLinks.getInitialLink();
      debugPrint('[DeeplinkService] initialUri (cold-start): $initialUri');
      if (initialUri != null && _isPaymentLink(initialUri)) {
        _storePending(initialUri);
      }
    } catch (e) {
      debugPrint('[DeeplinkService] getInitialLink error: $e');
    }

    // In-app: navigasi via post-frame setelah GoRouter ter-mount.
    _subscription = _appLinks.uriLinkStream.listen(
      _handleInAppUri,
      onError: (e) => debugPrint('[DeeplinkService] stream error: $e'),
      onDone: () => debugPrint('[DeeplinkService] stream DITUTUP (seharusnya tidak terjadi)'),
    );
    debugPrint('[DeeplinkService] uriLinkStream aktif — subscription: $_subscription');
  }

  /// Simpan URI cold-start sebagai pending (belum navigasi).
  void _storePending(Uri uri) {
    _pendingUri = uri;
    debugPrint('[DeeplinkService] Pending URI tersimpan: $uri');
  }

  /// Handle URI in-app: GoRouter sudah mounted, jadwalkan navigasi ke /pay
  /// di post-frame agar tidak konflik dengan state GoRouter yang sedang update.
  void _handleInAppUri(Uri uri) {
    debugPrint('[DeeplinkService] *** IN-APP URI DITERIMA ***: $uri');
    if (!_isPaymentLink(uri)) {
      debugPrint('[DeeplinkService] Bukan payment link, diabaikan.');
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('[DeeplinkService] router.go("/pay?${uri.query}") dieksekusi');
      _router.go('/pay?${uri.query}');
    });
  }

  bool _isPaymentLink(Uri uri) {
    if (uri.scheme == 'dompetkampus' && uri.host == 'pay') return true;
    if (uri.scheme == 'https' &&
        uri.host == 'dompetkampus.app' &&
        uri.path.startsWith('/pay')) {
      return true;
    }
    return false;
  }

  void dispose() => _subscription?.cancel();
}
