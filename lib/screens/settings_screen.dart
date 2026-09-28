import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/strings.dart';
import '../services/ad_service.dart';
import '../services/iap_service.dart';
import '../services/storage_service.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _privacyOptions = false;

  @override
  void initState() {
    super.initState();
    context.read<AdService>().privacyOptionsRequired().then((v) {
      if (mounted) setState(() => _privacyOptions = v);
    });
  }

  Future<void> _buy() async {
    // The Play billing sheet backgrounds the app; don't greet the player
    // with an App Open ad when it closes.
    context.read<AdService>().skipNextAppOpen();
    final ok = await context.read<IapService>().buyRemoveAds();
    if (!ok && mounted) {
      showSnack(context, context.tr('storeUnavailable'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<StorageService>();
    final iap = context.watch<IapService>();
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('settings'))),
      body: ListView(
        children: [
          SwitchListTile(
            title: Text(context.tr('sound')),
            secondary: Icon(s.muted ? Icons.volume_off : Icons.volume_up),
            value: !s.muted,
            onChanged: (v) => s.setMuted(!v),
          ),
          SwitchListTile(
            title: Text(context.tr('vibration')),
            secondary: const Icon(Icons.vibration),
            value: s.vibration,
            onChanged: s.setVibration,
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(context.tr('language')),
            trailing: DropdownButton<String>(
              value: s.language,
              underline: const SizedBox.shrink(),
              onChanged: (v) {
                if (v != null) s.setLanguage(v);
              },
              items: [
                DropdownMenuItem(
                  value: 'system',
                  child: Text(context.tr('langSystem')),
                ),
                const DropdownMenuItem(value: 'en', child: Text('English')),
                const DropdownMenuItem(value: 'ar', child: Text('العربية')),
              ],
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.block),
            title: Text(
              s.adsRemoved ? context.tr('adsRemoved') : context.tr('removeAds'),
            ),
            subtitle: s.adsRemoved
                ? null
                : Text(
                    [
                      ?iap.product?.price,
                      context.tr('removeAdsSub'),
                    ].join(' • '),
                  ),
            onTap: s.adsRemoved ? null : _buy,
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: Text(context.tr('restore')),
            onTap: () {
              context.read<AdService>().skipNextAppOpen();
              iap.restore();
            },
          ),
          const Divider(),
          if (_privacyOptions)
            ListTile(
              leading: const Icon(Icons.manage_accounts),
              title: Text(context.tr('privacyOptions')),
              onTap: () => context.read<AdService>().showPrivacyOptions(),
            ),
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: Text(context.tr('privacy')),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => openPrivacyPolicy(context),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(context.tr('about')),
            subtitle: Text(context.tr('version', {'v': appVersion})),
          ),
        ],
      ),
    );
  }
}
