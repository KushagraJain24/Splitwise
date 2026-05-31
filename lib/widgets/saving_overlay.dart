import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:splitwise/utils/constants.dart';

class SavingOverlay extends StatelessWidget {
  final Widget child;
  final bool isSaving;
  final String message;

  const SavingOverlay({
    super.key,
    required this.child,
    required this.isSaving,
    this.message = 'Saving changes...',
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isSaving)
          Positioned.fill(
            child: GestureDetector(
              onTap: () {}, // Prevent taps
              behavior: HitTestBehavior.opaque,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: Container(
                  color: AppConstants.backgroundDark.withOpacity(0.5),
                  child: Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Material(
                          color: Colors.transparent,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                            decoration: AppConstants.glassDecoration(
                              color: Colors.white,
                              opacity: 0.05,
                              borderRadius: 20,
                              borderOpacity: 0.1,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(AppConstants.accentTeal),
                                  strokeWidth: 3.5,
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  message,
                                  style: const TextStyle(
                                    color: AppConstants.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
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
