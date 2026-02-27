const jwt = require('jsonwebtoken');
const pool = require('../config/database');

function setupSocket(io) {
  // Authentication middleware for Socket.IO
  io.use(async (socket, next) => {
    try {
      const token = socket.handshake.auth.token || socket.handshake.query.token;

      if (!token) {
        return next(new Error('Authentication required.'));
      }

      const decoded = jwt.verify(token, process.env.JWT_SECRET);

      const { rows } = await pool.query(
        'SELECT id, name, email, avatar_url, role FROM users WHERE id = $1',
        [decoded.userId]
      );

      if (rows.length === 0) {
        return next(new Error('User not found.'));
      }

      socket.user = rows[0];
      next();
    } catch (err) {
      next(new Error('Invalid token.'));
    }
  });

  io.on('connection', async (socket) => {
    const user = socket.user;
    console.log(`Socket connected: ${user.name} (${user.id})`);

    // Join personal room for direct notifications
    socket.join(`user:${user.id}`);

    // Join rooms for each project the user belongs to
    try {
      const { rows: memberships } = await pool.query(
        'SELECT project_id FROM project_members WHERE user_id = $1',
        [user.id]
      );

      for (const membership of memberships) {
        socket.join(`project:${membership.project_id}`);
      }

      console.log(`${user.name} joined ${memberships.length} project rooms`);
    } catch (err) {
      console.error('Error joining project rooms:', err.message);
    }

    // Handle joining a specific project room (e.g., after being added to a project)
    socket.on('join_project', (projectId) => {
      socket.join(`project:${projectId}`);
      console.log(`${user.name} joined project:${projectId}`);
    });

    // Handle leaving a project room
    socket.on('leave_project', (projectId) => {
      socket.leave(`project:${projectId}`);
      console.log(`${user.name} left project:${projectId}`);
    });

    // Handle typing indicator in tasks
    socket.on('typing', ({ projectId, taskId }) => {
      socket.to(`project:${projectId}`).emit('user_typing', {
        user_id: user.id,
        user_name: user.name,
        task_id: taskId,
      });
    });

    // Handle stop typing
    socket.on('stop_typing', ({ projectId, taskId }) => {
      socket.to(`project:${projectId}`).emit('user_stop_typing', {
        user_id: user.id,
        task_id: taskId,
      });
    });

    // Handle disconnect
    socket.on('disconnect', (reason) => {
      console.log(`Socket disconnected: ${user.name} (${reason})`);
    });
  });

  return io;
}

module.exports = setupSocket;
