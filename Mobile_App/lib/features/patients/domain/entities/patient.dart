import 'package:equatable/equatable.dart';

class Patient extends Equatable {
  final String id;
  final String name;
  final String gender;
  final String phoneNumber;
  final String email;
  final String bloodGroup;
  final String condition;
  final DateTime lastVisit;
  final String status;
  final String address;

  const Patient({
    required this.id,
    required this.name,
    required this.gender,
    required this.phoneNumber,
    required this.email,
    required this.bloodGroup,
    required this.condition,
    required this.lastVisit,
    required this.status,
    this.address = '',
  });

  @override
  List<Object?> get props => [
        id,
        name,
        gender,
        phoneNumber,
        email,
        bloodGroup,
        condition,
        lastVisit,
        status,
        address,
      ];
}
