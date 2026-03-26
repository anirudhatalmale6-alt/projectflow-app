const { google } = require('googleapis');
const pool = require('../config/database');

class CalendarSyncService {
  /**
   * Create an OAuth2 client from user's stored Google tokens.
   */
  static _getOAuth2Client(accessToken, refreshToken) {
    const oauth2Client = new google.auth.OAuth2(
      process.env.GOOGLE_CLIENT_ID,
      process.env.GOOGLE_CLIENT_SECRET
    );
    oauth2Client.setCredentials({
      access_token: accessToken,
      refresh_token: refreshToken,
    });
    return oauth2Client;
  }

  /**
   * Get authenticated Calendar client for a user.
   */
  static async _getCalendarForUser(userId) {
    const { rows } = await pool.query(
      'SELECT google_access_token, google_refresh_token FROM users WHERE id = $1',
      [userId]
    );
    if (!rows.length || !rows[0].google_refresh_token) {
      throw new Error('USER_NOT_GOOGLE_LINKED');
    }
    const auth = CalendarSyncService._getOAuth2Client(
      rows[0].google_access_token,
      rows[0].google_refresh_token
    );

    // Update stored token on refresh
    auth.on('tokens', async (tokens) => {
      if (tokens.access_token) {
        await pool.query(
          'UPDATE users SET google_access_token = $1 WHERE id = $2',
          [tokens.access_token, userId]
        );
      }
    });

    return google.calendar({ version: 'v3', auth });
  }

  /**
   * Check if user has Google Calendar access.
   */
  static async hasGoogleCalendar(userId) {
    const { rows } = await pool.query(
      'SELECT google_refresh_token FROM users WHERE id = $1',
      [userId]
    );
    return rows.length > 0 && !!rows[0].google_refresh_token;
  }

  /**
   * Create a Google Calendar event and store the google_event_id.
   */
  static async createEvent(userId, localEvent) {
    const calendar = await CalendarSyncService._getCalendarForUser(userId);

    const gcalEvent = {
      summary: localEvent.title,
      description: localEvent.description || '',
      start: {
        dateTime: new Date(localEvent.start_time).toISOString(),
        timeZone: 'America/Sao_Paulo',
      },
      end: {
        dateTime: new Date(localEvent.end_time).toISOString(),
        timeZone: 'America/Sao_Paulo',
      },
    };

    const res = await calendar.events.insert({
      calendarId: 'primary',
      requestBody: gcalEvent,
    });

    // Store google_event_id in our DB
    if (res.data.id && localEvent.id) {
      await pool.query(
        'UPDATE calendar_events SET google_event_id = $1 WHERE id = $2',
        [res.data.id, localEvent.id]
      );
    }

    return res.data.id;
  }

  /**
   * Update a Google Calendar event.
   */
  static async updateEvent(userId, localEvent) {
    if (!localEvent.google_event_id) return;

    const calendar = await CalendarSyncService._getCalendarForUser(userId);

    const gcalEvent = {
      summary: localEvent.title,
      description: localEvent.description || '',
      start: {
        dateTime: new Date(localEvent.start_time).toISOString(),
        timeZone: 'America/Sao_Paulo',
      },
      end: {
        dateTime: new Date(localEvent.end_time).toISOString(),
        timeZone: 'America/Sao_Paulo',
      },
    };

    try {
      await calendar.events.update({
        calendarId: 'primary',
        eventId: localEvent.google_event_id,
        requestBody: gcalEvent,
      });
    } catch (err) {
      if (err.code === 404) {
        // Event was deleted on Google side, clear the reference
        await pool.query(
          'UPDATE calendar_events SET google_event_id = NULL WHERE id = $1',
          [localEvent.id]
        );
      } else {
        throw err;
      }
    }
  }

  /**
   * Delete a Google Calendar event.
   */
  static async deleteEvent(userId, googleEventId) {
    if (!googleEventId) return;

    const calendar = await CalendarSyncService._getCalendarForUser(userId);

    try {
      await calendar.events.delete({
        calendarId: 'primary',
        eventId: googleEventId,
      });
    } catch (err) {
      if (err.code !== 404 && err.code !== 410) {
        throw err;
      }
      // Already deleted on Google side, ignore
    }
  }

  /**
   * Import events from Google Calendar for a date range.
   */
  static async importEvents(userId, projectId, timeMin, timeMax) {
    const calendar = await CalendarSyncService._getCalendarForUser(userId);

    const res = await calendar.events.list({
      calendarId: 'primary',
      timeMin: new Date(timeMin).toISOString(),
      timeMax: new Date(timeMax).toISOString(),
      singleEvents: true,
      orderBy: 'startTime',
      maxResults: 100,
    });

    const gcalEvents = res.data.items || [];
    const imported = [];

    for (const ge of gcalEvents) {
      // Skip all-day events without dateTime
      const startTime = ge.start.dateTime || ge.start.date;
      const endTime = ge.end.dateTime || ge.end.date;
      if (!startTime || !endTime) continue;

      // Check if already imported
      const { rows: existing } = await pool.query(
        'SELECT id FROM calendar_events WHERE google_event_id = $1 AND project_id = $2',
        [ge.id, projectId]
      );

      if (existing.length > 0) {
        // Update existing
        await pool.query(
          `UPDATE calendar_events SET title = $1, description = $2, start_time = $3, end_time = $4 WHERE id = $5`,
          [ge.summary || 'Sem título', ge.description || null, startTime, endTime, existing[0].id]
        );
        imported.push({ id: existing[0].id, action: 'updated' });
      } else {
        // Insert new
        const { rows } = await pool.query(
          `INSERT INTO calendar_events (project_id, title, description, start_time, end_time, type, google_event_id, created_by)
           VALUES ($1, $2, $3, $4, $5, 'meeting', $6, $7) RETURNING id`,
          [projectId, ge.summary || 'Sem título', ge.description || null, startTime, endTime, ge.id, userId]
        );
        imported.push({ id: rows[0].id, action: 'created' });
      }
    }

    return {
      total_google_events: gcalEvents.length,
      imported: imported.length,
      details: imported,
    };
  }

  /**
   * Export all local events for a project to Google Calendar.
   */
  static async exportEvents(userId, projectId) {
    const { rows: events } = await pool.query(
      'SELECT * FROM calendar_events WHERE project_id = $1 AND google_event_id IS NULL',
      [projectId]
    );

    const exported = [];
    for (const ev of events) {
      try {
        const googleId = await CalendarSyncService.createEvent(userId, ev);
        exported.push({ id: ev.id, google_event_id: googleId });
      } catch (err) {
        console.error(`Failed to export event ${ev.id}:`, err.message);
      }
    }

    return {
      total_local_events: events.length,
      exported: exported.length,
      details: exported,
    };
  }
}

module.exports = CalendarSyncService;
