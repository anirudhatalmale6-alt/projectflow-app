const express = require('express');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const User = require('../models/User');
const auth = require('../middleware/auth');
const pool = require('../config/database');
const { logAudit, getClientIp } = require('../utils/audit');

const passport = require('passport');
const { Strategy: GoogleStrategy } = require('passport-google-oauth20');

const router = express.Router();

// Configure Google OAuth if credentials are set
if (process.env.GOOGLE_CLIENT_ID && process.env.GOOGLE_CLIENT_SECRET) {
  passport.use(new GoogleStrategy({
    clientID: process.env.GOOGLE_CLIENT_ID,
    clientSecret: process.env.GOOGLE_CLIENT_SECRET,
    callbackURL: process.env.GOOGLE_CALLBACK_URL || '/api/v1/auth/google/callback',
  }, async (accessToken, refreshToken, profile, done) => {
    try {
      const email = profile.emails[0].value.toLowerCase();
      let user = await User.findByEmail(email);

      if (user) {
        // Update Google tokens
        await pool.query(
          'UPDATE users SET google_id = $1, google_access_token = $2, google_refresh_token = COALESCE($3, google_refresh_token), avatar_url = COALESCE(avatar_url, $4) WHERE id = $5',
          [profile.id, accessToken, refreshToken, profile.photos?.[0]?.value, user.id]
        );
      } else {
        // Create new user from Google
        const result = await pool.query(
          `INSERT INTO users (name, email, google_id, google_access_token, google_refresh_token, avatar_url, role)
           VALUES ($1, $2, $3, $4, $5, $6, 'editor') RETURNING *`,
          [profile.displayName, email, profile.id, accessToken, refreshToken, profile.photos?.[0]?.value]
        );
        user = result.rows[0];
      }

      done(null, user);
    } catch (err) {
      done(err, null);
    }
  }));
}

/**
 * Generate an access token (short-lived).
 */
function generateAccessToken(userId) {
  return jwt.sign(
    { userId },
    process.env.JWT_SECRET,
    { expiresIn: process.env.JWT_EXPIRES_IN || '15m' }
  );
}

/**
 * Generate a refresh token (long-lived), store it in the database, and return it.
 */
async function generateRefreshToken(userId) {
  const token = crypto.randomBytes(64).toString('hex');
  const expiresIn = process.env.JWT_REFRESH_EXPIRES_IN || '7d';

  // Parse duration string to ms
  const daysMatch = expiresIn.match(/^(\d+)d$/);
  const days = daysMatch ? parseInt(daysMatch[1], 10) : 7;
  const expiresAt = new Date(Date.now() + days * 24 * 60 * 60 * 1000);

  await pool.query(
    `INSERT INTO refresh_tokens (user_id, token, expires_at)
     VALUES ($1, $2, $3)`,
    [userId, token, expiresAt]
  );

  return token;
}

/**
 * Invalidate a refresh token (delete from DB).
 */
async function invalidateRefreshToken(token) {
  const { rowCount } = await pool.query(
    'DELETE FROM refresh_tokens WHERE token = $1',
    [token]
  );
  return rowCount > 0;
}

/**
 * Validate a refresh token and return the associated user_id.
 */
async function validateRefreshToken(token) {
  const { rows } = await pool.query(
    'SELECT user_id, expires_at FROM refresh_tokens WHERE token = $1',
    [token]
  );

  if (rows.length === 0) return null;

  const { user_id, expires_at } = rows[0];

  if (new Date(expires_at) < new Date()) {
    // Token expired, clean up
    await pool.query('DELETE FROM refresh_tokens WHERE token = $1', [token]);
    return null;
  }

  return user_id;
}

// POST /api/v1/auth/register
router.post('/register', async (req, res, next) => {
  try {
    const { name, email, password, role, phone } = req.body;

    if (!name || !email || !password) {
      return res.status(400).json({ error: 'Name, email, and password are required.' });
    }

    if (typeof name !== 'string' || name.trim().length < 2) {
      return res.status(400).json({ error: 'Name must be at least 2 characters.' });
    }

    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      return res.status(400).json({ error: 'Invalid email format.' });
    }

    if (password.length < 6) {
      return res.status(400).json({ error: 'Password must be at least 6 characters.' });
    }

    // Validate role if provided
    const validRoles = ['admin', 'manager', 'editor', 'freelancer', 'client'];
    const userRole = role && validRoles.includes(role) ? role : 'editor';

    // Check if email already exists
    const existing = await User.findByEmail(email.toLowerCase().trim());
    if (existing) {
      return res.status(409).json({ error: 'Email is already registered.' });
    }

    // Create user
    const user = await User.create({
      name: name.trim(),
      email: email.toLowerCase().trim(),
      password,
      role: userRole,
      phone: phone || null,
    });

    // Generate tokens
    const access_token = generateAccessToken(user.id);
    const refresh_token = await generateRefreshToken(user.id);

    await logAudit({
      userId: user.id,
      action: 'register',
      entityType: 'user',
      entityId: user.id,
      details: { name: user.name, email: user.email, role: user.role },
      ipAddress: getClientIp(req),
    });

    res.status(201).json({
      message: 'Registration successful.',
      access_token,
      refresh_token,
      user,
    });
  } catch (err) {
    next(err);
  }
});

