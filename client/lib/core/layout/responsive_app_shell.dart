import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../theme/app_colors.dart';

class ResponsiveAppShell extends StatelessWidget {
  const ResponsiveAppShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop =
            constraints.maxWidth >= AppConstants.desktopBreakpoint;
        final horizontalInset =
            constraints.maxWidth < AppConstants.responsiveBreakpoint
            ? 0.0
            : isDesktop
            ? AppConstants.desktopContentInset
            : AppConstants.tabletContentInset;
        final availableWidth = math.max(
          0.0,
          constraints.maxWidth - (horizontalInset * 2),
        );
        final panelWidth = isDesktop
            ? math.min(
                availableWidth,
                constraints.maxWidth * AppConstants.desktopContentFraction,
              )
            : availableWidth;
        final minPanelHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : 0.0;

        return ColoredBox(
          color: AppColors.background,
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalInset),
              child: SizedBox(
                width: panelWidth,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: AppConstants.wideContentMaxWidth,
                    minHeight: minPanelHeight,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: isDesktop
                          ? BorderRadius.circular(AppConstants.radiusLg)
                          : BorderRadius.zero,
                      border: isDesktop
                          ? Border.all(color: AppColors.lightBorder)
                          : null,
                      boxShadow: isDesktop
                          ? const [
                              BoxShadow(
                                color: Color(0x0A161616),
                                blurRadius: 18,
                                offset: Offset(0, 6),
                              ),
                            ]
                          : null,
                    ),
                    child: ClipRRect(
                      borderRadius: isDesktop
                          ? BorderRadius.circular(AppConstants.radiusLg)
                          : BorderRadius.zero,
                      child: SizedBox(width: double.infinity, child: child),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
