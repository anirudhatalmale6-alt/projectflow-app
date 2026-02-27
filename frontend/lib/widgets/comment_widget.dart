import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../models/comment.dart';

class CommentWidget extends StatelessWidget {
  final Comment comment;
  final bool isOwn;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const CommentWidget({
    super.key,
    required this.comment,
    this.isOwn = false,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.secondaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                comment.author?.initials ?? '?',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.secondaryColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Comment content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: name + time
                Row(
                  children: [
                    Text(
                      comment.author?.name ?? 'Unknown',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTime(comment.createdAt),
                      style: AppTheme.caption,
                    ),
                    if (comment.isEdited) ...[
                      const SizedBox(width: 4),
                      Text(
                        '(edited)',
                        style: AppTheme.caption.copyWith(
                          fontStyle: FontStyle.italic,
                          fontSize: 10,
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (isOwn)
                      PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        iconSize: 18,
                        icon: Icon(
                          Icons.more_horiz_rounded,
                          color: AppTheme.textTertiary,
                          size: 18,
                        ),
                        onSelected: (value) {
                          if (value == 'edit') onEdit?.call();
                          if (value == 'delete') onDelete?.call();
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined, size: 18),
                                SizedBox(width: 8),
                                Text('Edit'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline, size: 18,
                                    color: AppTheme.errorColor),
                                SizedBox(width: 8),
                                Text('Delete',
                                    style: TextStyle(color: AppTheme.errorColor)),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),

                const SizedBox(height: 4),

                // Comment text with mention highlighting
                _buildCommentContent(comment.content),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentContent(String content) {
    final mentionRegex = RegExp(r'@(\w+)');
    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final match in mentionRegex.allMatches(content)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: content.substring(lastEnd, match.start),
          style: AppTheme.bodyMedium,
        ));
      }
      spans.add(TextSpan(
        text: match.group(0),
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppTheme.primaryColor,
          backgroundColor: AppTheme.primaryColor.withOpacity(0.08),
        ),
      ));
      lastEnd = match.end;
    }
    if (lastEnd < content.length) {
      spans.add(TextSpan(
        text: content.substring(lastEnd),
        style: AppTheme.bodyMedium,
      ));
    }

    return RichText(text: TextSpan(children: spans));
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inDays > 0) {
      return DateFormat('MMM d, h:mm a').format(dateTime);
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    }
    return 'just now';
  }
}
