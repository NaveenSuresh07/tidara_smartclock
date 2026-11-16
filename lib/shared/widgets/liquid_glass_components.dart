import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/tidara_palette.dart';
import '../../features/shell/cubit/app_preferences_cubit.dart';

/// Resolves whether high contrast mode is active from explicit override,
/// [MediaQuery], or [AppPreferencesCubit].
bool resolveHighContrastMode(BuildContext context, {bool? explicit}) {
  if (explicit != null) return explicit;
  try {
    if (MediaQuery.highContrastOf(context)) return true;
  } catch (_) {}
  try {
    final prefCubit = context.read<AppPreferencesCubit?>();
    if (prefCubit != null) {
      return prefCubit.state.highContrastMode;
    }
  } catch (_) {}
  return false;
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final double blurSigma;
  final bool isElevated;
  final bool useBackdropBlur;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final bool? isHighContrast;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.blurSigma = 20.0,
    this.isElevated = false,
    this.useBackdropBlur = true,
    this.onTap,
    this.semanticLabel,
    this.isHighContrast,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool highContrast = resolveHighContrastMode(
      context,
      explicit: isHighContrast,
    );

    if (highContrast) {
      Widget cardSurface = Container(
        padding: padding,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF24201C) : const Color(0xFFFFFFFF),
          borderRadius: borderRadius,
          border: Border.all(
            color: isDark ? Colors.white : const Color(0xFF1C1917),
            width: isElevated ? 2.0 : 1.5,
          ),
        ),
        child: child,
      );

      if (onTap != null) {
        cardSurface = InkWell(
          borderRadius: borderRadius,
          onTap: onTap,
          child: cardSurface,
        );
      }

      if (semanticLabel != null) {
        return Semantics(
          label: semanticLabel,
          button: onTap != null,
          child: cardSurface,
        );
      }
      return cardSurface;
    }

    final topAlpha = isDark
        ? (isElevated ? 0.22 : 0.14)
        : (isElevated ? 0.82 : 0.68);
    final bottomAlpha = isDark
        ? (isElevated ? 0.10 : 0.06)
        : (isElevated ? 0.54 : 0.42);
    final borderAlpha = isDark
        ? (isElevated ? 0.38 : 0.22)
        : (isElevated ? 0.90 : 0.72);

    final Color borderColor = isDark
        ? Colors.white.withValues(alpha: borderAlpha)
        : (isElevated
              ? const Color(0xFF8C8477).withValues(alpha: 0.55)
              : const Color(0xFFB5AC99).withValues(alpha: 0.40));

    Widget cardSurface = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: topAlpha),
            Colors.white.withValues(alpha: bottomAlpha),
          ],
        ),
        border: Border.all(color: borderColor, width: isElevated ? 1.4 : 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.07),
            blurRadius: isElevated ? 22 : 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );

    Widget content = ClipRRect(
      borderRadius: borderRadius,
      child: useBackdropBlur
          ? BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
              child: cardSurface,
            )
          : cardSurface,
    );

    if (onTap != null) {
      content = Semantics(
        button: true,
        label: semanticLabel,
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap!();
          },
          child: content,
        ),
      );
    } else if (semanticLabel != null) {
      content = Semantics(label: semanticLabel, child: content);
    }
    return content;
  }
}

enum GlassButtonVariant {
  primary,
  secondary,
  destructive,
  iconOnly,
  chip,
  highEmphasisPill,
  largeCta,
}

class GlassButton extends StatefulWidget {
  final String? label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final GlassButtonVariant variant;
  final bool isPrimary;
  final bool isDestructive;
  final bool isSelected;
  final bool isLoading;
  final bool useBackdropBlur;
  final double blurSigma;
  final Color? accentColor;
  final Color? customBackgroundColor;
  final Color? customBorderColor;
  final Color? customTextColor;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final double? width;
  final double? height;
  final double minWidth;
  final double minHeight;
  final String? semanticLabel;
  final String? tooltip;
  final bool isCircle;
  final Widget? child;
  final Widget? customChild;
  final TextStyle? textStyle;
  final double? iconSize;
  final Color? iconColor;
  final bool? isHighContrast;
  final TidaraPalette? palette;

