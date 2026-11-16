import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/security/encrypted_vault.dart';
import '../../core/security/self_test_suite.dart';
import '../../core/theme/tidara_palette.dart';
import '../../shared/widgets/liquid_glass_components.dart';

/// Diagnostics modal displaying live cryptographic self-test checks.
/// Strictly disabled/unreachable in release mode ([kDebugMode] == false).
class SecurityDiagnosticsModal extends StatefulWidget {
  final TidaraPalette palette;
  final VoidCallback onClose;
  final bool isDebug;

  const SecurityDiagnosticsModal({
    super.key,
    required this.palette,
    required this.onClose,
    this.isDebug = kDebugMode,
  });

  @override
  State<SecurityDiagnosticsModal> createState() =>
      _SecurityDiagnosticsModalState();
}

class _SecurityDiagnosticsModalState extends State<SecurityDiagnosticsModal> {
  Map<String, bool>? _liveResults;
  bool _isRunning = false;
  DateTime? _lastRunTimestamp;

  @override
  void initState() {
    super.initState();
    if (widget.isDebug) {
      _runLiveChecks();
    }
  }

  void _runLiveChecks() {
    setState(() => _isRunning = true);
    final results = TidaraSelfTestSuite.runAllChecks();
    if (!mounted) return;
    setState(() {
      _liveResults = results;
      _lastRunTimestamp = DateTime.now();
      _isRunning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Release mode security guard: Never render diagnostics in release mode
    if (!widget.isDebug) {
      return const SizedBox.shrink();
    }

    final palette = widget.palette;

    return Positioned.fill(
      child: GestureDetector(
        onTap: widget.onClose,
        child: Container(
          color: Colors.black.withValues(alpha: 0.55),
          padding: const EdgeInsets.fromLTRB(16, 48, 16, 84),
          child: GestureDetector(
            onTap: () {}, // Prevent tap propagation to backdrop
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: palette.surfaceElevated,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: palette.strokeSubtle),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.bug_report_outlined,
                        size: 20,
                        color: palette.accentPrimary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Security Diagnostics (Debug Only)',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: palette.textPrimary,
                          ),
                        ),
                      ),
                      GlassButton.iconOnly(
                        icon: Icons.close,
                        semanticLabel: 'Close diagnostics',
                        tooltip: 'Close',
                        onPressed: widget.onClose,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Live cryptographic checks and key-source verification. '
                    'This diagnostic utility is stripped from release builds.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: palette.surfaceCard,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: palette.strokeSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Active Vault Key Source: ${EncryptedVault.activeKeySource.name}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: palette.textPrimary,
                          ),
                        ),
                        if (_lastRunTimestamp != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Last run: ${_lastRunTimestamp!.toIso8601String().substring(11, 19)} UTC',
                              style: TextStyle(
                                fontSize: 11,
                                color: palette.textSecondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'LIVE SELF-TEST RESULTS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: palette.accentPrimary,
                        ),
                      ),
                      if (_isRunning)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView(
                      children: [
                        if (_liveResults != null)
                          ..._liveResults!.entries.map(
                            (e) => Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: palette.surfaceCard,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: palette.strokeSubtle),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    e.value ? Icons.check_circle : Icons.error,
                                    size: 16,
                                    color: e.value
                                        ? const Color(0xFF4A6B53)
                                        : palette.accentPrimary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      e.key,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: palette.textPrimary,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    e.value ? 'LIVE PASS' : 'LIVE FAIL',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: e.value
                                          ? const Color(0xFF4A6B53)
                                          : palette.accentPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: GlassButton.secondary(
                          onPressed: _isRunning ? null : _runLiveChecks,
                          icon: Icons.refresh,
                          isLoading: _isRunning,
                          label: 'Re-run Live Checks',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
