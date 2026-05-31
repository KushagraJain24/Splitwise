import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:splitwise/utils/constants.dart';

class InviteHelper {
  static Future<void> launchEmailInvite(String email, {String? groupName}) async {
    final groupText = groupName != null ? ' to the group "$groupName"' : '';
    final subject = Uri.encodeComponent('Join me on Splitwise!');
    final body = Uri.encodeComponent('Hey, I have added you$groupText on our Splitwise app. Please register at https://splitwise-3fcdd.web.app to view and settle your expenses!');
    final url = Uri.parse('mailto:$email?subject=$subject&body=$body');
    try {
      await launchUrl(url);
    } catch (e) {
      debugPrint("Could not launch email: $e");
    }
  }

  static Future<void> launchWhatsAppInvite(String phone, {String? groupName}) async {
    final groupText = groupName != null ? ' to the group "$groupName"' : '';
    final body = Uri.encodeComponent('Hey, I have added you$groupText on our Splitwise app. Please register at https://splitwise-3fcdd.web.app to view and settle your expenses!');
    
    var cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.length == 10) {
      cleanPhone = '91$cleanPhone';
    }
    
    final url = Uri.parse('https://wa.me/$cleanPhone?text=$body');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint("Could not launch WhatsApp: $e");
    }
  }

  static void showInviteChannelsDialog(BuildContext context, String emailOrPhone, {String? groupName}) {
    final isEmail = emailOrPhone.contains('@');
    final groupText = groupName != null ? ' to the group "$groupName"' : '';
    final messagePreview = 'Hey, I have added you$groupText on our Splitwise app. Please register at https://splitwise-3fcdd.web.app to view and settle your expenses!';

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppConstants.cardDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.white10)),
          title: const Text('Invite Preview', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Here is a preview of the invite message to be sent to $emailOrPhone:',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Text(
                  messagePreview,
                  style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
          actions: isEmail
              ? [
                  TextButton.icon(
                    icon: const Icon(Icons.email, color: AppConstants.accentTeal),
                    label: const Text('Send Email', style: TextStyle(color: AppConstants.accentTeal)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      launchEmailInvite(emailOrPhone, groupName: groupName);
                    },
                  ),
                  TextButton(
                    child: const Text('Cancel', style: TextStyle(color: Colors.white30)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ]
              : [
                  TextButton.icon(
                    icon: const Icon(Icons.chat, color: Colors.green),
                    label: const Text('WhatsApp', style: TextStyle(color: Colors.green)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      launchWhatsAppInvite(emailOrPhone, groupName: groupName);
                    },
                  ),
                  TextButton(
                    child: const Text('Cancel', style: TextStyle(color: Colors.white30)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
        );
      },
    );
  }
}
