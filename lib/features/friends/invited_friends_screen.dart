import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/phone_utils.dart';
import '../../data/models/app_user.dart';
import '../../data/models/invite.dart';
import '../../data/repositories/invite_repository.dart';
import '../../widgets/avatar.dart';
import '../../widgets/app_back_button.dart';

/// Figma frame 1:3317 -- name, phone, and a Cancel action per row.
///
/// The design shows every row as cancellable. Rows where the person has since
/// joined are marked "Joined" instead, because cancelling an invite that has
/// already been accepted would not mean anything.
class InvitedFriendsScreen extends ConsumerWidget {
  const InvitedFriendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitesAsync = ref.watch(myInvitesProvider);

    // Fire-and-forget: checks whether any invited number has since registered
    // and stamps acceptedUid, which is what flips the row to "Joined".
    ref.watch(resolveInvitesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.invitedFriends),
        leading: const AppBackButton(),
      ),
      body: invitesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const _Message(text: AppStrings.genericError),
        data: (invites) {
          if (invites.isEmpty) {
            return const _Message(text: AppStrings.noInvites);
          }

          // Cards with gaps, not divided rows -- matches the design.
          return ListView.separated(
            padding: const EdgeInsets.all(AppTheme.gutter),
            itemCount: invites.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) => _InviteRow(invite: invites[i]),
          );
        },
      ),
    );
  }
}

class _InviteRow extends ConsumerWidget {
  const _InviteRow({required this.invite});

  final Invite invite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppColors.gray20),
      ),
      child: Row(
        children: [
          Avatar(initials: AppUser.initialsOf(invite.name), size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invite.name.isEmpty ? invite.phone : invite.name,
                  style: AppTextStyles.rowLabelBold,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  PhoneUtils.pretty(invite.phone),
                  style: AppTextStyles.profileMeta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (invite.accepted)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.gray5,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                AppStrings.joined,
                style: AppTextStyles.profileMeta.copyWith(
                  color: AppColors.success,
                ),
              ),
            )
          else
            TextButton(
              onPressed: () =>
                  ref.read(inviteRepositoryProvider).cancel(invite.id),
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                AppStrings.cancelInvite,
                style: AppTextStyles.link.copyWith(color: AppColors.primary),
              ),
            ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppTheme.gutter),
      child: Text(text, style: AppTextStyles.body, textAlign: TextAlign.center),
    ),
  );
}
