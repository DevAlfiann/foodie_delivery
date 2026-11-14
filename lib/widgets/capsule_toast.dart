import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

/// Notifikasi Kapsul Melayang (Capsule Toast)
/// - Bentuk kapsul/pill modern dengan ambient glow & micro-border
/// - Animasi mulus: meluncur dari bawah ke atas (smooth slide-up), lalu meluncur kembali ke bawah
/// - Otomatis hilang dalam 3 detik
/// - Jika ada interaksi/pergerakan layar, dapat ditutup secara instan & lebih cepat
class CapsuleToast {
  static OverlayEntry? _currentEntry;
  static _CapsuleToastWidgetState? _currentState;
  static Timer? _dismissTimer;

  static void show(
    BuildContext context, {
    String? title,
    String? message,
    String? subtitle,
    IconData icon = Icons.check_circle_rounded,
    Color iconColor = Colors.white,
    Color? backgroundColor,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 5),
    double bottomMargin = 100.0,
  }) {
    final effectiveTitle = title ?? message ?? '';
    // Tutup toast sebelumnya terlebih dahulu agar tidak bertumpuk
    dismiss(fast: true);

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    final entry = OverlayEntry(
      builder: (context) {
        return _CapsuleToastWidget(
          title: effectiveTitle,
          subtitle: subtitle,
          icon: icon,
          iconColor: iconColor,
          backgroundColor: backgroundColor,
          actionLabel: actionLabel,
          onAction: onAction,
          bottomMargin: bottomMargin,
          onMounted: (state) => _currentState = state,
        );
      },
    );

    _currentEntry = entry;
    overlay.insert(entry);

    // Otomatis hilang dalam durasi tertentu (default 3 detik)
    _dismissTimer?.cancel();
    _dismissTimer = Timer(duration, () {
      dismiss(fast: false);
    });
  }

  /// Menutup toast dengan animasi meluncur ke bawah
  /// fast: true untuk menutup lebih cepat (140ms) saat ada pergerakan layar
  static void dismiss({bool fast = false}) {
    _dismissTimer?.cancel();
    _dismissTimer = null;

    if (_currentState != null) {
      final state = _currentState!;
      _currentState = null;
      state.hide(fast: fast).then((_) {
        _currentEntry?.remove();
        _currentEntry = null;
      });
    } else {
      _currentEntry?.remove();
      _currentEntry = null;
    }
  }

  /// Helper untuk mendeteksi apakah ada toast yang sedang tampil
  static bool get isVisible => _currentEntry != null;
}

class _CapsuleToastWidget extends StatefulWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color iconColor;
  final Color? backgroundColor;
  final String? actionLabel;
  final VoidCallback? onAction;
  final double bottomMargin;
  final void Function(_CapsuleToastWidgetState state) onMounted;

  const _CapsuleToastWidget({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.iconColor,
    this.backgroundColor,
    this.actionLabel,
    this.onAction,
    required this.bottomMargin,
    required this.onMounted,
  });

  @override
  State<_CapsuleToastWidget> createState() => _CapsuleToastWidgetState();
}

class _CapsuleToastWidgetState extends State<_CapsuleToastWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    widget.onMounted(this);

    // Animasi muncul sangat smooth (360ms) dengan bounce lembut
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
      reverseDuration: const Duration(milliseconds: 260),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 1.6), // Muncul dari arah bawah
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    ));

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );

    _scaleAnimation = Tween<double>(begin: 0.90, end: 1.0).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeIn,
    ));

    _controller.forward();
  }

  /// Fungsi untuk menyembunyikan notifikasi dengan animasi ke bawah
  Future<void> hide({bool fast = false}) async {
    if (!mounted) return;
    if (fast) {
      _controller.reverseDuration = const Duration(milliseconds: 140);
    } else {
      _controller.reverseDuration = const Duration(milliseconds: 260);
    }
    await _controller.reverse();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: widget.bottomMargin,
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: child,
                    ),
                  ),
                );
              },
              child: _buildCapsuleBody(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCapsuleBody() {
    final bg = widget.backgroundColor ?? const Color(0xFF0F5A31);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            bg,
            Color.lerp(bg, const Color(0xFF1E824C), 0.4) ?? bg,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32), // Bentuk capsul sempurna
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.28),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: bg.withValues(alpha: 0.45),
            blurRadius: 18,
            offset: const Offset(0, 6),
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ikon Lingkaran
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.20),
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.icon,
                color: widget.iconColor,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),

            // Teks Pesan (Title & Subtitle)
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      widget.subtitle!,
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.secondaryContainer,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            // Tombol Aksi (Opsional: e.g. "KERANJANG", "LIHAT")
            if (widget.actionLabel != null) ...[
              const SizedBox(width: 10),
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  CapsuleToast.dismiss(fast: true);
                  widget.onAction?.call();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.actionLabel!,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(Icons.arrow_forward_rounded, size: 12, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
