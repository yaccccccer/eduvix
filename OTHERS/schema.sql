-- =============================
-- ENUM TYPES
-- =============================

CREATE TYPE user_role AS ENUM ('student','teacher','admin');
CREATE TYPE specialty_type AS ENUM ('academic','hard_skills','soft_skills');
CREATE TYPE transaction_status AS ENUM ('pending','completed','failed','refunded');
CREATE TYPE transaction_type AS ENUM ('purchase','commission','refund','withdraw','deposit');
CREATE TYPE enrollment_status AS ENUM ('active','completed','cancelled','refunded');
CREATE TYPE lesson_type_enum AS ENUM ('video','pdf');

-- =============================
-- GENERIC UPDATE TIMESTAMPTZ FUNCTION
-- =============================

CREATE OR REPLACE FUNCTION update_TIMESTAMPTZ()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =============================
-- USERS
-- =============================

CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    username VARCHAR(150) NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    first_name VARCHAR(150),
    last_name VARCHAR(150),
    phone VARCHAR(30),
    avatar TEXT,
    bio TEXT,
    role user_role NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    is_verified BOOLEAN DEFAULT FALSE,
    last_login TIMESTAMPTZ NULL,
    deleted_at TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_users_active_not_deleted ON users(id) WHERE deleted_at IS NULL AND is_active = TRUE;

CREATE TRIGGER trg_users_updated
BEFORE UPDATE ON users
FOR EACH ROW EXECUTE FUNCTION update_TIMESTAMPTZ();

-- =============================
-- TEACHERS & STUDENTS
-- =============================

CREATE TABLE teachers (
    id BIGINT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    rating NUMERIC(3,2) DEFAULT 0.0,
    total_earned NUMERIC(12,2) DEFAULT 0.00,
    total_commission NUMERIC(12,2) DEFAULT 0.00
);

CREATE TABLE students (
    id BIGINT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    points INT DEFAULT 0,
    level VARCHAR(50)
);

-- =============================
-- WALLETS
-- =============================

