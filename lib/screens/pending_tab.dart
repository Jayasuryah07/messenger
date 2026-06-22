import 'package:flutter/material.dart';
import '../models/crm_model.dart';
import '../theme/theme.dart';
import 'lead_card.dart';

class PendingTab extends StatelessWidget {
  final List<Lead> leads;
  final int todayFollowUpsCount;
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

  const PendingTab({
    super.key,
    required this.leads,
    required this.todayFollowUpsCount,
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

  @override
  Widget build(BuildContext context) {
    final totalLeads = leads.length;

    final bool showHeader = todayFollowUpsCount > 0;

return RefreshIndicator(
  onRefresh: onRefresh,
  color: AppTheme.primaryTeal,
  backgroundColor: AppTheme.darkCard,
  child: ListView.builder(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.all(16),
    itemCount: totalLeads == 0
        ? (showHeader ? 2 : 1)
        : totalLeads + (showHeader ? 1 : 0),
    itemBuilder: (context, index) {

      // Show header only when follow-ups exist today
      if (showHeader && index == 0) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFEEF2FF), Color(0xFFE0E7FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFC7D2FE),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.alarm_rounded,
                  color: AppTheme.statusFollowUp,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Action Required',
                      style: TextStyle(
                        color: Color(0xFF3730A3),
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'You have $todayFollowUpsCount follow-up${todayFollowUpsCount != 1 ? 's' : ''} scheduled for today.',
                      style: const TextStyle(
                        color: Color(0xFF4338CA),
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }

      if (totalLeads == 0) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Center(
            child: Text("No pending leads"),
          ),
        );
      }

      // Adjust lead index when header exists
      final leadIndex = showHeader ? index - 1 : index;
      final lead = leads[leadIndex];

      return LeadCard(
        lead: lead,
        tabType: 'pending',
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
);
    
  }
}
