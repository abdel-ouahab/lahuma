import 'package:flutter/foundation.dart';
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';

/// The system contact picker (Android `ACTION_PICK`, iOS
/// `CNContactPickerViewController`). The user picks one number; the app
/// gets only that, so no contacts permission is needed. Nothing is uploaded.
class ContactPicker {
  const ContactPicker();

  /// Null when the user cancels or the picker is unavailable.
  Future<({String name, String phone})?> pick() async {
    try {
      final contact = await FlutterNativeContactPicker().selectPhoneNumber();
      if (contact == null) return null;
      final phone = contact.selectedPhoneNumber ??
          (contact.phoneNumbers?.isNotEmpty ?? false
              ? contact.phoneNumbers!.first
              : null);
      if (phone == null || phone.trim().isEmpty) return null;
      return (name: contact.fullName?.trim() ?? '', phone: phone.trim());
    } catch (e) {
      debugPrint('Contact picker failed: $e');
      return null;
    }
  }
}