CREATE TABLE wallets (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    balance NUMERIC(12,2) NOT NULL DEFAULT 0.00 CHECK (balance >= 0),
    is_locked BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TRIGGER trg_wallet_updated
BEFORE UPDATE ON wallets
FOR EACH ROW EXECUTE FUNCTION update_TIMESTAMPTZ();

REVOKE UPDATE ON wallets FROM PUBLIC;

-- =============================
-- CATEGORIES
-- =============================

CREATE TABLE categories (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL,
    description TEXT,
    parent_id BIGINT REFERENCES categories(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TRIGGER trg_category_updated
BEFORE UPDATE ON categories
FOR EACH ROW EXECUTE FUNCTION update_TIMESTAMPTZ();

-- =============================
-- COURSES
-- =============================

CREATE TABLE courses (
    id BIGSERIAL PRIMARY KEY,
    teacher_id BIGINT NOT NULL REFERENCES teachers(id) ON DELETE CASCADE,
    category_id BIGINT NOT NULL REFERENCES categories(id) ON DELETE RESTRICT,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    photo TEXT,
    price NUMERIC(12,2) NOT NULL DEFAULT 0.00 CHECK (price >= 0),
    is_published BOOLEAN DEFAULT FALSE,
    rating NUMERIC(3,2) DEFAULT 0.0,
    total_reviews INT DEFAULT 0,
    deleted_at TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_courses_active_title ON courses(title) WHERE deleted_at IS NULL AND is_published = TRUE;

CREATE TRIGGER trg_course_updated
BEFORE UPDATE ON courses
FOR EACH ROW EXECUTE FUNCTION update_TIMESTAMPTZ();

CREATE OR REPLACE FUNCTION notify_course_completion()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.course_progress = 100 AND (OLD.course_progress IS NULL OR OLD.course_progress < 100) THEN
        INSERT INTO notifications(
            user_id,
            type,
            title,
            message,
            metadata
        ) VALUES (
            NEW.student_id,
            'course_completed',
            'Congratulations!',
            'You have completed the course: ' || (SELECT title FROM courses WHERE id = NEW.course_id),
            jsonb_build_object('course_id', NEW.course_id)
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_notify_course_completion
AFTER UPDATE ON enrollments
FOR EACH ROW
EXECUTE FUNCTION notify_course_completion();

-- =============================
-- LESSONS
-- =============================

CREATE TABLE lessons (
    id BIGSERIAL PRIMARY KEY,
    course_id BIGINT NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    lesson_type lesson_type_enum NOT NULL,
    content_url TEXT NOT NULL,
    order_index INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(course_id, order_index)
);

CREATE TRIGGER trg_lesson_updated
BEFORE UPDATE ON lessons
FOR EACH ROW EXECUTE FUNCTION update_TIMESTAMPTZ();

-- =============================
-- REVIEWS
-- =============================

CREATE TABLE reviews (
    id BIGSERIAL PRIMARY KEY,
    student_id BIGINT NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    course_id BIGINT NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    rating NUMERIC(2,1) NOT NULL CHECK (rating >= 0 AND rating <= 5),
    feedback TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (student_id, course_id)
);

CREATE OR REPLACE FUNCTION update_course_rating()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE courses
  SET 
    rating = (
        SELECT COALESCE(AVG(rating),0)
        FROM reviews
        WHERE course_id = COALESCE(NEW.course_id, OLD.course_id)
    ),
    total_reviews = (
        SELECT COUNT(*)
        FROM reviews
        WHERE course_id = COALESCE(NEW.course_id, OLD.course_id)
    )
  WHERE id = COALESCE(NEW.course_id, OLD.course_id);

  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_rating
AFTER INSERT OR UPDATE OR DELETE
ON reviews
FOR EACH ROW
EXECUTE FUNCTION update_course_rating();

-- =============================
-- TRANSACTIONS
-- =============================

CREATE TABLE transactions (
    id BIGSERIAL PRIMARY KEY,
    student_id BIGINT NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    course_id BIGINT NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    amount NUMERIC(12,2) NOT NULL CHECK (amount >= 0),
    status transaction_status NOT NULL,
    payment_method VARCHAR(30),
    deleted_at TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMPTZ NULL
);

CREATE TABLE coin_transactions (
    id BIGSERIAL PRIMARY KEY,
    wallet_id BIGINT NOT NULL REFERENCES wallets(id) ON DELETE CASCADE,
    transaction_id BIGINT REFERENCES transactions(id) ON DELETE SET NULL,
    type transaction_type NOT NULL,
    amount NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    balance_before NUMERIC(12,2) NOT NULL,
    balance_after NUMERIC(12,2) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_balance_consistency
    CHECK (
        (type IN ('deposit','refund') AND balance_after = balance_before + amount)
        OR
        (type IN ('withdraw','commission','purchase') AND balance_after = balance_before - amount)
    )
);


-- =============================
-- ENROLLMENTS
-- =============================

CREATE TABLE enrollments (
    id BIGSERIAL PRIMARY KEY,
    student_id BIGINT NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    course_id BIGINT NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    transaction_id BIGINT REFERENCES transactions(id) ON DELETE SET NULL,
    status enrollment_status DEFAULT 'active',
    course_progress NUMERIC(5,2) DEFAULT 0.00 CHECK (course_progress BETWEEN 0 AND 100),
    deleted_at TIMESTAMPTZ NULL,
    enrolled_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMPTZ NULL,
    UNIQUE(student_id, course_id)
);

CREATE OR REPLACE FUNCTION auto_complete_enrollment()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.course_progress = 100 THEN
        NEW.status := 'completed';
        NEW.completed_at := CURRENT_TIMESTAMP;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_auto_complete_enrollment
BEFORE UPDATE ON enrollments
FOR EACH ROW
EXECUTE FUNCTION auto_complete_enrollment();

-- =============================
-- STUDENT PROGRESS
-- =============================

CREATE TABLE student_progress (
    id BIGSERIAL PRIMARY KEY,
    enrollment_id BIGINT NOT NULL REFERENCES enrollments(id) ON DELETE CASCADE,
    lesson_id BIGINT NOT NULL REFERENCES lessons(id) ON DELETE CASCADE,
    progress NUMERIC(5,2) DEFAULT 0.00 CHECK (progress BETWEEN 0 AND 100),
    completed_at TIMESTAMPTZ NULL,
    UNIQUE(enrollment_id, lesson_id)
);

CREATE OR REPLACE FUNCTION update_enrollment_progress()
RETURNS TRIGGER AS $$
DECLARE
    avg_progress NUMERIC(5,2);
    target_enrollment BIGINT;
BEGIN
    target_enrollment := COALESCE(NEW.enrollment_id, OLD.enrollment_id);

    SELECT COALESCE(AVG(progress),0) INTO avg_progress
    FROM student_progress
    WHERE enrollment_id = target_enrollment;

    UPDATE enrollments
    SET course_progress = avg_progress
    WHERE id = target_enrollment;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_enrollment_progress
AFTER INSERT OR UPDATE OR DELETE
ON student_progress
FOR EACH ROW
EXECUTE FUNCTION update_enrollment_progress();

-- =============================
-- NOTIFICATIONS
-- =============================

CREATE TABLE notifications (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type VARCHAR(50) NOT NULL,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    metadata JSONB,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    read_at TIMESTAMPTZ NULL
);

CREATE INDEX idx_notifications_user_read ON notifications(user_id, is_read);
CREATE INDEX idx_notifications_unread
ON notifications(user_id)
WHERE is_read = false;

-- =============================
-- SECURITY TABLES
-- =============================

CREATE TABLE password_resets (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash TEXT NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    used BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- =============================
-- SOFT DELETE AUTOMATION JOB
-- =============================

DO $$
DECLARE
    retention_interval INTERVAL := INTERVAL '1 month';
BEGIN
    -- USERS
    DELETE FROM users
    WHERE deleted_at IS NOT NULL
      AND deleted_at < NOW() - retention_interval;

    -- COURSES
    DELETE FROM courses
    WHERE deleted_at IS NOT NULL
      AND deleted_at < NOW() - retention_interval;

    -- ENROLLMENTS
    DELETE FROM enrollments
    WHERE deleted_at IS NOT NULL
      AND deleted_at < NOW() - retention_interval;

    -- TRANSACTIONS
    DELETE FROM transactions
    WHERE deleted_at IS NOT NULL
      AND deleted_at < NOW() - retention_interval;

    -- WALLETS
    DELETE FROM wallets
    WHERE is_locked = TRUE
      AND updated_at < NOW() - retention_interval;

END;
$$ LANGUAGE plpgsql;

-- =============================
-- AUDIT LOGGING
-- =============================

CREATE TABLE audit_logs (
    id BIGSERIAL PRIMARY KEY,
    table_name TEXT NOT NULL,
    record_id BIGINT NOT NULL,
    action_type VARCHAR(10) NOT NULL CHECK (action_type IN ('INSERT','UPDATE','DELETE')),
    old_data JSONB,
    new_data JSONB,
    changed_by BIGINT NULL REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_audit_table_record ON audit_logs(table_name, record_id);

CREATE OR REPLACE FUNCTION log_audit()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO audit_logs(table_name, record_id, action_type, new_data, changed_by)
        VALUES (TG_TABLE_NAME, NEW.id, TG_OP, to_jsonb(NEW), NULL);
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO audit_logs(table_name, record_id, action_type, old_data, new_data, changed_by)
        VALUES (TG_TABLE_NAME, NEW.id, TG_OP, to_jsonb(OLD), to_jsonb(NEW), NULL);
        RETURN NEW;
    ELSE
        INSERT INTO audit_logs(table_name, record_id, action_type, old_data, changed_by)
        VALUES (TG_TABLE_NAME, OLD.id, TG_OP, to_jsonb(OLD), NULL);
        RETURN OLD;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_audit_users
AFTER INSERT OR UPDATE OR DELETE ON users
FOR EACH ROW EXECUTE FUNCTION log_audit();

CREATE TRIGGER trg_audit_wallets
AFTER INSERT OR UPDATE OR DELETE ON wallets
FOR EACH ROW EXECUTE FUNCTION log_audit();

CREATE TRIGGER trg_audit_courses
AFTER INSERT OR UPDATE OR DELETE ON courses
FOR EACH ROW EXECUTE FUNCTION log_audit();

-- =============================
-- WALLET TRANSACTION PROCESSOR
-- =============================

CREATE OR REPLACE FUNCTION process_wallet_transaction(
    p_wallet_id BIGINT,
    p_amount NUMERIC,
    p_type transaction_type,
    p_transaction_id BIGINT DEFAULT NULL,
    p_user_id BIGINT DEFAULT NULL
)
RETURNS VOID AS $$
DECLARE
    v_balance NUMERIC(12,2);
    v_new_balance NUMERIC(12,2);
BEGIN
    IF p_amount <= 0 THEN
        RAISE EXCEPTION 'Amount must be greater than zero';
    END IF;

    PERFORM pg_advisory_xact_lock(p_wallet_id);

    SELECT balance INTO v_balance
    FROM wallets
    WHERE id = p_wallet_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Wallet not found';
    END IF;

    IF p_type IN ('withdraw', 'commission', 'purchase') THEN
        IF v_balance < p_amount THEN
            RAISE EXCEPTION 'Insufficient balance';
        END IF;
        v_new_balance := v_balance - p_amount;
    ELSE
        v_new_balance := v_balance + p_amount;
    END IF;

    INSERT INTO coin_transactions(
        wallet_id,
        transaction_id,
        type,
        amount,
        balance_before,
        balance_after
    ) VALUES (
        p_wallet_id,
        p_transaction_id,
        p_type,
        p_amount,
        v_balance,
        v_new_balance
    );

    UPDATE wallets
    SET balance = v_new_balance,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_wallet_id;

    IF p_type = 'purchase' AND p_transaction_id IS NOT NULL THEN
        UPDATE teachers t
        SET total_earned = t.total_earned + p_amount
        FROM courses c
        JOIN transactions tr ON c.id = tr.course_id
        WHERE tr.id = p_transaction_id
          AND t.id = c.teacher_id; 
    END IF;

    INSERT INTO audit_logs(
        table_name, record_id, action_type, new_data, changed_by
    ) VALUES (
        'wallets', p_wallet_id, 'UPDATE', 
        (SELECT to_jsonb(w) FROM wallets w WHERE w.id = p_wallet_id), 
        p_user_id
    );

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Transaction failed: %', SQLERRM;
        RAISE; 
END;
$$ LANGUAGE plpgsql;