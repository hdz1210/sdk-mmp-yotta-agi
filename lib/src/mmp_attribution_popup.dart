import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'mmp_deeplink_data.dart';

/// Built-in Attribution Popup for MMP SDK.
/// Shows a beautiful dialog with deep link attribution info
/// when the app is opened via a tracked link.
class MMPAttributionPopup {
  /// Show the attribution popup dialog.
  /// Call this inside your [MMPSdk.onDeepLinkReceived] callback.
  static void show(BuildContext context, MMPDeeplinkData data) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _AttributionDialog(data: data),
    );
  }
}

class _AttributionDialog extends StatelessWidget {
  final MMPDeeplinkData data;
  const _AttributionDialog({required this.data});

  @override
  Widget build(BuildContext context) {
    final isDirect = data.isDirect;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366f1).withOpacity(0.3),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDirect
                      ? [const Color(0xFF6366f1), const Color(0xFF8b5cf6)]
                      : [const Color(0xFFec4899), const Color(0xFFf43f5e)],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isDirect ? Icons.link : Icons.fingerprint,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isDirect ? '🔗 Direct Link' : '🔍 Deferred Link',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isDirect ? 'Mở trực tiếp từ link' : 'Khớp vân tay thiết bị',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Body — Attribution Info
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _InfoRow(
                    icon: Icons.source,
                    label: 'UTM Source',
                    value: data.utmSource ?? '—',
                    color: const Color(0xFF60a5fa),
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: Icons.campaign,
                    label: 'UTM Campaign',
                    value: data.utmCampaign ?? '—',
                    color: const Color(0xFF34d399),
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: Icons.tag,
                    label: 'Slug',
                    value: data.slug ?? '—',
                    color: const Color(0xFFfbbf24),
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: Icons.card_giftcard,
                    label: 'Referral Code',
                    value: data.referralCode ?? '—',
                    color: const Color(0xFFf472b6),
                  ),
                  if (data.targetScreen != null && data.targetScreen!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _InfoRow(
                      icon: Icons.screen_share,
                      label: 'Target Screen',
                      value: data.targetScreen!,
                      color: const Color(0xFFa78bfa),
                    ),
                  ],
                  if (data.clickToOpenDuration != null) ...[
                    const SizedBox(height: 12),
                    _InfoRow(
                      icon: Icons.timer_outlined,
                      label: 'Click-to-Open Time',
                      value: '${data.clickToOpenDuration!.inSeconds} seconds',
                      color: const Color(0xFF10b981),
                    ),
                  ],
                  if (data.matchScore != null) ...[
                    const SizedBox(height: 12),
                    _InfoRow(
                      icon: Icons.score,
                      label: 'Match Score',
                      value: '${data.matchScore}/3',
                      color: const Color(0xFFfb923c),
                    ),
                  ],
                ],
              ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final text = 'Source: ${data.utmSource ?? "—"}\n'
                            'Campaign: ${data.utmCampaign ?? "—"}\n'
                            'Slug: ${data.slug ?? "—"}\n'
                            'Referral: ${data.referralCode ?? "—"}\n'
                            'Target: ${data.targetScreen ?? "—"}\n'
                            'Type: ${isDirect ? "Direct" : "Deferred"}';
                        Clipboard.setData(ClipboardData(text: text));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Đã copy thông tin!'), duration: Duration(seconds: 2)),
                        );
                      },
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copy'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDirect ? const Color(0xFF6366f1) : const Color(0xFFec4899),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
