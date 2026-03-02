import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/chat_provider.dart';
import '../../models/chat_channel.dart';

class ChatChannelsScreen extends StatefulWidget {
  const ChatChannelsScreen({super.key});

  @override
  State<ChatChannelsScreen> createState() => _ChatChannelsScreenState();
}

class _ChatChannelsScreenState extends State<ChatChannelsScreen> {
  String? _projectId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String && args != _projectId) {
      _projectId = args;
      context.read<ChatProvider>().loadChannels(_projectId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
      ),
      body: chatProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : chatProvider.channels.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: () => chatProvider.loadChannels(_projectId!),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: chatProvider.channels.length,
                    itemBuilder: (context, index) {
                      return _buildChannelCard(chatProvider.channels[index]);
                    },
                  ),
                ),
      floatingActionButton: _projectId != null
          ? FloatingActionButton.extended(
              onPressed: () => _showCreateChannel(),
              icon: const Icon(Icons.add),
              label: const Text('Novo Canal'),
            )
          : null,
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Nenhum canal de chat',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Crie um canal para começar a conversar',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelCard(ChatChannel channel) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryColor.withAlpha(25),
          child: Icon(
            channel.type == 'project' ? Icons.tag : Icons.work_outline,
            color: AppTheme.primaryColor,
          ),
        ),
        title: Text(
          channel.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          channel.lastMessage ?? 'Sem mensagens',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
        trailing: channel.messageCount > 0
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${channel.messageCount}',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : null,
        onTap: () {
          Navigator.pushNamed(context, '/chat/messages', arguments: {
            'channelId': channel.id,
            'channelName': channel.name,
            'projectId': _projectId,
          });
        },
      ),
    );
  }

  void _showCreateChannel() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Novo Canal'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Nome do canal',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty && _projectId != null) {
                await context.read<ChatProvider>().createChannel(
                  _projectId!,
                  name: name,
                );
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Criar'),
          ),
        ],
      ),
    );
  }
}