  const GlassButton({
    super.key,
    this.label,
    this.icon,
    this.onPressed,
    this.variant = GlassButtonVariant.secondary,
    this.isPrimary = false,
    this.isDestructive = false,
    this.isSelected = false,
    this.isLoading = false,
    this.useBackdropBlur = false,
    this.blurSigma = 10.0,
    this.accentColor,
    this.customBackgroundColor,
    this.customBorderColor,
    this.customTextColor,
    this.padding,
    this.borderRadius,
    this.width,
    this.height,
    this.minWidth = 48.0,
    this.minHeight = 48.0,
    this.semanticLabel,
    this.tooltip,
    this.isCircle = false,
    this.child,
    this.customChild,
    this.textStyle,
    this.iconSize,
    this.iconColor,
    this.isHighContrast,
    this.palette,
  });

  const GlassButton.primary({
    super.key,
    this.label,
    this.icon,
    this.onPressed,
    this.isLoading = false,
    this.useBackdropBlur = false,
    this.blurSigma = 10.0,
    this.accentColor,
    this.customBackgroundColor,
    this.customBorderColor,
    this.customTextColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    this.borderRadius,
    this.width,
    this.height,
    this.minWidth = 48.0,
    this.minHeight = 48.0,
    this.semanticLabel,
    this.tooltip,
    this.isCircle = false,
    this.child,
    this.customChild,
    this.textStyle,
    this.iconSize,
    this.iconColor,
    this.isHighContrast,
    this.palette,
  }) : variant = GlassButtonVariant.primary,
       isPrimary = true,
       isDestructive = false,
       isSelected = false;

  const GlassButton.secondary({
    super.key,
    this.label,
    this.icon,
    this.onPressed,
    this.isLoading = false,
    this.useBackdropBlur = false,
    this.blurSigma = 10.0,
    this.accentColor,
    this.customBackgroundColor,
    this.customBorderColor,
    this.customTextColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    this.borderRadius,
    this.width,
    this.height,
    this.minWidth = 48.0,
    this.minHeight = 48.0,
    this.semanticLabel,
    this.tooltip,
    this.isCircle = false,
    this.child,
    this.customChild,
    this.textStyle,
    this.iconSize,
    this.iconColor,
    this.isHighContrast,
    this.palette,
  }) : variant = GlassButtonVariant.secondary,
       isPrimary = false,
       isDestructive = false,
       isSelected = false;

  const GlassButton.destructive({
    super.key,
    this.label,
    this.icon,
    this.onPressed,
    this.isLoading = false,
    this.useBackdropBlur = false,
    this.blurSigma = 10.0,
    this.accentColor,
    this.customBackgroundColor,
    this.customBorderColor,
    this.customTextColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    this.borderRadius,
    this.width,
    this.height,
    this.minWidth = 48.0,
    this.minHeight = 48.0,
    this.semanticLabel,
    this.tooltip,
    this.isCircle = false,
    this.child,
    this.customChild,
    this.textStyle,
    this.iconSize,
    this.iconColor,
    this.isHighContrast,
    this.palette,
  }) : variant = GlassButtonVariant.destructive,
       isPrimary = false,
       isDestructive = true,
       isSelected = false;

  const GlassButton.iconOnly({
    super.key,
    required IconData this.icon,
    this.onPressed,
    required String this.semanticLabel,
    this.tooltip,
    this.isPrimary = false,
    this.isDestructive = false,
    this.isSelected = false,
    this.isLoading = false,
    this.useBackdropBlur = false,
    this.blurSigma = 10.0,
    this.accentColor,
    this.customBackgroundColor,
    this.customBorderColor,
    this.customTextColor,
    this.padding,
    this.borderRadius,
    this.width,
    this.height,
    this.minWidth = 48.0,
    this.minHeight = 48.0,
    this.isCircle = true,
    this.child,
    this.customChild,
    this.textStyle,
    this.iconSize,
    this.iconColor,
    this.isHighContrast,
    this.label,
    this.palette,
  }) : variant = GlassButtonVariant.iconOnly;

