require('dotenv').config();

const express = require('express');
const http = require('http');
const cors = require('cors');
const { Server } = require('socket.io');

const errorHandler = require('./middleware/errorHandler');
const setupSocket = require('./socket');

// Route imports
const authRoutes = require('./routes/auth');
const clientRoutes = require('./routes/clients');
const projectRoutes = require('./routes/projects');
const taskRoutes = require('./routes/tasks');
const deliveryRoutes = require('./routes/deliveries');
const approvalRoutes = require('./routes/approvals');
const commentRoutes = require('./routes/comments');
const notificationRoutes = require('./routes/notifications');
const dashboardRoutes = require('./routes/dashboard');
const adminRoutes = require('./routes/admin');

const app = express();
const server = http.createServer(app);

// CORS configuration
const corsOptions = {
  origin: process.env.CORS_ORIGIN || 'http://localhost:5173',
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  credentials: true,
};

app.use(cors(corsOptions));

// Socket.IO setup
const io = new Server(server, {
  cors: corsOptions,
  pingTimeout: 60000,
  pingInterval: 25000,
});

// Make io accessible in routes
app.set('io', io);

// Setup Socket.IO event handlers
setupSocket(io);

// Body parsing middleware
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Request logging in development
if (process.env.NODE_ENV !== 'production') {
  app.use((req, res, next) => {
    console.log(`${new Date().toISOString()} ${req.method} ${req.path}`);
    next();
  });
}

// Health check endpoint
app.get('/api/v1/health', (req, res) => {
  res.json({
    status: 'ok',
    service: 'video-editing-platform-api',
    version: '2.0.0',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
  });
});

// =============================================================
// API v1 Routes
// =============================================================

// Auth
app.use('/api/v1/auth', authRoutes);

// Clients
app.use('/api/v1/clients', clientRoutes);

// Projects (includes /api/v1/projects/:id/members)
app.use('/api/v1/projects', projectRoutes);

// Tasks
// Handles: /api/v1/projects/:projectId/tasks AND /api/v1/tasks/:id
app.use('/api/v1', taskRoutes);

// Delivery Jobs
// Handles: /api/v1/projects/:projectId/deliveries AND /api/v1/deliveries/:id
app.use('/api/v1', deliveryRoutes);

// Approvals
// Handles: /api/v1/deliveries/:deliveryId/approve, reject, request-revision, approvals
app.use('/api/v1', approvalRoutes);

// Comments (polymorphic)
app.use('/api/v1/comments', commentRoutes);

// Notifications
app.use('/api/v1/notifications', notificationRoutes);

// Dashboard
app.use('/api/v1/dashboard', dashboardRoutes);

// Admin
app.use('/api/v1/admin', adminRoutes);

// =============================================================

// 404 handler for unknown routes
app.use((req, res) => {
  res.status(404).json({ error: `Route ${req.method} ${req.path} not found.` });
});

// Global error handler
app.use(errorHandler);

// Start server
const PORT = parseInt(process.env.PORT, 10) || 3000;

server.listen(PORT, () => {
  console.log(`Video Editing Platform API running on port ${PORT}`);
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`CORS origin: ${corsOptions.origin}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received. Shutting down gracefully...');
  server.close(() => {
    console.log('Server closed.');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  console.log('SIGINT received. Shutting down gracefully...');
  server.close(() => {
    console.log('Server closed.');
    process.exit(0);
  });
});

module.exports = { app, server, io };
