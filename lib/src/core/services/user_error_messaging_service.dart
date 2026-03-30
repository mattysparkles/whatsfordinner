import 'package:flutter/material.dart';

class UserMessage {
  const UserMessage({required this.title, required this.details});

  final String title;
  final String details;
}

class UserErrorMessagingService {
  const UserErrorMessagingService();

  UserMessage map(Object error, {required String fallbackTitle}) {
    final message = error.toString();
    if (message.contains('SocketException') || message.contains('TimeoutException')) {
      return const UserMessage(
        title: 'Connection issue',
        details: 'Please check your network and try again.',
      );
    }
    return UserMessage(title: fallbackTitle, details: 'Please try again. ($message)');
  }

  void show(BuildContext context, {required UserMessage message}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${message.title}: ${message.details}')),
    );
  }
}
