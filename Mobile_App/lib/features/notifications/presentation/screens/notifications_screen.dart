import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../injection/injection_container.dart' as di;
import '../bloc/notification_bloc.dart';
import '../bloc/notification_event.dart';
import '../bloc/notification_state.dart';
import '../widgets/empty_notifications_widget.dart';
import '../widgets/notification_action_button.dart';
import '../widgets/notification_filter_chip.dart';
import '../widgets/notification_item_widget.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => di.sl<NotificationBloc>()..add(LoadNotificationsEvent()),
      child: const NotificationsView(),
    );
  }
}

class NotificationsView extends StatefulWidget {
  const NotificationsView({super.key});

  @override
  State<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<NotificationsView> {
  String _selectedFilter = 'All';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1025),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'Notifications',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: NotificationActionButton(
              icon: Icons.done_all_rounded,
              tooltip: 'Mark all as read',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'All marked as read',
                      style: GoogleFonts.poppins(),
                    ),
                    backgroundColor: const Color(0xFF1F2343),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                NotificationFilterChip(
                  label: 'All',
                  isSelected: _selectedFilter == 'All',
                  onTap: () => setState(() => _selectedFilter = 'All'),
                ),
                const SizedBox(width: 12),
                NotificationFilterChip(
                  label: 'Unread',
                  isSelected: _selectedFilter == 'Unread',
                  onTap: () => setState(() => _selectedFilter = 'Unread'),
                ),
                const SizedBox(width: 12),
                NotificationFilterChip(
                  label: 'Messages',
                  isSelected: _selectedFilter == 'Messages',
                  onTap: () => setState(() => _selectedFilter = 'Messages'),
                ),
                const SizedBox(width: 12),
                NotificationFilterChip(
                  label: 'Appointments',
                  isSelected: _selectedFilter == 'Appointments',
                  onTap: () => setState(() => _selectedFilter = 'Appointments'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: BlocBuilder<NotificationBloc, NotificationState>(
              builder: (context, state) {
                if (state is NotificationLoading) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF6D6AFB),
                    ),
                  );
                } else if (state is NotificationLoaded) {
                  final filteredList = state.notifications.where((n) {
                    if (_selectedFilter == 'Unread') return !n.isRead;
                    if (_selectedFilter == 'Messages') return n.type == 'message';
                    if (_selectedFilter == 'Appointments') return n.type == 'appointment';
                    return true;
                  }).toList();

                  if (filteredList.isEmpty) {
                    return EmptyNotificationsWidget(
                      onRefresh: () => context.read<NotificationBloc>().add(LoadNotificationsEvent()),
                    );
                  }

                  return RefreshIndicator(
                    color: const Color(0xFF6D6AFB),
                    backgroundColor: const Color(0xFF1F2343),
                    onRefresh: () async {
                      context.read<NotificationBloc>().add(LoadNotificationsEvent());
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: filteredList.length,
                      itemBuilder: (context, index) {
                        final notification = filteredList[index];
                        return NotificationItemWidget(
                          notification: notification,
                          onMarkAsRead: () {
                            context.read<NotificationBloc>().add(
                              MarkNotificationAsReadEvent(notification.id),
                            );
                          },
                          onDelete: () {
                            context.read<NotificationBloc>().add(
                              DeleteNotificationEvent(notification.id),
                            );
                          },
                        );
                      },
                    ),
                  );
                } else if (state is NotificationError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          'Oops, something went wrong',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          state.message,
                          style: GoogleFonts.poppins(color: Colors.grey),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () {
                            context.read<NotificationBloc>().add(LoadNotificationsEvent());
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6D6AFB),
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }
}