  const GlassButton.chip({
    super.key,
    required String this.label,
    this.icon,
    this.onPressed,
    this.isSelected = false,
    this.isPrimary = false,
    this.isLoading = false,
    this.useBackdropBlur = false,
    this.blurSigma = 10.0,
    this.accentColor,
    this.customBackgroundColor,
    this.customBorderColor,
    this.customTextColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    this.borderRadius,
    this.width,
    this.height,
    this.minWidth = 0.0,
    this.minHeight = 32.0,
    this.semanticLabel,
    this.tooltip,
    this.isCircle = false,
    this.child,
    this.customChild,
    this.textStyle,
    this.iconSize,
    this.iconColor,
    this.isHighContrast,
    this.palette,
  }) : variant = GlassButtonVariant.chip,
       isDestructive = false;

  const GlassButton.highEmphasisPill({
    super.key,
    required String this.label,
    this.icon,
    this.onPressed,
    this.isLoading = false,
    this.useBackdropBlur = false,
    this.blurSigma = 10.0,
    this.accentColor,
    this.customBackgroundColor,
    this.customBorderColor,
    this.customTextColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
    this.borderRadius,
    this.width = double.infinity,
    this.height = 52.0,
    this.minWidth = 48.0,
    this.minHeight = 48.0,
    this.semanticLabel,
    this.tooltip,
    this.isCircle = false,
    this.child,
    this.customChild,
    this.textStyle,
    this.iconSize,
    this.iconColor,
    this.isHighContrast,
    this.palette,
  }) : variant = GlassButtonVariant.highEmphasisPill,
       isPrimary = false,
       isDestructive = false,
       isSelected = false;

