-- ============================================================
-- Mico's Bike Shop — Enhancement Migration
-- Run this in phpMyAdmin → SQL tab
-- ============================================================

-- 1. Add email verification column to users
ALTER TABLE users
  ADD COLUMN is_verified TINYINT(1) NOT NULL DEFAULT 0 AFTER firebase_uid,
  ADD COLUMN verified_at TIMESTAMP NULL DEFAULT NULL AFTER is_verified;

-- 2. Email verifications table
CREATE TABLE IF NOT EXISTS email_verifications (
  id         INT(11)      NOT NULL AUTO_INCREMENT,
  user_id    INT(11)      NOT NULL,
  token      VARCHAR(100) NOT NULL UNIQUE,
  expires_at TIMESTAMP    NOT NULL,
  used_at    TIMESTAMP    NULL DEFAULT NULL,
  created_at TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_ev_user  (user_id),
  KEY idx_ev_token (token),
  CONSTRAINT fk_ev_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 3. Password resets table
CREATE TABLE IF NOT EXISTS password_resets (
  id         INT(11)      NOT NULL AUTO_INCREMENT,
  email      VARCHAR(100) NOT NULL,
  token      VARCHAR(100) NOT NULL UNIQUE,
  expires_at TIMESTAMP    NOT NULL,
  used_at    TIMESTAMP    NULL DEFAULT NULL,
  created_at TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_pr_email (email),
  KEY idx_pr_token (token)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 4. Product images table
CREATE TABLE IF NOT EXISTS product_images (
  id         INT(11)       NOT NULL AUTO_INCREMENT,
  product_id INT(11)       NOT NULL,
  image_url  VARCHAR(500)  NOT NULL,
  is_primary TINYINT(1)    NOT NULL DEFAULT 0,
  sort_order INT(11)       NOT NULL DEFAULT 0,
  created_at TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_pi_product (product_id),
  CONSTRAINT fk_pi_product FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 5. Product reviews table
CREATE TABLE IF NOT EXISTS product_reviews (
  id         INT(11)   NOT NULL AUTO_INCREMENT,
  product_id INT(11)   NOT NULL,
  user_id    INT(11)   NOT NULL,
  order_id   INT(11)   NULL DEFAULT NULL,
  rating     TINYINT   NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment    TEXT      NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_review (product_id, user_id),
  KEY idx_rv_product (product_id),
  KEY idx_rv_user    (user_id),
  CONSTRAINT fk_rv_product FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
  CONSTRAINT fk_rv_user    FOREIGN KEY (user_id)    REFERENCES users(id)    ON DELETE CASCADE,
  CONSTRAINT fk_rv_order   FOREIGN KEY (order_id)   REFERENCES orders(id)   ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 6. Notifications table
CREATE TABLE IF NOT EXISTS notifications (
  id         INT(11)      NOT NULL AUTO_INCREMENT,
  user_id    INT(11)      NOT NULL,
  type       VARCHAR(50)  NOT NULL,
  title      VARCHAR(150) NOT NULL,
  message    TEXT         NOT NULL,
  data       JSON         NULL,
  is_read    TINYINT(1)   NOT NULL DEFAULT 0,
  created_at TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_notif_user (user_id),
  KEY idx_notif_read (is_read),
  CONSTRAINT fk_notif_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 7. Add conversation_id to messages for SSE grouping
ALTER TABLE messages
  ADD COLUMN conversation_id VARCHAR(50)
    GENERATED ALWAYS AS (
      IF(sender_id < receiver_id,
         CONCAT(sender_id, '_', receiver_id),
         CONCAT(receiver_id, '_', sender_id))
    ) STORED,
  ADD KEY idx_msg_conv (conversation_id);
