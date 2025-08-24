
import 'package:flutter/material.dart';

class AccountWarningDialog extends StatelessWidget {
  final bool needEmailVerification;
  final bool needPhone;

  const AccountWarningDialog({
    super.key,
    this.needEmailVerification = false,
    this.needPhone = false,
  });

  @override
  Widget build(BuildContext context) {
    String message = '';
    if (needEmailVerification && needPhone) {
      message = 'You must verify your email and add a phone number before posting.';
    } else if (needEmailVerification) {
      message = 'Please verify your email before posting.';
    } else if (needPhone) {
      message = 'Please add a phone number before posting.';
    }

    return AlertDialog(
      title: const Text('Action Required'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
