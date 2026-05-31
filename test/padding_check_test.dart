import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

void main() {
  test('check Padding', () {
    // This will fail compile time if Padding is not defined or if there is a conflict
    print(Padding); 
  });
}