  const GlassButton.largeCta({
    super.key,
    required String this.label,
    this.icon,
    this.onPressed,
    this.isPrimary = true,
    this.isDestructive = false,
    this.isLoading = false,
    this.useBackdropBlur = false,
    this.blurSigma = 10.0,
    this.accentColor,
    this.customBackgroundColor,
    this.customBorderColor,
    this.customTextColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
    this.borderRadius,
    this.width = double.infinity,
    this.height = 52.0,
    this.minWidth = 48.0,
    this.minHeight = 48.0,
    this.semanticLabel,
    this.tooltip,
    this.isCircle = false,
    this.child,
    this.customChild,
    this.textStyle,
    this.iconSize,
    this.iconColor,
    this.isHighContrast,
    this.palette,
  }) : variant = GlassButtonVariant.largeCta,
       isSelected = false;

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton> {
  bool _pressed = false;

  bool _resolveHighContrast(BuildContext context) {
    if (widget.isHighContrast != null) {
      return widget.isHighContrast!;
    }
    if (widget.palette?.highContrast ?? false) {
      return true;
    }
    if (MediaQuery.maybeOf(context)?.highContrast ?? false) {
      return true;
    }
    try {
      final cubit = BlocProvider.of<AppPreferencesCubit>(
        context,
        listen: false,
      );
      if (cubit.state.highContrastMode) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark =
        widget.palette?.isDark ??
        (Theme.of(context).brightness == Brightness.dark);
    final bool highContrast = _resolveHighContrast(context);
    final enabled = widget.onPressed != null && !widget.isLoading;

    final bool isHighEmphasis =
        widget.variant == GlassButtonVariant.highEmphasisPill;
    final bool isChip = widget.variant == GlassButtonVariant.chip;

    final bool effectivePrimary =
        widget.isPrimary ||
        widget.variant == GlassButtonVariant.primary ||
        (widget.variant == GlassButtonVariant.largeCta && widget.isPrimary);

    final bool effectiveDestructive =
        widget.isDestructive ||
        widget.variant == GlassButtonVariant.destructive;

    final Color defaultAccent =
        widget.palette?.accentPrimary ?? const Color(0xFFC24C27);
    final baseAccent = widget.accentColor ?? defaultAccent;
    final destructiveBase =
        widget.palette?.errorColor ??
        (highContrast ? const Color(0xFF93000A) : const Color(0xFFBA1A1A));

    Color topColor;
    Color bottomColor;
    Color borderColor;
    Color textColor;

    if (!enabled) {
      topColor = highContrast
          ? (isDark ? const Color(0xFF282420) : const Color(0xFFD9D2C3))
          : (isDark
                ? const Color(0xFF2C2623).withValues(alpha: 0.35)
                : const Color(0xFFE8E2D5).withValues(alpha: 0.35));
      bottomColor = topColor;
      borderColor = highContrast
          ? (isDark ? const Color(0xFF574E46) : const Color(0xFF8C8477))
          : (isDark
                ? const Color(0xFFF4F0E8).withValues(alpha: 0.08)
                : const Color(0xFF1C1917).withValues(alpha: 0.06));
      textColor = highContrast
          ? (isDark ? const Color(0xFFA8A096) : const Color(0xFF5C5750))
          : (isDark ? const Color(0xFF7A756D) : const Color(0xFFA8A095));
    } else if (highContrast) {
      if (effectiveDestructive) {
        topColor = destructiveBase;
        bottomColor = destructiveBase;
        borderColor = isDark ? Colors.white : Colors.black;
        textColor = Colors.white;
      } else if (isHighEmphasis) {
        topColor = isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
        bottomColor = topColor;
        borderColor = isDark ? Colors.white : Colors.black;
        textColor = isDark ? Colors.black : Colors.white;
      } else if (isChip) {
        if (widget.isSelected) {
          topColor = baseAccent;
          bottomColor = baseAccent;
          borderColor = isDark ? Colors.white : Colors.black;
          textColor = Colors.white;
        } else {
          topColor = isDark ? const Color(0xFF24201C) : const Color(0xFFFFFFFF);
          bottomColor = isDark
              ? const Color(0xFF1A1715)
              : const Color(0xFFEDE8DE);
          borderColor = isDark ? Colors.white : const Color(0xFF1C1917);
          textColor = isDark
              ? const Color(0xFFF4F0E8)
              : const Color(0xFF1C1917);
        }
      } else if (effectivePrimary) {
        topColor = baseAccent;
        bottomColor = baseAccent;
        borderColor = isDark ? Colors.white : Colors.black;
        textColor = Colors.white;
      } else {
        topColor = isDark ? const Color(0xFF24201C) : const Color(0xFFFFFFFF);
        bottomColor = isDark
            ? const Color(0xFF1A1715)
            : const Color(0xFFEDE8DE);
        borderColor = isDark ? Colors.white : const Color(0xFF1C1917);
        textColor = isDark ? const Color(0xFFF4F0E8) : const Color(0xFF1C1917);
      }
    } else {
      if (effectiveDestructive) {
        topColor = destructiveBase.withValues(alpha: 0.85);
        bottomColor = destructiveBase.withValues(alpha: 0.75);
        borderColor = Colors.white.withValues(alpha: isDark ? 0.35 : 0.40);
        textColor = Colors.white;
      } else if (isHighEmphasis) {
        // High-emphasis pill: Fill #1C1917 (92%) text #F4F0E8 in light; Fill #F4F0E8 (92%) text #14110F in dark
        topColor = isDark
            ? const Color(0xFFF4F0E8).withValues(alpha: 0.94)
            : const Color(0xFF1C1917).withValues(alpha: 0.94);
        bottomColor = isDark
            ? const Color(0xFFF4F0E8).withValues(alpha: 0.90)
            : const Color(0xFF1C1917).withValues(alpha: 0.90);
        borderColor = isDark
            ? const Color(0xFF1C1917).withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.20);
        textColor = isDark ? const Color(0xFF14110F) : const Color(0xFFF4F0E8);
      } else if (isChip) {
        if (widget.isSelected) {
          // Selected Preset Chip: Fill #C24C27, Text #FFFFFF
          topColor = baseAccent;
          bottomColor = baseAccent;
          borderColor = Colors.white.withValues(alpha: isDark ? 0.35 : 0.40);
          textColor = Colors.white;
        } else {
          // Unselected Preset Chip:
          // Light: Fill #E8E2D5 (75%), Text #1C1917
          // Dark: Fill #2A2421 (85%), Text #F4F0E8
          topColor = isDark
              ? const Color(0xFF2A2421).withValues(alpha: 0.85)
              : const Color(0xFFE8E2D5).withValues(alpha: 0.75);
          bottomColor = isDark
              ? const Color(0xFF2A2421).withValues(alpha: 0.85)
              : const Color(0xFFE8E2D5).withValues(alpha: 0.75);
          borderColor = isDark
              ? const Color(0xFFF4F0E8).withValues(alpha: 0.18)
              : const Color(0xFF1C1917).withValues(alpha: 0.12);
          textColor = isDark
              ? const Color(0xFFF4F0E8)
              : const Color(0xFF1C1917);
        }
      } else if (effectivePrimary) {
        // Accent Glass Button: Fill #C24C27 at ~90-95% alpha, Foreground #FFFFFF
        topColor = isDark
            ? baseAccent.withValues(alpha: 0.90)
            : baseAccent.withValues(alpha: 0.96);
        bottomColor = isDark
            ? baseAccent.withValues(alpha: 0.88)
            : baseAccent.withValues(alpha: 0.92);
        borderColor = Colors.white.withValues(alpha: isDark ? 0.35 : 0.40);
        textColor = Colors.white;
      } else {
        // Neutral Glass Button:
        // Light: Fill #E8E2D5 at 65% alpha (with subtle white top highlight), border #1C1917 at 12%, text #1C1917
        // Dark: Fill #2C2623 at 70% alpha (NEVER #FFFFFF or #E8E2D5 in Dark!), border #F4F0E8 at 18%, text #F4F0E8
        topColor = isDark
            ? const Color(0xFF332C28).withValues(alpha: 0.72)
            : const Color(0xFFF5EFE6).withValues(alpha: 0.70);
        bottomColor = isDark
            ? const Color(0xFF2C2623).withValues(alpha: 0.70)
            : const Color(0xFFE8E2D5).withValues(alpha: 0.65);
        borderColor = isDark
            ? const Color(0xFFF4F0E8).withValues(alpha: 0.18)
            : const Color(0xFF1C1917).withValues(alpha: 0.12);
        textColor = isDark ? const Color(0xFFF4F0E8) : const Color(0xFF1C1917);
      }
    }

    if (widget.customBackgroundColor != null) {
      topColor = widget.customBackgroundColor!;
      bottomColor = widget.customBackgroundColor!;
    }
    if (widget.customBorderColor != null) {
      borderColor = widget.customBorderColor!;
    }
    if (widget.customTextColor != null) {
      textColor = widget.customTextColor!;
    }

    final bool isCircleShape =
        widget.isCircle ||
        widget.variant == GlassButtonVariant.iconOnly ||
        (widget.width != null &&
            widget.height != null &&
            widget.width == widget.height);

    final bool isClipCircle =
        widget.isCircle ||
        widget.variant == GlassButtonVariant.iconOnly ||
        (isCircleShape && widget.borderRadius == null);

    final double? circleSize = isCircleShape
        ? (widget.width ??
              widget.height ??
              (widget.minWidth > 0 ? widget.minWidth : 48.0))
        : null;

    final double? visualWidth = isCircleShape ? circleSize : widget.width;
    final double? visualHeight = isCircleShape ? circleSize : widget.height;

    final BorderRadius radius =
        widget.borderRadius ??
        (isCircleShape
            ? BorderRadius.circular(999)
            : (widget.variant == GlassButtonVariant.chip
                  ? BorderRadius.circular(16)
                  : BorderRadius.circular(16)));

    final EdgeInsetsGeometry effectivePadding =
        widget.padding ??
        (isCircleShape
            ? EdgeInsets.zero
            : (widget.variant == GlassButtonVariant.chip
                  ? const EdgeInsets.symmetric(horizontal: 14, vertical: 8)
                  : (widget.variant == GlassButtonVariant.highEmphasisPill ||
                            widget.variant == GlassButtonVariant.largeCta
                        ? const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 15,
                          )
                        : const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ))));

