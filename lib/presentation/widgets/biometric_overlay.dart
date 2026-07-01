import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/services/biometric_service.dart';
import '../../core/theme/app_colors.dart';

class BiometricOverlay extends StatefulWidget {
  final Widget child;

  const BiometricOverlay({super.key, required this.child});

  @override
  State<BiometricOverlay> createState() => _BiometricOverlayState();
}

class _BiometricOverlayState extends State<BiometricOverlay>
    with WidgetsBindingObserver {
  bool _isLocked = false;
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkInitialLock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // 🔥 Cek apakah saat awal masuk (cold start) harus langsung terkunci
  Future<void> _checkInitialLock() async {
    final user = FirebaseAuth.instance.currentUser;
    final isBiometricEnabled = await BiometricService.isBiometricEnabled();

    if (user != null && isBiometricEnabled) {
      setState(() {
        _isLocked = true;
      });
      _authenticate();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    final user = FirebaseAuth.instance.currentUser;
    final isBiometricEnabled = await BiometricService.isBiometricEnabled();

    if (user == null || !isBiometricEnabled) return;

    // 🔥 Kunci layar segera setelah aplikasi masuk ke background
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (!_isLocked) {
        setState(() {
          _isLocked = true;
        });
      }
    }

    // 🔥 Minta sidik jari ketika aplikasi kembali aktif (resumed)
    if (state == AppLifecycleState.resumed && _isLocked) {
      _authenticate();
    }
  }

  // 🔥 Fungsi untuk memicu otentikasi biometrik
  Future<void> _authenticate() async {
    if (_isAuthenticating) return;

    setState(() {
      _isAuthenticating = true;
    });

    final success = await BiometricService.authenticate();

    if (success) {
      setState(() {
        _isLocked = false;
      });
    }

    setState(() {
      _isAuthenticating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLocked) {
      return widget.child;
    }

    // Tampilan Layar Kunci Biometrik yang Premium
    return Stack(
      children: [
        // Widget aplikasi asli di belakangnya tetap di-render tapi dihalangi
        widget.child,

        // Layer Kunci Pengaman
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient, // 🔥 Ubah ke gradient sesuai logo/tema
            ),
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(),
                      // Icon Gembok / Sidik Jari dengan Efek Glowing Putih
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.15),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.4),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.fingerprint_rounded,
                          size: 56,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        'Aplikasi Terkunci',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Silakan gunakan sidik jari atau Face ID Anda untuk membuka akses Dompet Ku.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 14,
                          color: Colors.white70,
                          height: 1.5,
                        ),
                      ),
                      const Spacer(),
                      // Button untuk Coba Lagi jika dialog tertutup
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _authenticate,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white, // 🔥 Tombol putih kontras dengan gradient
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: _isAuthenticating
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: AppColors.primary,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.lock_open_rounded, color: AppColors.primary),
                          label: Text(
                            _isAuthenticating ? 'Menunggu Sidik Jari...' : 'Buka Kunci',
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
