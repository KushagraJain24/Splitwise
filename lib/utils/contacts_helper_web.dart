import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'package:flutter/foundation.dart';

bool isWebContactsSupported() {
  try {
    return js_util.hasProperty(html.window.navigator, 'contacts');
  } catch (e) {
    return false;
  }
}

Future<List<Map<String, String>>> getBrowserContacts() async {
  try {
    final navigator = html.window.navigator;
    if (!js_util.hasProperty(navigator, 'contacts')) {
      return [];
    }
    final contactsApi = js_util.getProperty(navigator, 'contacts');
    final props = ['name', 'email'];
    final options = js_util.jsify({'multiple': true});
    
    final selectedContacts = await js_util.promiseToFuture<List<dynamic>>(
      js_util.callMethod(contactsApi, 'select', [props, options])
    );

    final List<Map<String, String>> contacts = [];
    for (var c in selectedContacts) {
      final names = js_util.getProperty<List<dynamic>?>(c, 'name');
      final emails = js_util.getProperty<List<dynamic>?>(c, 'email');

      final name = (names != null && names.isNotEmpty) ? names.first.toString().trim() : '';
      final email = (emails != null && emails.isNotEmpty) ? emails.first.toString().trim() : '';

      if (name.isNotEmpty && email.isNotEmpty) {
        contacts.add({
          'name': name,
          'email': email,
        });
      }
    }
    return contacts;
  } catch (e) {
    debugPrint("Error importing Web contacts: $e");
    return [];
  }
}
