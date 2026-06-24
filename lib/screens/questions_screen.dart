import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

/// Community questions. The admin opens a round with a topic; the community
/// asks questions and upvotes, hoping to be "mentioned" on the podcast.
class QuestionsScreen extends StatelessWidget {
  final VoidCallback onMenu;
  const QuestionsScreen({super.key, required this.onMenu});

  @override
  Widget build(BuildContext context) {
    final admin = store.isAdmin;
    // Sort: mentioned first, then by votes, then newest.
    final questions = [...store.questions]..sort((a, b) {
        if (a.mentioned != b.mentioned) return a.mentioned ? -1 : 1;
        if (a.votes.length != b.votes.length) {
          return b.votes.length.compareTo(a.votes.length);
        }
        return b.createdAt.compareTo(a.createdAt);
      });

    return Column(
      children: [
        ScreenHeader(
          title: 'Community Q&A',
          subtitle: 'GET MENTIONED ON THE SHOW',
          onMenu: onMenu,
          trailing: TagBadge(
            store.questionsOpen ? 'OPEN' : 'CLOSED',
            color: store.questionsOpen ? C.ok : C.muted,
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 6, 24, 140),
            physics: const BouncingScrollPhysics(),
            children: [
              _statusCard(context, admin),
              const SizedBox(height: 20),
              if (questions.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: EmptyState(
                    icon: Icons.forum_outlined,
                    title: 'No questions yet',
                    message:
                        'When a round is open, the community\'s questions show up here.',
                  ),
                )
              else
                ...questions.map((q) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _QuestionCard(question: q, admin: admin),
                    )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statusCard(BuildContext context, bool admin) {
    final open = store.questionsOpen;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: C.cardGradient,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.campaign_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Text(open ? 'Questions are OPEN' : 'Questions are closed',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            open
                ? (store.questionTopic.isEmpty
                    ? 'Ask anything — the admin reads the top questions on air.'
                    : 'This round\'s topic: ${store.questionTopic}')
                : 'The admin hasn\'t opened a round yet. Check back soon.',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 13.5,
                height: 1.4),
          ),
          const SizedBox(height: 18),
          if (admin)
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _openRoundDialog(context),
                    child: _miniBtn(
                        open ? 'Edit topic' : 'Open round',
                        open ? Icons.edit_rounded : Icons.play_arrow_rounded),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => store.setQuestionsOpen(!open),
                    child: _miniBtn(open ? 'Close round' : 'Reopen',
                        open ? Icons.stop_rounded : Icons.refresh_rounded),
                  ),
                ),
              ],
            )
          else
            PillButton(
              label: open ? 'Ask a question' : 'Round closed',
              icon: Icons.add_comment_rounded,
              onTap: open ? () => _askDialog(context) : null,
            ),
        ],
      ),
    );
  }

  Widget _miniBtn(String label, IconData icon) => Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      );

  Future<void> _openRoundDialog(BuildContext context) async {
    final res = await showComposer(
      context,
      heading: 'Open a question round',
      bodyHint: 'Topic for this round (e.g. "Transfer window special")',
      submitLabel: 'Open round',
    );
    if (res != null) store.setQuestionsOpen(true, topic: res.$2);
  }

  Future<void> _askDialog(BuildContext context) async {
    final res = await showComposer(
      context,
      heading: 'Ask the show',
      bodyHint: 'What do you want answered on the podcast?',
      submitLabel: 'Submit question',
    );
    if (res != null) store.addQuestion(res.$2);
  }
}

class _QuestionCard extends StatelessWidget {
  final Question question;
  final bool admin;
  const _QuestionCard({required this.question, required this.admin});

  @override
  Widget build(BuildContext context) {
    final me = store.currentUser!.username;
    final voted = question.votes.contains(me);
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InitialAvatar(name: question.author, size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('@${question.author}',
                        style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: C.ink)),
                    Text(timeAgo(question.createdAt),
                        style: const TextStyle(fontSize: 11.5, color: C.muted)),
                  ],
                ),
              ),
              if (question.mentioned)
                const TagBadge('ON THE SHOW', color: C.accent),
            ],
          ),
          const SizedBox(height: 12),
          Text(question.text,
              style: const TextStyle(
                  fontSize: 15, height: 1.4, color: C.ink, fontWeight: FontWeight.w500)),
          const SizedBox(height: 14),
          Row(
            children: [
              VoteChip(
                count: question.votes.length,
                active: voted,
                onTap: () => store.toggleQuestionVote(question.id),
              ),
              const Spacer(),
              if (admin)
                GestureDetector(
                  onTap: () => store.toggleMentioned(question.id),
                  child: Row(
                    children: [
                      Icon(
                          question.mentioned
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          size: 20,
                          color: C.accent),
                      const SizedBox(width: 5),
                      Text(question.mentioned ? 'Mentioned' : 'Mark for show',
                          style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: C.accent)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
