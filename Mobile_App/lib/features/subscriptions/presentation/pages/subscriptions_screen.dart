import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/repositories/subscription_repository_impl.dart';
import '../../domain/usecases/cancel_subscription_usecase.dart';
import '../../domain/usecases/get_subscription_details_usecase.dart';
import '../../domain/usecases/get_subscriptions_usecase.dart';
import '../bloc/subscriptions_bloc.dart';
import '../bloc/subscriptions_event.dart';
import '../bloc/subscriptions_state.dart';
import '../widgets/subscription_card.dart';
import 'subscription_details_screen.dart';

class SubscriptionsScreen extends StatelessWidget {
  const SubscriptionsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final repo = SubscriptionRepositoryImpl();
    return BlocProvider(
      create: (context) => SubscriptionsBloc(
        getSubscriptionsUseCase: GetSubscriptionsUseCase(repo),
        getSubscriptionDetailsUseCase: GetSubscriptionDetailsUseCase(repo),
        cancelSubscriptionUseCase: CancelSubscriptionUseCase(repo),
      )..add(LoadSubscriptionsEvent()),
      child: Scaffold(
        backgroundColor: const Color(0xFF0D1025),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0D1025),
          elevation: 0,
          title: Text(
            'My Subscriptions',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          centerTitle: false,
        ),
        body: BlocBuilder<SubscriptionsBloc, SubscriptionsState>(
          builder: (context, state) {
            if (state is SubscriptionsLoading) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF6D6AFB)),
              );
            } else if (state is SubscriptionsLoaded) {
              if (state.subscriptions.isEmpty) {
                return Center(
                  child: Text(
                    'No subscriptions found.',
                    style: GoogleFonts.poppins(color: Colors.white70),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: state.subscriptions.length,
                itemBuilder: (context, index) {
                  final subscription = state.subscriptions[index];
                  return SubscriptionCard(
                    subscription: subscription,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BlocProvider.value(
                            value: BlocProvider.of<SubscriptionsBloc>(context),
                            child: SubscriptionDetailsScreen(
                              subscriptionId: subscription.id,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            } else if (state is SubscriptionsError) {
              return Center(
                child: Text(
                  state.message,
                  style: GoogleFonts.poppins(color: Colors.redAccent),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}
