import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:intl/intl.dart';
import '../../config/api_config.dart';
import '../../config/theme.dart';
import '../../models/review.dart';
import '../../providers/auth_provider.dart';
import '../../services/review_service.dart';
import '../../services/api_service.dart';

class ReviewPlayerScreen extends StatefulWidget {
  const ReviewPlayerScreen({super.key});

  @override
  State<ReviewPlayerScreen> createState() => _ReviewPlayerScreenState();
}

class _ReviewPlayerScreenState extends State<ReviewPlayerScreen> {
  final ReviewService _reviewService = ReviewService();
  final _commentController = TextEditingController();

  // Args
  String? _reviewId;
  String? _jobId;
  String? _videoUrl;
  String? _assetName;

  // State
  Review? _review;
  List<ReviewComment> _comments = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _error;

  // Video
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _videoReady = false;
  String _currentTimecode = '00:00:00';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic> && args['reviewId'] != _reviewId) {
      _reviewId = args['reviewId'] as String?;
      _jobId = args['jobId'] as String?;
      _videoUrl = args['videoUrl'] as String?;
      _assetName = args['assetName'] as String? ?? 'Review';
      _loadData();
      if (_videoUrl != null && _videoUrl!.isNotEmpty) {
        _initVideo();
      }
    }
  }

  Future<void> _initVideo() async {
    if (_videoUrl == null) return;

    // Build full URL if relative
    String url = _videoUrl!;
    if (!url.startsWith('http')) {
      url = '${ApiConfig.baseUrl}$url';
    }

    try {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(url));
      await _videoController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: false,
        looping: false,
        showControls: true,
        allowFullScreen: true,
        allowMuting: true,
        placeholder: Container(
          color: Colors.black,
          child: const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
      );

      // Listen for position updates to show timecode
      _videoController!.addListener(_onVideoPositionChanged);

      if (mounted) {
        setState(() => _videoReady = true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Erro ao carregar vídeo: $e');
      }
    }
  }

  void _onVideoPositionChanged() {
    if (_videoController == null || !_videoController!.value.isInitialized) return;
    final pos = _videoController!.value.position;
    final tc = _formatDuration(pos);
    if (tc != _currentTimecode && mounted) {
      setState(() => _currentTimecode = tc);
    }
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (_reviewId != null) {
        _comments = await _reviewService.getComments(_reviewId!);
      }
      if (_jobId != null) {
        final reviews = await _reviewService.getReviews(_jobId!);
        _review = reviews.firstWhere(
          (r) => r.id == _reviewId,
          orElse: () => reviews.isNotEmpty ? reviews.first : reviews.first,
        );
      }
    } catch (e) {
      _error = 'Erro ao carregar dados: $e';
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _reviewId == null) return;

    setState(() => _isSending = true);

    try {
      final comment = await _reviewService.addComment(
        _reviewId!,
        content: text,
        timecode: _currentTimecode,
      );
      _comments.add(comment);
      _commentController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    }

    if (mounted) setState(() => _isSending = false);
  }

  void _seekToTimecode(String? timecode) {
    if (timecode == null || _videoController == null) return;
    final parts = timecode.split(':');
    Duration target;
    if (parts.length == 3) {
      target = Duration(
        hours: int.tryParse(parts[0]) ?? 0,
        minutes: int.tryParse(parts[1]) ?? 0,
        seconds: int.tryParse(parts[2]) ?? 0,
      );
    } else if (parts.length == 2) {
      target = Duration(
        minutes: int.tryParse(parts[0]) ?? 0,
        seconds: int.tryParse(parts[1]) ?? 0,
      );
    } else {
      return;
    }
    _videoController!.seekTo(target);
    _videoController!.play();
  }

  Future<void> _updateReviewStatus(String status) async {
    if (_reviewId == null) return;
    try {
      final updated = await _reviewService.updateReview(_reviewId!, status: status);
      setState(() => _review = updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status atualizado: ${updated.statusLabel}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _videoController?.removeListener(_onVideoPositionChanged);
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isWide = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      appBar: AppBar(
        title: Text(_assetName ?? 'Player de Review'),
        actions: [
          if (_review != null)
            _buildStatusChip(_review!.status),
          const SizedBox(width: 8),
          if (_review != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: _updateReviewStatus,
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'approved', child: Text('Aprovar')),
                const PopupMenuItem(value: 'rejected', child: Text('Rejeitar')),
                const PopupMenuItem(value: 'revision_requested', child: Text('Solicitar Revisão')),
              ],
            ),
        ],
      ),
      body: isWide ? _buildWideLayout() : _buildNarrowLayout(),
    );
  }

  Widget _buildWideLayout() {
    return Row(
      children: [
        // Video player (left side - 60%)
        Expanded(
          flex: 6,
          child: Column(
            children: [
              Expanded(child: _buildVideoPlayer()),
              _buildTimecodeBar(),
            ],
          ),
        ),
        // Comments panel (right side - 40%)
        Expanded(
          flex: 4,
          child: _buildCommentsPanel(),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout() {
    return Column(
      children: [
        // Video player (top)
        SizedBox(
          height: 240,
          child: _buildVideoPlayer(),
        ),
        _buildTimecodeBar(),
        // Comments (bottom, scrollable)
        Expanded(child: _buildCommentsPanel()),
      ],
    );
  }

  Widget _buildVideoPlayer() {
    if (_videoUrl == null || _videoUrl!.isEmpty) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.videocam_off, size: 48, color: Colors.grey[600]),
              const SizedBox(height: 12),
              Text(
                'Nenhum vídeo disponível',
                style: TextStyle(color: Colors.grey[500], fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                'Faça upload de um asset de vídeo no job para revisar',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    if (!_videoReady) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 12),
              Text(
                'Carregando vídeo...',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: Colors.black,
      child: Chewie(controller: _chewieController!),
    );
  }

  Widget _buildTimecodeBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey[900],
      child: Row(
        children: [
          // Current timecode
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _currentTimecode,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Duration
          if (_videoController != null && _videoController!.value.isInitialized)
            Text(
              '/ ${_formatDuration(_videoController!.value.duration)}',
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
          const Spacer(),
          // Comment count
          Icon(Icons.comment, color: Colors.grey[500], size: 16),
          const SizedBox(width: 4),
          Text(
            '${_comments.length}',
            style: TextStyle(color: Colors.grey[400], fontSize: 13),
          ),
          const SizedBox(width: 12),
          // Quick add comment at current timecode
          TextButton.icon(
            onPressed: () {
              // Focus on comment input
              FocusScope.of(context).requestFocus(FocusNode());
            },
            icon: const Icon(Icons.add_comment, size: 16),
            label: const Text('Comentar aqui', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white70,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsPanel() {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Icon(Icons.rate_review, color: AppTheme.primaryColor, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Comentários da Revisão',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                const Spacer(),
                Text(
                  '${_comments.length}',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // Comments list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _comments.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline, size: 40, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            Text(
                              'Nenhum comentário ainda',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Pause o vídeo e adicione um comentário',
                              style: TextStyle(color: Colors.grey[500], fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _comments.length,
                        itemBuilder: (context, index) {
                          return _buildCommentTile(_comments[index]);
                        },
                      ),
          ),
          // Comment input
          _buildCommentInput(),
        ],
      ),
    );
  }

  Widget _buildCommentTile(ReviewComment comment) {
    return InkWell(
      onTap: comment.timecode != null ? () => _seekToTimecode(comment.timecode) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timecode badge
            if (comment.timecode != null && comment.timecode!.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(right: 10, top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppTheme.primaryColor.withAlpha(50)),
                ),
                child: Text(
                  comment.timecode!,
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            // Comment content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        comment.userName ?? 'Usuário',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      if (comment.createdAt != null)
                        Text(
                          DateFormat('dd/MM HH:mm').format(comment.createdAt!),
                          style: TextStyle(color: Colors.grey[500], fontSize: 11),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    comment.content,
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Timecode indicator
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.access_time, size: 12, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Timecode: $_currentTimecode',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'Adicionar comentário...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      isDense: true,
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _addComment(),
                    maxLines: null,
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: AppTheme.primaryColor,
                  radius: 18,
                  child: _isSending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.send, color: Colors.white, size: 16),
                          onPressed: _addComment,
                          padding: EdgeInsets.zero,
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'approved':
        color = Colors.green;
        break;
      case 'rejected':
        color = Colors.red;
        break;
      case 'revision_requested':
        color = Colors.orange;
        break;
      case 'in_progress':
        color = Colors.blue;
        break;
      default:
        color = Colors.grey;
    }

    final review = _review;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(
        review?.statusLabel ?? status,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
