import 'dart:async' show unawaited;
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/contacts_repository.dart';
import '../../../data/repositories/invite_repository.dart';
import '../../../widgets/avatar.dart';
import '../../../widgets/primary_button.dart';
import '../../../widgets/success_sheet.dart';

/// Figma frame "4. اختر خدمك..." -- the "Select user" bottom sheet.
///
/// The design draws two row states and this sheet maps them onto real data:
///   * a plain row  -> the contact already has a Listy account, tap to select
///   * an "Invite" link -> the contact is not registered, tap to share an invite
///
/// Returns the chosen [ContactEntry] (always a registered one) or null.
Future<ContactEntry?> showSelectUserSheet(BuildContext context) {
  return showModalBottomSheet<ContactEntry>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.white,
    barrierColor: AppColors.scrim,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => const _SelectUserSheet(),
  );
}

class _SelectUserSheet extends ConsumerStatefulWidget {
  const _SelectUserSheet();

  @override
  ConsumerState<_SelectUserSheet> createState() => _SelectUserSheetState();
}

class _SelectUserSheetState extends ConsumerState<_SelectUserSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Opens the SMS composer pre-addressed to [contact] with the invite text.
  ///
  /// This is aimed rather than generic: we already know exactly who is being
  /// invited and have their number, so a pre-filled message to that person
  /// beats a share sheet that asks the user to pick a recipient again.
  ///
  /// The two platforms disagree on the separator before `body` -- Android wants
  /// `?body=`, iOS wants `&body=` -- so the URI is assembled by hand rather
  /// than with Uri's query helpers.
  Future<void> _invite(ContactEntry contact) async {
    // Record the invite before opening the composer. We can't observe whether
    // the user actually hits send, so this optimistically logs the intent --
    // that's what the Invited Friends screen lists, and it stays cancellable.
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid != null) {
      unawaited(
        ref
            .read(inviteRepositoryProvider)
            .record(
              invitedByUid: uid,
              name: contact.displayName,
              phone: contact.phone,
            ),
      );
    }

    final body = Uri.encodeComponent(
      AppStrings.inviteMessage(contact.displayName),
    );
    final separator = Platform.isIOS ? '&' : '?';
    final uri = Uri.parse('sms:${contact.phone}${separator}body=$body');

    var launched = false;
    try {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // No messaging app, or the platform refused the intent.
      launched = false;
    }

    if (!mounted) return;

    if (!launched) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.cannotOpenMessages)),
      );
      return;
    }

    // Confirm only once the composer actually opened. The sheet is stacked
    // above the Select user sheet, so the user lands back on the picker and
    // can invite someone else without reopening it.
    await showInviteSentSheet(context, contact.displayName);
  }

  @override
  Widget build(BuildContext context) {
    final directoryAsync = ref.watch(contactDirectoryProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            const _Grabber(),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.gutter,
                4,
                AppTheme.gutter,
                12,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  AppStrings.selectUser,
                  style: AppTextStyles.heading.copyWith(fontSize: 20),
                ),
              ),
            ),
            // Only offer search once there is a loaded, non-empty directory.
            if (directoryAsync.valueOrNull?.isEmpty == false)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.gutter,
                  0,
                  AppTheme.gutter,
                  12,
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v),
                  style: AppTextStyles.input,
                  decoration: InputDecoration(
                    hintText: AppStrings.searchContacts,
                    prefixIcon: const Icon(
                      Icons.search,
                      color: AppColors.gray30,
                      size: 20,
                    ),
                    isDense: true,
                  ),
                ),
              ),
            const Divider(height: 1),
            Expanded(
              child: directoryAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => _ErrorState(
                  error: error,
                  onRetry: () => ref.invalidate(contactDirectoryProvider),
                ),
                data: (directory) {
                  final filtered = directory.search(_query);

                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        AppStrings.noContacts,
                        style: AppTextStyles.body,
                      ),
                    );
                  }

                  return ListView(
                    controller: scrollController,
                    padding: EdgeInsets.zero,
                    children: [
                      if (filtered.registered.isNotEmpty) ...[
                        _SectionHeader(
                          label: AppStrings.onListy,
                          count: filtered.registered.length,
                        ),
                        for (final contact in filtered.registered)
                          _ContactRow(
                            contact: contact,
                            onTap: () => Navigator.of(context).pop(contact),
                          ),
                      ],
                      if (filtered.invitable.isNotEmpty) ...[
                        _SectionHeader(
                          label: AppStrings.inviteToListy,
                          count: filtered.invitable.length,
                        ),
                        for (final contact in filtered.invitable)
                          _ContactRow(
                            contact: contact,
                            onInvite: () => _invite(contact),
                          ),
                      ],
                      const SizedBox(height: 24),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Grabber extends StatelessWidget {
  const _Grabber();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 5,
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.label,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.gray5,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.gutter,
        vertical: 8,
      ),
      child: Text('$label  ($count)', style: AppTextStyles.sectionHeader),
    );
  }
}

/// One contact row. Renders the "Invite" link only when [onInvite] is given,
/// which is what distinguishes an unregistered contact in the Figma design.
class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.contact, this.onTap, this.onInvite});

  final ContactEntry contact;
  final VoidCallback? onTap;
  final VoidCallback? onInvite;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.gutter,
              vertical: 12,
            ),
            child: Row(
              children: [
                Avatar(
                  photo: contact.photo,
                  photoUrl: contact.registeredUser?.photoUrl,
                  initials: contact.initials,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contact.displayName,
                        style: AppTextStyles.rowLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (contact.displayName != contact.phone)
                        Text(
                          contact.phone,
                          style: AppTextStyles.profileMeta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (onInvite != null)
                  TextButton(
                    onPressed: onInvite,
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      AppStrings.invite,
                      style: AppTextStyles.link.copyWith(
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.link,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Contacts permission is the most common failure here, so it gets a real
/// explanation and a route into system settings rather than a bare error.
class _ErrorState extends ConsumerWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final denial = error is ContactsPermissionDenied
        ? error as ContactsPermissionDenied
        : null;

    // Only send the user to system settings when the OS will no longer prompt.
    // If they can still be asked, retrying re-triggers the native dialog, which
    // is far less friction than a trip through Settings.
    final needsSettings = denial?.permanently ?? false;

    return Padding(
      padding: const EdgeInsets.all(AppTheme.gutter),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            denial != null ? Icons.contacts_outlined : Icons.error_outline,
            size: 40,
            color: AppColors.gray30,
          ),
          const SizedBox(height: 16),
          Text(
            denial != null
                ? AppStrings.contactsPermissionTitle
                : AppStrings.genericError,
            style: AppTextStyles.rowLabelBold,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            denial != null ? AppStrings.contactsPermissionBody : '$error',
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (needsSettings)
            PrimaryButton(
              label: AppStrings.openSettings,
              onPressed: () async {
                await ref.read(contactsRepositoryProvider).openSettings();
                onRetry();
              },
            )
          else
            PrimaryButton(
              label: denial != null ? AppStrings.grantAccess : 'Try again',
              onPressed: onRetry,
            ),
        ],
      ),
    );
  }
}
