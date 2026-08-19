import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';

/// Shown while auth state / the `users/{uid}` profile doc is still
/// resolving. The router redirects away from here automatically once
/// `authStateChangesProvider` and `currentAppUserProvider` settle.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [
                    const Color(0xFF0B1220),
                    const Color(0xFF070B14),
                  ]
                : [
                    const Color(0xFFF8FAFC),
                    const Color(0xFFEFF6FF),
                  ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Center Branding
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Animated-like Logo container
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.card * 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: colors.cardShadow.withValues(alpha: 0.15),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.card * 1.5),
                        child: Image.asset(
                          'assets/images/app_icon.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // App Name
                    Text(
                      'İş Takip',
                      style: GoogleFonts.lexend(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: theme.textTheme.displayLarge?.color,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    // Subtitle/Tagline
                    Text(
                      'Personel & Tahsilat Yönetimi',
                      style: GoogleFonts.sourceSans3(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              // Bottom loader & Version info
              Positioned(
                bottom: 48,
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'v1.0.0',
                      style: GoogleFonts.sourceSans3(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
