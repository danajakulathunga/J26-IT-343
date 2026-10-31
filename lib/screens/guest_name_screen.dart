import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bananaguard_ai/providers/auth_provider.dart';

import 'package:bananaguard_ai/providers/locale_provider.dart';

class GuestNameScreen extends ConsumerStatefulWidget {
  const GuestNameScreen({super.key});

  @override
  ConsumerState<GuestNameScreen> createState() => _GuestNameScreenState();
}

class _GuestNameScreenState extends ConsumerState<GuestNameScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final name = _nameController.text.trim();
    final success = await ref.read(authProvider.notifier).loginAsGuest(name);

    if (success && mounted) {
      context.go('/home');
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = ref.watch(localeProvider).languageCode;

    final appTitle = lang == 'si'
        ? 'අමුත්තන්ගේ මාදිලිය'
        : (lang == 'ta' ? 'விருந்தினர் பயன்முறை' : 'Guest Mode');
    final headingText = lang == 'si'
        ? 'ඔබගේ නම කුමක්ද?'
        : (lang == 'ta' ? 'உங்கள் பெயர் என்ன?' : 'What is your name?');
    final subText = lang == 'si'
        ? 'ඔබගේ නම වාර්තා සහ මුල් පිටුව සඳහා භාවිත වේ. විද්‍යුත් තැපෑලක් හෝ මුරපදයක් අවශ්‍ය නොවේ!'
        : (lang == 'ta'
            ? 'உங்கள் பெயர் அறிக்கைகள் மற்றும் முகப்பு வாழ்த்துகளுக்கு பயன்படுத்தப்படும். மின்னஞ்சல் அல்லது கடவுச்சொல் தேவையில்லை!'
            : 'Your name will be personalized in diagnostic reports and dashboard greetings. No email or password needed!');
    final labelName = lang == 'si'
        ? 'ඔබගේ නම'
        : (lang == 'ta' ? 'உங்கள் பெயர்' : 'Your Name');
    final hintName = lang == 'si'
        ? 'උදා. කසුන් / නිමල්'
        : (lang == 'ta' ? 'எ.கா. கசுன் / நிமால்' : 'e.g. Kasun / Nimal');
    final validatorMsg = lang == 'si'
        ? 'ඉදිරියට යාමට කරුණාකර ඔබගේ නම ඇතුළත් කරන්න'
        : (lang == 'ta' ? 'தொடர உங்கள் பெயரை உள்ளிடவும்' : 'Please enter your name to proceed');
    final startBtnText = lang == 'si'
        ? 'පරීක්ෂාව අරඹන්න'
        : (lang == 'ta' ? 'ஸ்கேன் செய்யத் தொடங்குங்கள்' : 'Start Scanning');

    return Scaffold(
      appBar: AppBar(
        title: Text(appTitle),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headingText,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.75),
                  ),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: labelName,
                    hintText: hintName,
                    prefixIcon: const Icon(Icons.badge_outlined),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return validatorMsg;
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _continue(),
                ),
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: _isLoading ? null : _continue,
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : Text(startBtnText),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
