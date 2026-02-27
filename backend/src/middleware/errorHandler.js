const errorHandler = (err, req, res, next) => {
  console.error('Error:', err.message);
  console.error('Stack:', err.stack);

  if (err.code === '23505') {
    // PostgreSQL unique violation
    return res.status(409).json({
      error: 'A record with that value already exists.',
    });
  }

  if (err.code === '23503') {
    // PostgreSQL foreign key violation
    return res.status(400).json({
      error: 'Referenced record does not exist.',
    });
  }

  if (err.code === '22P02') {
    // PostgreSQL invalid text representation (e.g. invalid UUID)
    return res.status(400).json({
      error: 'Invalid identifier format.',
    });
  }

  const statusCode = err.statusCode || 500;
  const message = statusCode === 500 ? 'Internal server error.' : err.message;

  res.status(statusCode).json({ error: message });
};

module.exports = errorHandler;
