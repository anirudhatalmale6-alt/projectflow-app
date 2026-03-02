import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../models/chat_message.dart';
import 'package:intl/intl.dart';

class ChatMessagesScreen extends StatefulWidget {
  const ChatMessagesScreen({super.key});

  @override
  State<ChatMessagesScreen> createState() => _ChatMessagesScreenState();
}

class _ChatMessagesScreenState extends State<ChatMessagesScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  String? _channelId;
  String? _channelName;
  String? _projectId;
  Timer? _typingTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic> && args['channelId'] != _channelId) {
      _channelId = args['channelId'] as String;
      _channelName = args['channelName'] as String? ?? 'Chat';
      _projectId = args['projectId'] as String?;

      final chat = context.read<ChatProvider>();
      // Make sure we're joined to the project room
      if (_projectId != null) {
        chat.joinProject(_projectId!);
      }
      chat.loadMessages(_channelId!);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    // Clean up when leaving chat
    try {
      final chat = context.read<ChatProvider>();
      chat.clearMessages();
      chat.leaveProject();
    } catch (_) {}
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onTextChanged(String text) {
    if (_channelId == null) return;
    final chat = context.read<ChatProvider>();

    // Send typing event
    chat.sendTyping(_channelId!);

    // Reset timer - stop typing after 2 seconds of inactivity
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      chat.sendStopTyping(_channelId!);
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _channelId == null) return;

    _messageController.clear();
    _typingTimer?.cancel();
    final chat = context.read<ChatProvider>();
    chat.sendStopTyping(_channelId!);

    final sent = await chat.sendMessage(_channelId!, text);
    if (sent) _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final auth = context.watch<AuthProvider>();
    final currentUserId = auth.user?.id;

    if (chatProvider.messages.isNotEmpty) {
      _scrollToBottom();
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_channelName ?? 'Chat', style: const TextStyle(fontSize: 16)),
            if (chatProvider.typingUser != null)
              Text(
                '${chatProvider.typingUser} está digitando...',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.primaryColor,
                  fontStyle: FontStyle.italic,
                ),
              )
            else
              Text(
                '${chatProvider.messages.length} mensagens',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: chatProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : chatProvider.messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline,
                                size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 12),
                            Text(
                              'Nenhuma mensagem ainda',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Envie a primeira mensagem!',
                              style: TextStyle(
                                  color: Colors.grey[500], fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(12),
                        itemCount: chatProvider.messages.length,
                        itemBuilder: (context, index) {
                          final msg = chatProvider.messages[index];
                          final isMe = msg.userId == currentUserId;
                          final showName = !isMe &&
                              (index == 0 ||
                                  chatProvider.messages[index - 1].userId !=
                                      msg.userId);
                          final showDate = index == 0 ||
                              _isDifferentDay(
                                chatProvider.messages[index - 1].createdAt,
                                msg.createdAt,
                              );
                          return Column(
                            children: [
                              if (showDate) _buildDateDivider(msg.createdAt),
                              _buildMessage(msg, isMe, showName),
                            ],
                          );
                        },
                      ),
          ),
          _buildInput(),
        ],
      ),
    );
  }

  bool _isDifferentDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return true;
    return a.day != b.day || a.month != b.month || a.year != b.year;
  }

  Widget _buildDateDivider(DateTime? date) {
    final text = date != null
        ? _isToday(date)
            ? 'Hoje'
            : _isYesterday(date)
                ? 'Ontem'
                : DateFormat('dd/MM/yyyy').format(date)
        : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.grey[300])),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Divider(color: Colors.grey[300])),
        ],
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.day == now.day &&
        date.month == now.month &&
        date.year == now.year;
  }

  bool _isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return date.day == yesterday.day &&
        date.month == yesterday.month &&
        date.year == yesterday.year;
  }

  Widget _buildMessage(ChatMessage msg, bool isMe, bool showName) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: 4,
          top: showName ? 12 : 2,
          left: isMe ? 60 : 0,
          right: isMe ? 0 : 60,
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (showName)
              Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 12),
                child: Text(
                  msg.userName ?? 'Usuário',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? AppTheme.primaryColor : Colors.grey[200],
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    msg.content,
                    style: TextStyle(
                      color: isMe ? Colors.white : Colors.black87,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    msg.createdAt != null
                        ? DateFormat('HH:mm').format(msg.createdAt!)
                        : '',
                    style: TextStyle(
                      fontSize: 10,
                      color:
                          isMe ? Colors.white.withAlpha(179) : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Digite uma mensagem...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                textInputAction: TextInputAction.send,
                onChanged: _onTextChanged,
                onSubmitted: (_) => _sendMessage(),
                maxLines: null,
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: AppTheme.primaryColor,
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white, size: 20),
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
