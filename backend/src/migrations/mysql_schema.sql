-- Duozz Flow - MySQL/MariaDB Schema
-- Converted from PostgreSQL

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ============================================================
-- 1. users
-- ============================================================
CREATE TABLE IF NOT EXISTS users (
    id CHAR(36) NOT NULL DEFAULT (UUID()),
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL,
    password_hash VARCHAR(255),
    avatar_url TEXT,
    role VARCHAR(20) NOT NULL DEFAULT 'editor',
    is_approved BOOLEAN NOT NULL DEFAULT FALSE,
    phone VARCHAR(30),
    organization_id CHAR(36),
    google_id VARCHAR(255),
    google_access_token TEXT,
    google_refresh_token TEXT,
    role_id CHAR(36),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uk_users_email (email),
    INDEX idx_users_email (email),
    INDEX idx_users_role (role),
    INDEX idx_users_google_id (google_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 2. clients
-- ============================================================
CREATE TABLE IF NOT EXISTS clients (
    id CHAR(36) NOT NULL DEFAULT (UUID()),
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255),
    phone VARCHAR(30),
    company VARCHAR(255),
    notes TEXT,
    created_by CHAR(36) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    INDEX idx_clients_created_by (created_by),
    INDEX idx_clients_email (email),
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 3. organizations
-- ============================================================
CREATE TABLE IF NOT EXISTS organizations (
    id CHAR(36) NOT NULL DEFAULT (UUID()),
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(100) NOT NULL,
    logo_url TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uk_organizations_slug (slug)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Add foreign keys for users
ALTER TABLE users ADD FOREIGN KEY fk_users_org (organization_id) REFERENCES organizations(id) ON DELETE SET NULL;

-- ============================================================
-- 4. roles & permissions
-- ============================================================
CREATE TABLE IF NOT EXISTS roles (
    id CHAR(36) NOT NULL DEFAULT (UUID()),
    organization_id CHAR(36) NOT NULL,
    name VARCHAR(50) NOT NULL,
    slug VARCHAR(50) NOT NULL,
    description TEXT,
    is_default BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uk_roles_org_slug (organization_id, slug),
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE users ADD FOREIGN KEY fk_users_role (role_id) REFERENCES roles(id) ON DELETE SET NULL;

CREATE TABLE IF NOT EXISTS role_permissions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    role_id CHAR(36) NOT NULL,
    resource VARCHAR(50) NOT NULL,
    action VARCHAR(20) NOT NULL,
    UNIQUE KEY uk_role_perm (role_id, resource, action),
    FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 5. projects
-- ============================================================
CREATE TABLE IF NOT EXISTS projects (
    id CHAR(36) NOT NULL DEFAULT (UUID()),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    client_id CHAR(36),
    status VARCHAR(20) NOT NULL DEFAULT 'active',
    deadline TIMESTAMP NULL,
    budget DECIMAL(12, 2),
    currency VARCHAR(3) DEFAULT 'BRL',
    color VARCHAR(7),
    created_by CHAR(36) NOT NULL,
    organization_id CHAR(36),
    drive_folder_url TEXT,
    drive_folders JSON,
    deleted_at TIMESTAMP NULL DEFAULT NULL,
    deleted_by CHAR(36),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    INDEX idx_projects_status (status),
    INDEX idx_projects_client (client_id),
    INDEX idx_projects_created_by (created_by),
    FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE SET NULL,
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 6. project_members
-- ============================================================
CREATE TABLE IF NOT EXISTS project_members (
    id INT AUTO_INCREMENT PRIMARY KEY,
    project_id CHAR(36) NOT NULL,
    user_id CHAR(36) NOT NULL,
    role VARCHAR(20) NOT NULL DEFAULT 'editor',
    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_project_member (project_id, user_id),
    INDEX idx_project_members_project (project_id),
    INDEX idx_project_members_user (user_id),
    FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 7. delivery_jobs
-- ============================================================
CREATE TABLE IF NOT EXISTS delivery_jobs (
    id CHAR(36) NOT NULL DEFAULT (UUID()),
    project_id CHAR(36) NOT NULL,
    task_id CHAR(36),
    title VARCHAR(500) NOT NULL,
    description TEXT,
    format VARCHAR(100),
    version INT NOT NULL DEFAULT 1,
    file_url TEXT,
    file_size BIGINT,
    status VARCHAR(30) NOT NULL DEFAULT 'pending',
    requires_approval BOOLEAN DEFAULT FALSE,
    uploaded_by CHAR(36),
    reviewed_by CHAR(36),
    review_notes TEXT,
    deleted_at TIMESTAMP NULL,
    deleted_by CHAR(36),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    INDEX idx_delivery_jobs_project (project_id),
    INDEX idx_delivery_jobs_task (task_id),
    INDEX idx_delivery_jobs_status (status),
    INDEX idx_delivery_jobs_uploaded_by (uploaded_by),
    FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
    FOREIGN KEY (uploaded_by) REFERENCES users(id) ON DELETE SET NULL,
    FOREIGN KEY (reviewed_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 8. tasks
-- ============================================================
CREATE TABLE IF NOT EXISTS tasks (
    id CHAR(36) NOT NULL DEFAULT (UUID()),
    project_id CHAR(36) NOT NULL,
    title VARCHAR(500) NOT NULL,
    description TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'todo',
    priority VARCHAR(20) NOT NULL DEFAULT 'medium',
    assignee_id CHAR(36),
    reporter_id CHAR(36) NOT NULL,
    due_date TIMESTAMP NULL,
    position INT NOT NULL DEFAULT 0,
    estimated_hours DECIMAL(6, 2),
    actual_hours DECIMAL(6, 2) DEFAULT 0,
    tags JSON,
    parent_task_id CHAR(36),
    deleted_at TIMESTAMP NULL,
    deleted_by CHAR(36),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    INDEX idx_tasks_project (project_id),
    INDEX idx_tasks_assignee (assignee_id),
    INDEX idx_tasks_status (status),
    INDEX idx_tasks_parent (parent_task_id),
    INDEX idx_tasks_position (project_id, status, position),
    INDEX idx_tasks_reporter (reporter_id),
    FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
    FOREIGN KEY (assignee_id) REFERENCES users(id) ON DELETE SET NULL,
    FOREIGN KEY (reporter_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (parent_task_id) REFERENCES tasks(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 9. task_assignees (junction table for multiple assignees)
-- ============================================================
CREATE TABLE IF NOT EXISTS task_assignees (
    task_id CHAR(36) NOT NULL,
    user_id CHAR(36) NOT NULL,
    assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (task_id, user_id),
    FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 10. approvals
-- ============================================================
CREATE TABLE IF NOT EXISTS approvals (
    id CHAR(36) NOT NULL DEFAULT (UUID()),
    delivery_id CHAR(36) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    reviewer_id CHAR(36) NOT NULL,
    comments TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    INDEX idx_approvals_delivery (delivery_id),
    INDEX idx_approvals_reviewer (reviewer_id),
    FOREIGN KEY (delivery_id) REFERENCES delivery_jobs(id) ON DELETE CASCADE,
    FOREIGN KEY (reviewer_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 11. comments (polymorphic)
-- ============================================================
CREATE TABLE IF NOT EXISTS comments (
    id CHAR(36) NOT NULL DEFAULT (UUID()),
    entity_type VARCHAR(20) NOT NULL,
    entity_id CHAR(36) NOT NULL,
    user_id CHAR(36) NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    INDEX idx_comments_entity (entity_type, entity_id),
    INDEX idx_comments_user (user_id),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 12. notifications
-- ============================================================
CREATE TABLE IF NOT EXISTS notifications (
    id CHAR(36) NOT NULL DEFAULT (UUID()),
    user_id CHAR(36) NOT NULL,
    type VARCHAR(30) NOT NULL,
    title VARCHAR(500) NOT NULL,
    message TEXT,
    reference_type VARCHAR(50),
    reference_id CHAR(36),
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    INDEX idx_notifications_user (user_id),
    INDEX idx_notifications_read (user_id, is_read),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 13. audit_log
-- ============================================================
CREATE TABLE IF NOT EXISTS audit_log (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id CHAR(36),
    action VARCHAR(100) NOT NULL,
    entity_type VARCHAR(50) NOT NULL,
    entity_id CHAR(36),
    details JSON,
    ip_address VARCHAR(45),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_audit_log_user (user_id),
    INDEX idx_audit_log_entity (entity_type, entity_id),
    INDEX idx_audit_log_created (created_at),
    INDEX idx_audit_log_action (action),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 14. refresh_tokens
-- ============================================================
CREATE TABLE IF NOT EXISTS refresh_tokens (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id CHAR(36) NOT NULL,
    token VARCHAR(512) NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_refresh_token (token),
    INDEX idx_refresh_tokens_user (user_id),
    INDEX idx_refresh_tokens_expires (expires_at),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 15. jobs (video deliverable jobs)
-- ============================================================
CREATE TABLE IF NOT EXISTS jobs (
    id CHAR(36) NOT NULL DEFAULT (UUID()),
    project_id CHAR(36) NOT NULL,
    title VARCHAR(500) NOT NULL,
    description TEXT,
    type VARCHAR(50) DEFAULT 'edit',
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    assigned_to CHAR(36),
    due_date TIMESTAMP NULL,
    priority VARCHAR(20) DEFAULT 'medium',
    created_by CHAR(36) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    INDEX idx_jobs_project (project_id),
    INDEX idx_jobs_assigned (assigned_to),
    INDEX idx_jobs_status (status),
    FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
    FOREIGN KEY (assigned_to) REFERENCES users(id) ON DELETE SET NULL,
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 16. assets & asset_versions
-- ============================================================
CREATE TABLE IF NOT EXISTS assets (
    id CHAR(36) NOT NULL DEFAULT (UUID()),
    project_id CHAR(36) NOT NULL,
    job_id CHAR(36),
    name VARCHAR(500) NOT NULL,
    type VARCHAR(30) NOT NULL DEFAULT 'raw',
    mime_type VARCHAR(100),
    file_url TEXT,
    file_size BIGINT,
    drive_file_id VARCHAR(255),
    uploaded_by CHAR(36),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    INDEX idx_assets_project (project_id),
    INDEX idx_assets_job (job_id),
    INDEX idx_assets_type (type),
    FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
    FOREIGN KEY (job_id) REFERENCES jobs(id) ON DELETE SET NULL,
    FOREIGN KEY (uploaded_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS asset_versions (
    id CHAR(36) NOT NULL DEFAULT (UUID()),
    asset_id CHAR(36) NOT NULL,
    version INT NOT NULL DEFAULT 1,
    file_url TEXT NOT NULL,
    file_size BIGINT,
    drive_file_id VARCHAR(255),
    notes TEXT,
    status VARCHAR(20) DEFAULT 'pending',
    uploaded_by CHAR(36),
    approved_by CHAR(36),
    approved_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    INDEX idx_asset_versions_asset (asset_id),
    FOREIGN KEY (asset_id) REFERENCES assets(id) ON DELETE CASCADE,
    FOREIGN KEY (uploaded_by) REFERENCES users(id) ON DELETE SET NULL,
    FOREIGN KEY (approved_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 17. reviews & review_comments
-- ============================================================
CREATE TABLE IF NOT EXISTS reviews (
    id CHAR(36) NOT NULL DEFAULT (UUID()),
    job_id CHAR(36) NOT NULL,
    asset_version_id CHAR(36),
    reviewer_id CHAR(36) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    summary TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    INDEX idx_reviews_job (job_id),
    INDEX idx_reviews_reviewer (reviewer_id),
    FOREIGN KEY (job_id) REFERENCES jobs(id) ON DELETE CASCADE,
    FOREIGN KEY (asset_version_id) REFERENCES asset_versions(id) ON DELETE SET NULL,
    FOREIGN KEY (reviewer_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS review_comments (
    id CHAR(36) NOT NULL DEFAULT (UUID()),
    review_id CHAR(36) NOT NULL,
    user_id CHAR(36) NOT NULL,
    content TEXT NOT NULL,
    timecode VARCHAR(20),
    frame_url TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    INDEX idx_review_comments_review (review_id),
    FOREIGN KEY (review_id) REFERENCES reviews(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 18. chat_channels & chat_messages
-- ============================================================
CREATE TABLE IF NOT EXISTS chat_channels (
    id CHAR(36) NOT NULL DEFAULT (UUID()),
    project_id CHAR(36) NOT NULL,
    name VARCHAR(255) NOT NULL DEFAULT 'Geral',
    type VARCHAR(20) DEFAULT 'project',
    job_id CHAR(36),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    INDEX idx_chat_channels_project (project_id),
    FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
    FOREIGN KEY (job_id) REFERENCES jobs(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS chat_messages (
    id CHAR(36) NOT NULL DEFAULT (UUID()),
    channel_id CHAR(36) NOT NULL,
    user_id CHAR(36) NOT NULL,
    content TEXT NOT NULL,
    type VARCHAR(20) DEFAULT 'text',
    file_url TEXT,
    file_name VARCHAR(500),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    INDEX idx_chat_messages_channel (channel_id),
    INDEX idx_chat_messages_created (channel_id, created_at),
    FOREIGN KEY (channel_id) REFERENCES chat_channels(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 19. calendar_events
-- ============================================================
CREATE TABLE IF NOT EXISTS calendar_events (
    id CHAR(36) NOT NULL DEFAULT (UUID()),
    project_id CHAR(36) NOT NULL,
    title VARCHAR(500) NOT NULL,
    description TEXT,
    start_time TIMESTAMP NOT NULL,
    end_time TIMESTAMP NOT NULL,
    type VARCHAR(30) DEFAULT 'deadline',
    google_event_id VARCHAR(255),
    created_by CHAR(36) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    INDEX idx_calendar_events_project (project_id),
    INDEX idx_calendar_events_time (start_time, end_time),
    FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET FOREIGN_KEY_CHECKS = 1;

-- ============================================================
-- Delivery version auto-increment trigger
-- ============================================================
DROP TRIGGER IF EXISTS trg_delivery_version;
DELIMITER //
CREATE TRIGGER trg_delivery_version
BEFORE INSERT ON delivery_jobs
FOR EACH ROW
BEGIN
    DECLARE next_ver INT;
    SELECT COALESCE(MAX(version), 0) + 1 INTO next_ver
    FROM delivery_jobs WHERE project_id = NEW.project_id;
    SET NEW.version = next_ver;
END//
DELIMITER ;

-- ============================================================
-- Asset version auto-increment trigger
-- ============================================================
DROP TRIGGER IF EXISTS trg_asset_version;
DELIMITER //
CREATE TRIGGER trg_asset_version
BEFORE INSERT ON asset_versions
FOR EACH ROW
BEGIN
    DECLARE next_ver INT;
    SELECT COALESCE(MAX(version), 0) + 1 INTO next_ver
    FROM asset_versions WHERE asset_id = NEW.asset_id;
    SET NEW.version = next_ver;
END//
DELIMITER ;

-- ============================================================
-- Add color column to projects (for existing databases)
-- ============================================================
SET @col_exists = (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 'projects' AND column_name = 'color');
SET @sql = IF(@col_exists = 0, 'ALTER TABLE projects ADD COLUMN color VARCHAR(7) AFTER currency', 'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- ============================================================
-- Add is_approved column to users (account approval system)
-- ============================================================
SET @col_exists = (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 'users' AND column_name = 'is_approved');
SET @sql = IF(@col_exists = 0, 'ALTER TABLE users ADD COLUMN is_approved BOOLEAN NOT NULL DEFAULT FALSE AFTER role', 'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Set existing users as approved (so they are not locked out)
UPDATE users SET is_approved = TRUE WHERE is_approved = FALSE;

-- ============================================================
-- Add timer_started_at column to tasks (automatic time tracking)
-- ============================================================
SET @col_exists = (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 'tasks' AND column_name = 'timer_started_at');
SET @sql = IF(@col_exists = 0, 'ALTER TABLE tasks ADD COLUMN timer_started_at DATETIME NULL DEFAULT NULL AFTER actual_hours', 'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
