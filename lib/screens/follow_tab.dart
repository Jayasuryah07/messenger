import 'package:flutter/material.dart';
import '../models/crm_model.dart';
import '../theme/theme.dart';
import 'lead_card.dart';

class FollowTab extends StatelessWidget {
  final List<Lead> leads;
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

  const FollowTab({
    super.key,
    required this.leads,
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
    if (leads.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        color: AppTheme.primaryTeal,
        backgroundColor: AppTheme.darkCard,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.18),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppTheme.statusFollowUp.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.event_note_rounded,
                        size: 64,
                        color: AppTheme.statusFollowUp,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'No Follow-ups Scheduled',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'There are no follow-ups scheduled for today. Drag down to refresh or check other status tabs.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
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
      );
    }

    final totalLeads = leads.length;

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppTheme.primaryTeal,
      backgroundColor: AppTheme.darkCard,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: totalLeads + 1, // Add 1 for the summary header card
        itemBuilder: (context, index) {
          if (index == 0) {
            // Header summary card
            return Container(
             
              
            );
          }

          final lead = leads[index - 1];
          return LeadCard(
            lead: lead,
            tabType: 'follow',
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
