USE quiz_db;

-- New AI question bank; old `questions` and `quiz_results` tables are left untouched.
CREATE TABLE IF NOT EXISTS ai_questions (
  id INT AUTO_INCREMENT PRIMARY KEY,
  question_text TEXT NOT NULL,
  option_a VARCHAR(1000) NOT NULL,
  option_b VARCHAR(1000) NOT NULL,
  option_c VARCHAR(1000) NOT NULL,
  option_d VARCHAR(1000) NOT NULL,
  correct_option CHAR(1) NOT NULL,
  explanation TEXT,
  topic VARCHAR(100) NOT NULL,
  difficulty ENUM('Easy','Medium','Hard') NOT NULL,
  source VARCHAR(20) NOT NULL DEFAULT 'GEMINI',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_ai_topic_difficulty(topic,difficulty),
  CONSTRAINT chk_ai_correct_option CHECK (correct_option IN ('A','B','C','D'))
);

CREATE TABLE IF NOT EXISTS quiz_attempts (
  id INT AUTO_INCREMENT PRIMARY KEY,
  username VARCHAR(100) NOT NULL,
  topic VARCHAR(100) NOT NULL,
  difficulty ENUM('Easy','Medium','Hard') NOT NULL,
  total_questions INT NOT NULL,
  score INT NOT NULL DEFAULT 0,
  percentage DECIMAL(5,2) NOT NULL DEFAULT 0,
  status ENUM('IN_PROGRESS','COMPLETED') NOT NULL DEFAULT 'IN_PROGRESS',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  completed_at TIMESTAMP NULL,
  INDEX idx_attempt_history(created_at)
);

CREATE TABLE IF NOT EXISTS quiz_attempt_questions (
  id INT AUTO_INCREMENT PRIMARY KEY,
  attempt_id INT NOT NULL,
  question_id INT NOT NULL,
  selected_option CHAR(1) NULL,
  is_correct BOOLEAN NOT NULL DEFAULT FALSE,
  CONSTRAINT fk_qaq_attempt FOREIGN KEY(attempt_id) REFERENCES quiz_attempts(id) ON DELETE CASCADE,
  CONSTRAINT fk_qaq_question FOREIGN KEY(question_id) REFERENCES ai_questions(id),
  UNIQUE KEY uq_attempt_question(attempt_id,question_id)
);