    final Widget? actualChild = widget.child ?? widget.customChild;
    final Color effectiveIconColor = widget.iconColor ?? textColor;

    Widget childContent;
    if (actualChild != null) {
      childContent = actualChild;
    } else if (widget.variant == GlassButtonVariant.iconOnly) {
      if (widget.isLoading) {
        childContent = SizedBox(
          width: widget.iconSize ?? 18,
          height: widget.iconSize ?? 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: textColor),
        );
      } else {
        childContent = Icon(
          widget.icon,
          size: widget.iconSize ?? 20,
          color: effectiveIconColor,
        );
      }
    } else {
      childContent = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (widget.isLoading) ...[
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: textColor,
              ),
            ),
            const SizedBox(width: 8),
          ] else if (widget.icon != null) ...[
            Icon(
              widget.icon,
              size:
                  widget.iconSize ??
                  (widget.variant == GlassButtonVariant.chip ? 15 : 18),
              color: effectiveIconColor,
            ),
            const SizedBox(width: 6),
          ],
          if (widget.label != null && widget.label!.isNotEmpty)
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  widget.label!,
                  maxLines: 1,
                  style: widget.textStyle != null
                      ? (widget.textStyle!.color != null
                            ? widget.textStyle
                            : widget.textStyle!.copyWith(color: textColor))
                      : TextStyle(
                          fontSize:
                              widget.variant == GlassButtonVariant.largeCta ||
                                  widget.variant ==
                                      GlassButtonVariant.highEmphasisPill
                              ? 15
                              : (widget.variant == GlassButtonVariant.chip
                                    ? 12
                                    : 14),
                          fontWeight:
                              widget.variant == GlassButtonVariant.largeCta ||
                                  widget.variant ==
                                      GlassButtonVariant.highEmphasisPill
                              ? FontWeight.w700
                              : (effectivePrimary || widget.isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w600),
                          color: textColor,
                          letterSpacing: 0.2,
                        ),
                ),
              ),
            ),
        ],
      );
    }

    final Widget themedContent = IconTheme(
      data: IconThemeData(
        color: effectiveIconColor,
        size: widget.iconSize ?? (isCircleShape ? 20 : 18),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(
          color: textColor,
          fontFamily: widget.textStyle?.fontFamily,
          fontSize: widget.textStyle?.fontSize,
          fontWeight: widget.textStyle?.fontWeight,
          letterSpacing: widget.textStyle?.letterSpacing,
        ),
        child: Center(child: childContent),
      ),
    );

    Widget buttonBody = Container(
      width: visualWidth,
      height: visualHeight,
      padding: effectivePadding,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: isClipCircle ? null : radius,
        shape: isClipCircle ? BoxShape.circle : BoxShape.rectangle,
        gradient: highContrast
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [topColor, bottomColor],
              ),
        color: highContrast ? topColor : null,
        border: Border.all(color: borderColor, width: highContrast ? 2.0 : 1.0),
        boxShadow: (enabled && !highContrast)
            ? [
                BoxShadow(
                  color:
                      (effectiveDestructive
                              ? destructiveBase
                              : (effectivePrimary
                                    ? baseAccent
                                    : (isHighEmphasis
                                          ? (isDark
                                                ? Colors.white
                                                : Colors.black)
                                          : Colors.black)))
                          .withValues(alpha: isDark ? 0.22 : 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : const [],
      ),
      child: themedContent,
    );

    final bool useBlur = widget.useBackdropBlur && !highContrast;
    Widget surface = isClipCircle
        ? ClipOval(
            child: useBlur
                ? BackdropFilter(
                    filter: ui.ImageFilter.blur(
                      sigmaX: widget.blurSigma,
                      sigmaY: widget.blurSigma,
                    ),
                    child: buttonBody,
                  )
                : buttonBody,
          )
        : ClipRRect(
            borderRadius: radius,
            child: useBlur
                ? BackdropFilter(
                    filter: ui.ImageFilter.blur(
                      sigmaX: widget.blurSigma,
                      sigmaY: widget.blurSigma,
                    ),
                    child: buttonBody,
                  )
                : buttonBody,
          );

    final String semanticsLabel =
        widget.semanticLabel ?? widget.label ?? widget.tooltip ?? 'Button';

    final bool disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    // Hit-target management: touch target satisfies minWidth/minHeight (48x48)
    // while keeping visual size unchanged
    final bool needsTouchExpansion =
        (visualWidth != null && visualWidth < widget.minWidth) ||
        (visualHeight != null && visualHeight < widget.minHeight);

    Widget hitTarget = needsTouchExpansion
        ? ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: widget.minWidth,
              minHeight: widget.minHeight,
            ),
            child: Center(
              child: SizedBox(
                width: visualWidth,
                height: visualHeight,
                child: RepaintBoundary(child: surface),
              ),
            ),
          )
        : ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: visualWidth == null ? widget.minWidth : 0,
              minHeight: visualHeight == null ? widget.minHeight : 0,
            ),
            child: RepaintBoundary(child: surface),
          );

    Widget buttonWidget = Semantics(
      button: true,
      enabled: enabled,
      selected: widget.variant == GlassButtonVariant.chip
          ? widget.isSelected
          : null,
      label: semanticsLabel,
      tooltip: widget.tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        onTap: enabled
            ? () {
                HapticFeedback.selectionClick();
                widget.onPressed!();
              }
            : null,
        child: AnimatedScale(
          scale: (_pressed && !disableAnimations) ? 0.96 : 1.0,
          duration: disableAnimations
              ? Duration.zero
              : const Duration(milliseconds: 100),
          child: AnimatedOpacity(
            opacity: (_pressed && !disableAnimations) ? 0.90 : 1.0,
            duration: disableAnimations
                ? Duration.zero
                : const Duration(milliseconds: 100),
            child: hitTarget,
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      buttonWidget = Tooltip(message: widget.tooltip!, child: buttonWidget);
    }

    return buttonWidget;
  }
}

class GlassBottomSheet extends StatelessWidget {
  final Widget child;
  final TidaraPalette? palette;

  const GlassBottomSheet({super.key, required this.child, this.palette});

  @override
  Widget build(BuildContext context) {
    final isDark =
        palette?.isDark ?? (Theme.of(context).brightness == Brightness.dark);
    final highContrast = resolveHighContrastMode(
      context,
      explicit: palette?.highContrast,
    );

    if (highContrast) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0C0A09) : const Color(0xFFF4F0E8),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(
              color: isDark ? Colors.white : const Color(0xFF1C1917),
              width: 2.0,
            ),
          ),
          child: child,
        ),
      );
    }

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      const Color(0xFF221E1B).withValues(alpha: 0.94),
                      const Color(0xFF161412).withValues(alpha: 0.96),
                    ]
                  : [
                      const Color(0xFFFFFFFF).withValues(alpha: 0.95),
                      const Color(0xFFF5EFE6).withValues(alpha: 0.92),
                    ],
            ),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.20)
                  : const Color(0xFFB5AC99).withValues(alpha: 0.60),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.10),
                blurRadius: 28,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
