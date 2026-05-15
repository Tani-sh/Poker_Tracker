import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../services/auth_service.dart';

/// Bottom sheet for picking a phone contact to link to a player or add to a game.
class ContactPickerSheet extends StatefulWidget {
  final void Function(String name, String phoneNumber) onContactSelected;

  const ContactPickerSheet({super.key, required this.onContactSelected});

  @override
  State<ContactPickerSheet> createState() => _ContactPickerSheetState();
}

class _ContactPickerSheetState extends State<ContactPickerSheet> {
  List<Contact>? _contacts;
  List<Contact> _filtered = [];
  bool _loading = true;
  bool _permissionDenied = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    try {
      final hasPermission = await FlutterContacts.requestPermission(readonly: true);
      if (!hasPermission) {
        if (mounted) setState(() { _permissionDenied = true; _loading = false; });
        return;
      }

      final contacts = await FlutterContacts.getContacts(withProperties: true);
      
      // Only contacts with at least one phone number
      final withPhones = contacts.where((c) => c.phones.isNotEmpty).toList();
      withPhones.sort((a, b) => a.displayName.compareTo(b.displayName));

      if (mounted) {
        setState(() {
          _contacts = withPhones;
          _filtered = withPhones;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading contacts: $e');
      if (mounted) {
        setState(() { _loading = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load contacts: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _filterContacts(String query) {
    if (_contacts == null) return;
    final lower = query.toLowerCase();
    setState(() {
      _filtered = _contacts!
          .where((c) => c.displayName.toLowerCase().contains(lower) ||
              c.phones.any((p) => p.number.contains(query)))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade600,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('📱 Pick from Contacts',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              // Search bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  onChanged: _filterContacts,
                  decoration: InputDecoration(
                    hintText: 'Search contacts...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Contact list
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _permissionDenied
                        ? const Center(child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Text('Contact permission denied.\nEnable it in Settings.',
                                textAlign: TextAlign.center),
                          ))
                        : _filtered.isEmpty
                            ? Center(child: Text('No contacts found',
                                style: TextStyle(color: Colors.grey.shade500)))
                            : ListView.builder(
                                controller: scrollController,
                                itemCount: _filtered.length,
                                itemBuilder: (context, index) {
                                  final contact = _filtered[index];
                                  final phone = contact.phones.first.number;
                                  final normalized = AuthService.normalizePhone(phone);

                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.teal.withValues(alpha: 0.2),
                                      child: Text(contact.displayName.isNotEmpty
                                          ? contact.displayName[0].toUpperCase()
                                          : '?',
                                        style: const TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                    title: Text(contact.displayName,
                                        style: const TextStyle(fontWeight: FontWeight.w500)),
                                    subtitle: Text(phone,
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                                    trailing: const Icon(Icons.add_circle_outline, size: 20),
                                    onTap: () {
                                      widget.onContactSelected(
                                        contact.displayName,
                                        normalized,
                                      );
                                      Navigator.pop(context);
                                    },
                                  );
                                },
                              ),
              ),
            ],
          ),
        );
      },
    );
  }
}
