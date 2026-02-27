const express = require('express');
const Comment = require('../models/Comment');
const Task = require('../models/Task');
const Project = require('../models/Project');
const Notification = require('../models/Notification');
const auth = require('../middleware/auth');
const { parseMentions } = require('../utils/mentions');
const pool = require('../config/database');

const router = express.Router();

// GET /api/tasks/:taskId/comments - list comments
router.get('/:taskId/comments', auth, async (req, res, next) => {
  try {
    const task = await Task.findById(req.params.taskId);
    if (!task) {
      return res.status(404).json({ error: 'Task not found.' });
    }

    // Check membership
    const membership = await Project.isMember(task.project_id, req.user.id);
    if (!membership && req.user.role !== 'admin') {
      return res.status(403).json({ error: 'Access denied.' });
    }

    const comments = await Comment.findByTaskId(req.params.taskId);

    // Attach mentions to each comment
    const commentsWithMentions = await Promise.all(
      comments.map(async (comment) => {
        const mentions = await Comment.getMentions(comment.id);
        return { ...comment, mentions };
      })
    );

    res.json({ comments: commentsWithMentions });
  } catch (err) {
    next(err);
  }
});

// POST /api/tasks/:taskId/comments - create comment
router.post('/:taskId/comments', auth, async (req, res, next) => {
  try {
    const task = await Task.findById(req.params.taskId);
    if (!task) {
      return res.status(404).json({ error: 'Task not found.' });
    }

    // Check membership
    const membership = await Project.isMember(task.project_id, req.user.id);
    if (!membership && req.user.role !== 'admin') {
      return res.status(403).json({ error: 'Access denied.' });
    }

    const { content } = req.body;

    if (!content || typeof content !== 'string' || content.trim().length === 0) {
      return res.status(400).json({ error: 'Comment content is required.' });
    }

    // Create comment
    const comment = await Comment.create({
      taskId: req.params.taskId,
      userId: req.user.id,
      content: content.trim(),
    });

    // Parse @mentions and create mention records
    const mentionedUsers = await parseMentions(content);
    if (mentionedUsers.length > 0) {
      const mentionUserIds = mentionedUsers.map((u) => u.id);
      await Comment.addMentions(comment.id, mentionUserIds);

      // Create mention notifications (exclude self)
      const mentionNotifications = mentionedUsers
        .filter((u) => u.id !== req.user.id)
        .map((u) => ({
          userId: u.id,
          type: 'mention',
          title: `${req.user.name} mentioned you in a comment`,
          message: `In task "${task.title}": ${content.substring(0, 200)}`,
          referenceId: task.id,
          referenceType: 'task',
        }));

      if (mentionNotifications.length > 0) {
        await Notification.createBulk(mentionNotifications);

        const io = req.app.get('io');
        if (io) {
          for (const n of mentionNotifications) {
            io.to(`user:${n.userId}`).emit('notification', {
              type: 'mention',
              title: n.title,
              task_id: task.id,
              comment_id: comment.id,
            });
          }
        }
      }
    }

    // Notify task assignee and reporter about the comment (if not self and not already mentioned)
    const mentionedIds = new Set(mentionedUsers.map((u) => u.id));
    const notifyUserIds = new Set();

    if (task.assignee_id && task.assignee_id !== req.user.id && !mentionedIds.has(task.assignee_id)) {
      notifyUserIds.add(task.assignee_id);
    }
    if (task.reporter_id && task.reporter_id !== req.user.id && !mentionedIds.has(task.reporter_id)) {
      notifyUserIds.add(task.reporter_id);
    }

    if (notifyUserIds.size > 0) {
      const commentNotifications = [];
      for (const uid of notifyUserIds) {
        commentNotifications.push({
          userId: uid,
          type: 'comment',
          title: `New comment on "${task.title}"`,
          message: `${req.user.name}: ${content.substring(0, 200)}`,
          referenceId: task.id,
          referenceType: 'task',
        });
      }
      await Notification.createBulk(commentNotifications);

      const io = req.app.get('io');
      if (io) {
        for (const uid of notifyUserIds) {
          io.to(`user:${uid}`).emit('notification', {
            type: 'comment',
            title: `New comment on "${task.title}"`,
            task_id: task.id,
            comment_id: comment.id,
          });
        }
      }
    }

    // Log activity
    await pool.query(
      `INSERT INTO activity_log (project_id, user_id, action, entity_type, entity_id, details)
       VALUES ($1, $2, 'commented', 'task', $3, $4)`,
      [task.project_id, req.user.id, task.id, JSON.stringify({
        task_title: task.title,
        comment_preview: content.substring(0, 100),
      })]
    );

    // Emit socket event to project room
    const io = req.app.get('io');
    if (io) {
      io.to(`project:${task.project_id}`).emit('comment_added', {
        ...comment,
        user_name: req.user.name,
        user_avatar: req.user.avatar_url,
        task_id: task.id,
        mentions: mentionedUsers,
      });
    }

    // Fetch full comment with user info
    const fullComment = await Comment.findById(comment.id);
    const mentions = await Comment.getMentions(comment.id);

    res.status(201).json({ comment: { ...fullComment, mentions } });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
