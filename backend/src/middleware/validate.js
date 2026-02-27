const { body, param, query, validationResult } = require('express-validator');

const validate = (validations) => {
  return async (req, res, next) => {
    for (const validation of validations) {
      const result = await validation.run(req);
      if (!result.isEmpty()) break;
    }

    const errors = validationResult(req);
    if (errors.isEmpty()) {
      return next();
    }

    return res.status(400).json({
      error: 'Validation failed',
      details: errors.array().map(e => ({
        field: e.path,
        message: e.msg,
      })),
    });
  };
};

// Common validators
const loginValidation = [
  body('email').isEmail().normalizeEmail().withMessage('Valid email required'),
  body('password').isLength({ min: 6 }).withMessage('Password must be at least 6 characters'),
];

const registerValidation = [
  body('name').trim().isLength({ min: 2, max: 100 }).withMessage('Name must be 2-100 characters'),
  body('email').isEmail().normalizeEmail().withMessage('Valid email required'),
  body('password').isLength({ min: 6, max: 128 }).withMessage('Password must be 6-128 characters'),
];

const uuidParam = (paramName = 'id') => [
  param(paramName).isUUID().withMessage(`${paramName} must be a valid UUID`),
];

const projectValidation = [
  body('name').trim().isLength({ min: 1, max: 255 }).withMessage('Project name required (max 255 chars)'),
  body('description').optional().trim().isLength({ max: 5000 }),
  body('client_id').optional().isUUID(),
  body('deadline').optional().isISO8601(),
  body('budget').optional().isFloat({ min: 0 }),
  body('currency').optional().isIn(['BRL', 'USD', 'EUR']),
];

const taskValidation = [
  body('title').trim().isLength({ min: 1, max: 500 }).withMessage('Task title required'),
  body('priority').optional().isIn(['low', 'medium', 'high', 'urgent']),
  body('status').optional().isIn(['todo', 'in_progress', 'review', 'done']),
  body('assignee_id').optional().isUUID(),
  body('due_date').optional().isISO8601(),
  body('estimated_hours').optional().isFloat({ min: 0 }),
  body('actual_hours').optional().isFloat({ min: 0 }),
];

const commentValidation = [
  body('content').trim().isLength({ min: 1, max: 10000 }).withMessage('Comment content required'),
  body('entity_type').isIn(['project', 'task', 'delivery']).withMessage('entity_type must be project, task, or delivery'),
  body('entity_id').isUUID().withMessage('entity_id must be a valid UUID'),
];

module.exports = {
  validate,
  loginValidation,
  registerValidation,
  uuidParam,
  projectValidation,
  taskValidation,
  commentValidation,
};
