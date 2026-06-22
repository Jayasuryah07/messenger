import 'package:flutter/material.dart';
import '../models/crm_model.dart';
import '../theme/theme.dart';
import 'lead_card.dart';

class CompletedTab extends StatelessWidget {
  final List<Lead> leads;
  final List<CompanyStatus> statuses;
  final String activeSubStatus;
  final Function(String) onSubStatusChanged;
  final Function(Lead) onCall;
  final Function(Lead) onWhatsApp;
  final Function(Lead) onEmail;
  final Function(Lead) onSchedule;
  final Function(Lead) onChangeStatus;
  final Function(Lead) onViewAttachment;
  final Future<void> Function() onRefresh;
  final bool useCommonDetails;
  final String commonMessage;
  final String commonImagePath;

  const CompletedTab({
    super.key,
    required this.leads,
    required this.statuses,
    required this.activeSubStatus,
    required this.onSubStatusChanged,
    required this.onCall,
    required this.onWhatsApp,
    required this.onEmail,
    required this.onSchedule,
    required this.onChangeStatus,
    required this.onViewAttachment,
    required this.onRefresh,
    this.useCommonDetails = false,
    this.commonMessage = '',
    this.commonImagePath = '',
  });

  IconData? _getStatusIcon(String name) {
    final s = name.toLowerCase().trim();
    if (s == 'completed') return Icons.check_circle_rounded;
    if (s.contains('wrong')) return Icons.phone_disabled_rounded;
    if (s.contains('not valid') || s.contains('invalid')) return Icons.cancel_rounded;
    if (s.contains('switch') || s.contains('off')) return Icons.power_settings_new_rounded;
    if (s.contains('no response') || s.contains('not taking')) return Icons.phone_missed_rounded;
    if (s.contains('add wa') || s == 'addwa') return Icons.chat_rounded;
    if (s.contains('wa link') || s == 'walink') return Icons.link_rounded;
    if (s.contains('need demo')) return Icons.slideshow_rounded;
    if (s.contains('interest')) return Icons.thumb_down_alt_rounded;
    if (s.contains('hindi')) return Icons.translate_rounded;
    return Icons.info_rounded;
  }

  Color _getStatusIconColor(String name) {
    final s = name.toLowerCase().trim();
    if (s == 'completed') return const Color(0xFF10B981);
    if (s.contains('wrong')) return const Color(0xFFEF4444);
    if (s.contains('not valid') || s.contains('invalid')) return const Color(0xFFF43F5E);
    if (s.contains('switch') || s.contains('off')) return const Color(0xFFF59E0B);
    if (s.contains('no response') || s.contains('not taking')) return const Color(0xFF3B82F6);
    if (s.contains('add wa') || s == 'addwa') return const Color(0xFF25D366);
    if (s.contains('wa link') || s == 'walink') return const Color(0xFF0D9488);
    if (s.contains('need demo')) return const Color(0xFF6366F1);
    if (s.contains('interest')) return const Color(0xFF64748B);
    if (s.contains('hindi')) return const Color(0xFF06B6D4);
    return const Color(0xFF64748B);
  }

  Widget _buildCategoryPill({
    required String label,
    required String value,
    required bool isSelected,
    required IconData? icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF10B981) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF10B981).withOpacity(0.15),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: isSelected ? Colors.white : iconColor),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF475569),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. Filter out Pending and Follow Up statuses to obtain the list of Completed sub-statuses
    final completedStatuses = statuses.where((status) {
      final name = status.companyStatus.trim().toLowerCase();
      return name != 'pending' && name != 'follow up' && name != 'follow';
    }).toList();

    // 2. Filter leads list by active selection
    final filteredLeads = activeSubStatus.toLowerCase() == 'all'
        ? leads
        : leads.where((lead) {
            final status = lead.dataStatus.toLowerCase().trim();
            final active = activeSubStatus.toLowerCase().trim();
            if (active == 'wrong no.' || active == 'wrong number') {
              return status == 'wrong number' || status == 'wrong no.';
            }
            if (active == 'not valid' || active == 'not valid number') {
              return status == 'not valid number' || status == 'not valid';
            }
            if (active == 'not taking' || active == 'not taking call') {
              return status == 'not taking call' || status == 'not taking';
            }
            return status == active;
          }).toList();

    return Column(
      children: [
        // Category Pills Scrollable Row
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          color: Colors.white,
          width: double.infinity,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // "All" Pill
                _buildCategoryPill(
                  label: 'All',
                  value: 'all',
                  isSelected: activeSubStatus.toLowerCase() == 'all',
                  icon: null,
                  iconColor: Colors.transparent,
                  onTap: () => onSubStatusChanged('all'),
                ),
                // Dynamic completed statuses
                ...completedStatuses.map((status) {
                  final name = status.companyStatus;
                  final isSelected = activeSubStatus.toLowerCase().trim() == name.toLowerCase().trim();
                  return _buildCategoryPill(
                    label: name,
                    value: name,
                    isSelected: isSelected,
                    icon: _getStatusIcon(name),
                    iconColor: _getStatusIconColor(name),
                    onTap: () => onSubStatusChanged(name),
                  );
                }),
              ],
            ),
          ),
        ),

        const Divider(color: Color(0xFFF1F5F9), height: 1),

        // Leads List
        Expanded(
          child: filteredLeads.isEmpty
              ? RefreshIndicator(
                  onRefresh: onRefresh,
                  color: const Color(0xFF10B981),
                  backgroundColor: Colors.white,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.15),
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withOpacity(0.05),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.inventory_2_outlined,
                                  size: 64,
                                  color: Colors.grey.withOpacity(0.4),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'No leads found in "${activeSubStatus.toLowerCase() == 'all' ? 'Completed' : activeSubStatus}"',
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Drag down to refresh or check other categories.',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                  height: 1.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: onRefresh,
                  color: const Color(0xFF10B981),
                  backgroundColor: Colors.white,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredLeads.length,
                    itemBuilder: (context, index) {
                      final lead = filteredLeads[index];
                      return LeadCard(
                        lead: lead,
                        tabType: 'completed',
                        onCall: () => onCall(lead),
                        onWhatsApp: () => onWhatsApp(lead),
                        onEmail: () => onEmail(lead),
                        onSchedule: () => onSchedule(lead),
                        onChangeStatus: () => onChangeStatus(lead),
                        onViewAttachment: () => onViewAttachment(lead),
                        useCommonDetails: useCommonDetails,
                        commonMessage: commonMessage,
                        commonImagePath: commonImagePath,
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
