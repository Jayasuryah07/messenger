import 'package:flutter/material.dart';
import '../models/crm_model.dart';
import '../services/auth_state.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class LeadCard extends StatelessWidget {
  final Lead lead;
  final String tabType;
  final VoidCallback onCall;
  final VoidCallback onWhatsApp;
  final VoidCallback onEmail;
  final VoidCallback onSchedule;
  final VoidCallback onChangeStatus;
  final VoidCallback onViewAttachment;
  final bool useCommonDetails;
  final String commonMessage;
  final String commonImagePath;

  const LeadCard({
    super.key,
    required this.lead,
    required this.tabType,
    required this.onCall,
    required this.onWhatsApp,
    required this.onEmail,
    required this.onSchedule,
    required this.onChangeStatus,
    required this.onViewAttachment,
    this.useCommonDetails = false,
    this.commonMessage = '',
    this.commonImagePath = '',
  });

  // Extract initials from message/chapter string
  String _getInitials(String msg) {
    if (msg.isEmpty) return 'LD';
    final parts = msg.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      final first = parts[0][0];
      final second = parts[1][0];
      return '${first}${second}'.toUpperCase().replaceAll(
        RegExp(r'[^A-Z]'),
        'L',
      );
    }
    return msg
        .substring(0, msg.length >= 2 ? 2 : 1)
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z]'), 'L');
  }

  // Dynamic matching avatar background colors
  Color _getInitialsColor(String initials) {
    final colors = [
      const Color(0xFF6366F1), // Indigo
      const Color(0xFF3B82F6), // Blue
      const Color(0xFFF97316), // Orange
      const Color(0xFF14B8A6), // Teal
      const Color(0xFFEC4899), // Pink
      const Color(0xFF8B5CF6), // Violet
    ];
    final hash = initials.hashCode;
    return colors[hash.abs() % colors.length];
  }

  // Status badges colors matching mockup screenshots
  Color _getBadgeBgColor(String status) {
    final s = status.toLowerCase().trim();
    if (s == 'new') return const Color(0xFFF5F3FF); // Lavender
    if (s == 'add wa' || s == 'wa link')
      return const Color(0xFFFFF7ED); // Pastel orange
    if (s == 'pending') return const Color(0xFFFFFBEB); // Soft amber
    if (s == 'follow up' || s == 'follow')
      return const Color(0xFFEFF6FF); // Light blue
    if (s == 'wrong number' || s == 'wrong no.')
      return const Color(0xFFFEE2E2); // Light red
    if (s == 'not valid number' || s == 'not valid')
      return const Color(0xFFFFF1F2); // Rose
    if (s == 'switch off')
      return const Color(0xFFFEF3C7); // Pastel yellow/amber
    return const Color(0xFFECFDF5); // Pastel emerald green
  }

  Color _getBadgeTextColor(String status) {
    final s = status.toLowerCase().trim();
    if (s == 'new') return const Color(0xFF8B5CF6);
    if (s == 'add wa' || s == 'wa link') return const Color(0xFFEA580C);
    if (s == 'pending') return const Color(0xFFD97706);
    if (s == 'follow up' || s == 'follow') return const Color(0xFF2563EB);
    if (s == 'wrong number' || s == 'wrong no.') return const Color(0xFFEF4444);
    if (s == 'not valid number' || s == 'not valid')
      return const Color(0xFFF43F5E);
    if (s == 'switch off') return const Color(0xFFD97706);
    return const Color(0xFF10B981);
  }

  Widget _buildLogoButton({
    required VoidCallback onTap,
    required Widget icon,
    required Color backgroundColor,
    Color? borderColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: borderColor == null
                ? null
                : Border.all(color: borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: backgroundColor.withOpacity(0.15),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: icon,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayMessage = useCommonDetails ? commonMessage : lead.message;
    final hasMedia = useCommonDetails
        ? commonImagePath.isNotEmpty
        : (lead.fileAttached.trim().toLowerCase() == 'yes');
    final bool isPdfCommon = commonImagePath.toLowerCase().endsWith('.pdf');
    final bool isImageCommon = commonImagePath.toLowerCase().endsWith('.jpg') ||
        commonImagePath.toLowerCase().endsWith('.jpeg') ||
        commonImagePath.toLowerCase().endsWith('.png') ||
        commonImagePath.toLowerCase().endsWith('.gif') ||
        commonImagePath.toLowerCase().endsWith('.webp');
    final displayHasPdf = useCommonDetails ? isPdfCommon : lead.hasPdf;
    final displayHasImage = useCommonDetails ? isImageCommon : lead.hasImage;

    // Dynamic theme color matching mockup tabs
    Color activeThemeColor = const Color(0xFF6366F1); // Indigo default
    if (tabType == 'pending') {
      activeThemeColor = const Color(0xFFD97706); // Amber/Yellow
    } else if (tabType == 'follow') {
      activeThemeColor = const Color(0xFF3B82F6); // Blue
    } else if (tabType == 'completed') {
      activeThemeColor = const Color(0xFF10B981); // Green
    }

    // Fetch user access control list parameters based on user_work config
    final String userWork = (AuthState().userProfile?['user_work'] ?? 'ALL')
        .toString()
        .toUpperCase()
        .trim();

    // access modes:
    // W -> WhatsApp only
    // C -> Call only
    // M -> Message (WhatsApp and Email)
    // ALL -> Full access for all actions
    final showCall = userWork == 'C' || userWork == 'ALL';
    final showWhatsApp =
        userWork == 'W' || userWork == 'ALL' || userWork == 'M';

    // Update Status option is enabled globally for all tabs!
    const showStatus = true;

    final List<Widget> leftActions = [];

    if (showCall) {
      leftActions.add(
        _buildLogoButton(
          onTap: onCall,
          icon: const Icon(
            Icons.phone_rounded,
            color: const Color.fromARGB(255, 0, 60, 255),
            size: 20,
          ),
          backgroundColor: const Color.fromARGB(255, 255, 255, 255), // Vibrant Call Green
          borderColor:  const Color.fromARGB(255, 0, 60, 255),
        ),
      );
    }

    if (showWhatsApp) {
      if (leftActions.isNotEmpty) leftActions.add(const SizedBox(width: 8));
      leftActions.add(
        _buildLogoButton(
          onTap: onWhatsApp,
          icon: const FaIcon(
            FontAwesomeIcons.whatsapp,
            color: const Color(0xFF25D366),
            size: 20,
          ),
          backgroundColor: const Color.fromARGB(255, 255, 255, 255),
          borderColor: const Color(0xFF25D366),
          // WhatsApp Green
        ),
      );
    }

    final initials = _getInitials(displayMessage);
    final avatarColor = _getInitialsColor(initials);
    final badgeBg = _getBadgeBgColor(lead.dataStatus);
    final badgeText = _getBadgeTextColor(lead.dataStatus);

    return FutureBuilder<String>(
      future: AuthState.getStatusChangeTime(lead.id, lead.dataCreated),
      builder: (context, snapshot) {
        final statusChangedTime = snapshot.data ?? lead.dataCreated;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top section (Avatar Circle, dynamic details, Badge, call dialer icon / chevron arrow)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Dynamic initials circle avatar
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: avatarColor,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Details body
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lead.mobileNo,
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            displayMessage,
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),

                          // Show Added date & Last Updated date side-by-side on non-followup tabs
                          if (tabType == 'pending' ||
                              tabType == 'completed') ...[
                            const SizedBox(height: 6),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Added Date
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.access_time_rounded,
                                      size: 11,
                                      color: Color(0xFF94A3B8),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        'Added: ${lead.dataCreated}',
                                        style: const TextStyle(
                                          color: Color(0xFF94A3B8),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),

                                // Updated Date (Completed Only)
                                if (tabType == 'completed') ...[
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.history_rounded,
                                        size: 11,
                                        color: Color(0xFF64748B),
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          'Updated: $statusChangedTime',
                                          style: const TextStyle(
                                            color: Color(0xFF64748B),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ], //
                        ],
                      ),
                    ),
                    // Badge column
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            lead.dataStatus,
                            style: TextStyle(
                              color: badgeText,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Always show dialer/chevron trigger
                  ],
                ),

                // Follow Up double column details segment
                if (tabType == 'follow' && lead.followupDate != null) ...[
                  const SizedBox(height: 12),
                  const Divider(color: Color(0xFFF1F5F9), height: 1),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Next Follow Up Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(
                                  Icons.calendar_month_rounded,
                                  size: 12,
                                  color: Color(0xFF3B82F6),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Next Follow Up',
                                  style: TextStyle(
                                    color: Color(0xFF3B82F6),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${lead.followupDate}   ${lead.followupTime ?? '00:00:00'}',
                              style: const TextStyle(
                                color: Color(0xFF1E293B),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Last Updated (Status Change Date & Time)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(
                                  Icons.history_rounded,
                                  size: 12,
                                  color: Color(0xFF0F172A),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Last Updated',
                                  style: TextStyle(
                                    color: Color(0xFF475569),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              statusChangedTime,
                              style: const TextStyle(
                                color: Color(0xFF1E293B),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],

                // Attachment Pill
                if (hasMedia) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: onViewAttachment,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            displayHasPdf
                                ? Icons.picture_as_pdf_rounded
                                : displayHasImage
                                    ? Icons.insert_photo_rounded
                                    : Icons.attach_file_rounded,
                            size: 14,
                            color: displayHasPdf
                                ? Colors.redAccent
                                : displayHasImage
                                    ? activeThemeColor
                                    : Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            displayHasPdf
                                ? 'PDF Document Attached'
                                : displayHasImage
                                    ? 'Image Attached'
                                    : 'File Attached',
                            style: const TextStyle(
                              color: Color(0xFF475569),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // Bottom actions pill row (Enabled on all tabs!)
                if (leftActions.isNotEmpty || showStatus) ...[
                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFFF1F5F9), height: 1),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(children: leftActions),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (showStatus)
                        ElevatedButton(
                          onPressed: onChangeStatus,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: activeThemeColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Update Status',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