// POST /api/v1/auth/login
router.post('/login', async (req, res, next) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password are required.' });
    }

    const user = await User.findByEmail(email.toLowerCase().trim());
    if (!user) {
      return res.status(401).json({ error: 'Invalid email or password.' });
    }

    const isMatch = await User.comparePassword(password, user.password_hash);
    if (!isMatch) {
      return res.status(401).json({ error: 'Invalid email or password.' });
    }

    // Generate tokens
    const access_token = generateAccessToken(user.id);
    const refresh_token = await generateRefreshToken(user.id);

    const { password_hash, ...userWithoutPassword } = user;

    await logAudit({
      userId: user.id,
      action: 'login',
      entityType: 'user',
      entityId: user.id,
      details: {},
      ipAddress: getClientIp(req),
    });

    res.json({
      message: 'Login successful.',
      access_token,
      refresh_token,
      user: userWithoutPassword,
    });
  } catch (err) {
    next(err);
  }
});

// POST /api/v1/auth/refresh - Refresh token rotation
router.post('/refresh', async (req, res, next) => {
  try {
    const { refresh_token } = req.body;

    if (!refresh_token) {
      return res.status(400).json({ error: 'Refresh token is required.' });
    }

    // Validate the old refresh token
    const userId = await validateRefreshToken(refresh_token);
    if (!userId) {
      return res.status(401).json({ error: 'Invalid or expired refresh token.' });
    }

    // Invalidate the old token (rotation)
    await invalidateRefreshToken(refresh_token);

    // Issue new tokens
    const new_access_token = generateAccessToken(userId);
    const new_refresh_token = await generateRefreshToken(userId);

    // Get user data
    const user = await User.findById(userId);

    res.json({
      access_token: new_access_token,
      refresh_token: new_refresh_token,
      user,
    });
  } catch (err) {
    next(err);
  }
});

// POST /api/v1/auth/logout - Invalidate refresh token
router.post('/logout', async (req, res, next) => {
  try {
    const { refresh_token } = req.body;

    if (refresh_token) {
      await invalidateRefreshToken(refresh_token);
    }

    // If authenticated, log the audit
    const authHeader = req.headers.authorization;
    if (authHeader && authHeader.startsWith('Bearer ')) {
      try {
        const token = authHeader.split(' ')[1];
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        await logAudit({
          userId: decoded.userId,
          action: 'logout',
          entityType: 'user',
          entityId: decoded.userId,
          details: {},
          ipAddress: getClientIp(req),
        });
      } catch (_) {
        // Token might be expired, still logout
      }
    }

    res.json({ message: 'Logged out successfully.' });
  } catch (err) {
    next(err);
  }
});

// GET /api/v1/auth/me
router.get('/me', auth, async (req, res, next) => {
  try {
    const user = await User.findById(req.user.id);
    if (!user) {
      return res.status(404).json({ error: 'User not found.' });
    }
    res.json({ user });
  } catch (err) {
    next(err);
  }
});

// PUT /api/v1/auth/profile
router.put('/profile', auth, async (req, res, next) => {
  try {
    const { name, avatar_url, phone, currentPassword, newPassword } = req.body;

    const updates = {};
    if (name !== undefined) {
      if (typeof name !== 'string' || name.trim().length < 2) {
        return res.status(400).json({ error: 'Name must be at least 2 characters.' });
      }
      updates.name = name.trim();
    }
    if (avatar_url !== undefined) {
      updates.avatar_url = avatar_url;
    }
    if (phone !== undefined) {
      updates.phone = phone;
    }

    let user;
    if (Object.keys(updates).length > 0) {
      user = await User.update(req.user.id, updates);
    }

    // Update password if provided
    if (newPassword) {
      if (!currentPassword) {
        return res.status(400).json({ error: 'Current password is required to set a new password.' });
      }

      if (newPassword.length < 6) {
        return res.status(400).json({ error: 'New password must be at least 6 characters.' });
      }

      const fullUser = await User.findByEmail(req.user.email);
      const isMatch = await User.comparePassword(currentPassword, fullUser.password_hash);
      if (!isMatch) {
        return res.status(401).json({ error: 'Current password is incorrect.' });
      }

      user = await User.updatePassword(req.user.id, newPassword);
    }

    if (!user) {
      user = await User.findById(req.user.id);
    }

    await logAudit({
      userId: req.user.id,
      action: 'update_profile',
      entityType: 'user',
      entityId: req.user.id,
      details: { fields: Object.keys(updates) },
      ipAddress: getClientIp(req),
    });

    res.json({
      message: 'Profile updated successfully.',
      user,
    });
  } catch (err) {
    next(err);
  }
});

// GET /api/v1/auth/google - Initiate Google OAuth
router.get('/google', (req, res, next) => {
  if (!process.env.GOOGLE_CLIENT_ID) {
    return res.status(501).json({ error: 'Google OAuth not configured. Set GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET.' });
  }
  passport.authenticate('google', {
    scope: ['profile', 'email'],
    session: false,
  })(req, res, next);
});

// GET /api/v1/auth/google/callback
router.get('/google/callback', (req, res, next) => {
  passport.authenticate('google', { session: false }, async (err, user) => {
    if (err || !user) {
      // Redirect to frontend with error
      const frontendUrl = process.env.FRONTEND_URL || '';
      return res.redirect(`${frontendUrl}/login?error=google_auth_failed`);
    }

    try {
      const access_token = generateAccessToken(user.id);
      const refresh_token = await generateRefreshToken(user.id);

      await logAudit({
        userId: user.id,
        action: 'google_login',
        entityType: 'user',
        entityId: user.id,
        details: { provider: 'google' },
        ipAddress: getClientIp(req),
      });

      // Redirect to frontend with tokens
      const frontendUrl = process.env.FRONTEND_URL || '';
      res.redirect(`${frontendUrl}/login?access_token=${access_token}&refresh_token=${refresh_token}`);
    } catch (error) {
      next(error);
    }
  })(req, res, next);
});

module.exports = router;
