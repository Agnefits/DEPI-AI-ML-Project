import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../bloc/subscriptions_bloc.dart';
import '../bloc/subscriptions_event.dart';
import '../bloc/subscriptions_state.dart';
import '../widgets/primary_action_button.dart';
import '../widgets/section_header.dart';
import '../widgets/subscription_detail_row.dart';
import '../widgets/subscription_status_badge.dart';

class SubscriptionDetailsScreen extends StatefulWidget {
  final String subscriptionId;

  const SubscriptionDetailsScreen({
    Key? key,
    required this.subscriptionId,
  }) : super(key: key);

  @override
  State<SubscriptionDetailsScreen> createState() => _SubscriptionDetailsScreenState();
}

class _SubscriptionDetailsScreenState extends State<SubscriptionDetailsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<SubscriptionsBloc>().add(LoadSubscriptionDetailsEvent(widget.subscriptionId));
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMMM dd, yyyy');
    
    return Scaffold(
      backgroundColor: const Color(0xFF0D1025),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1025),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () {
            context.read<SubscriptionsBloc>().add(LoadSubscriptionsEvent());
            Navigator.pop(context);
          },
        ),
        title: Text(
          'Plan Details',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: BlocConsumer<SubscriptionsBloc, SubscriptionsState>(
        listener: (context, state) {
          if (state is SubscriptionCancelledSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Subscription cancelled successfully',
                  style: GoogleFonts.poppins(),
                ),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context);
          } else if (state is SubscriptionsError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  state.message,
                  style: GoogleFonts.poppins(),
                ),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is SubscriptionsLoading) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF6D6AFB)));
          } else if (state is SubscriptionDetailsLoaded) {
            final subscription = state.subscription;
            final isActive = subscription.status.toLowerCase() == 'active';
            
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F2343),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6D6AFB).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.star_rounded,
                            color: Color(0xFF6D6AFB),
                            size: 48,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          subscription.planName,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SubscriptionStatusBadge(status: subscription.status),
                        const SizedBox(height: 16),
                        Text(
                          '\$${subscription.price.toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF6D6AFB),
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'per month',
                          style: GoogleFonts.poppins(
                            color: Colors.white54,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const SectionHeader(title: 'Subscription Info'),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F2343),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        SubscriptionDetailRow(
                          icon: Icons.calendar_today_rounded,
                          title: 'Start Date',
                          value: dateFormat.format(subscription.startDate),
                        ),
                        Divider(color: Colors.white.withOpacity(0.1), height: 1),
                        SubscriptionDetailRow(
                          icon: Icons.event_busy_rounded,
                          title: 'End Date',
                          value: dateFormat.format(subscription.endDate),
                        ),
                        Divider(color: Colors.white.withOpacity(0.1), height: 1),
                        SubscriptionDetailRow(
                          icon: Icons.credit_card_rounded,
                          title: 'Payment Method',
                          value: '•••• 4242',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const SectionHeader(title: 'Included Features'),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F2343),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: subscription.features.map((feature) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xFF6D6AFB),
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  feature,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 40),
                  if (isActive) ...[
                    PrimaryActionButton(
                      label: 'Upgrade Plan',
                      onTap: () {
                        
                      },
                    ),
                    const SizedBox(height: 16),
                    PrimaryActionButton(
                      label: 'Cancel Subscription',
                      isDestructive: true,
                      onTap: () {
                        context.read<SubscriptionsBloc>().add(
                          CancelSubscriptionEvent(subscription.id),
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
