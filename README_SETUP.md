# AI Quiz Studio — Gemini + JSP + MySQL

This is an upgraded version of the supplied Eclipse Dynamic Web Project. It keeps JSP, Jakarta Servlet 6, Java 21, Tomcat 10.1, and the MySQL Connector/J JAR already included in the original project. It does not drop or alter the existing `questions` or `quiz_results` tables; the new flow uses `ai_questions`, `quiz_attempts`, and `quiz_attempt_questions`.

## Features
- User chooses topic, difficulty, and 5/10/15/20/30 questions (server accepts 1–30).
- Gemini generates MCQs only when the database lacks enough questions for that topic and difficulty.
- Validated questions are stored and reused in later quizzes.
- Java scores submissions and persists per-question answers and attempt results.
- History is sorted newest-first.
- API and DB credentials are read from environment variables rather than hard-coded in source.

## Requirements
- Java 21
- Eclipse IDE for Enterprise Java and Web Developers
- Apache Tomcat 10.1
- MySQL 8.x
- A Gemini API key from Google AI Studio

## 1. Import into Eclipse
1. Extract the ZIP.
2. In Eclipse select **File → Import → General → Existing Projects into Workspace**.
3. Select the extracted `QuizApplication_Gemini` directory.
4. If Eclipse doesn't detect it, create a Dynamic Web Project named `QuizApplication`, target Tomcat 10.1, then copy `src/main/java`, `src/main/webapp`, `database`, and `README_SETUP.md` into it.
5. Confirm the project facet is Java 21 and Dynamic Web Module 6.0. Keep the existing `mysql-connector-j-8.4.0.jar` under `src/main/webapp/WEB-INF/lib`.

## 2. Create the database tables
Open MySQL Workbench and run `database/schema.sql` against the existing `quiz_db` database. It creates only the three new tables and preserves old tables/data.

## 3. Configure environment variables
Set these in the environment that launches Eclipse/Tomcat, then fully restart Eclipse/Tomcat:

Windows Command Prompt (for a new Eclipse launched from this terminal):
```bat
set GEMINI_API_KEY=YOUR_GEMINI_API_KEY
set QUIZ_DB_USER=root
set QUIZ_DB_PASSWORD=YOUR_MYSQL_PASSWORD
set QUIZ_DB_URL=jdbc:mysql://localhost:3306/quiz_db?useSSL=false&serverTimezone=UTC
set GEMINI_MODEL=gemini-flash-latest
eclipse
```

If Eclipse is already open, setting variables in a separate terminal will not update the existing process. Close Eclipse and launch it from the configured terminal, or configure the variables in your operating system and restart Eclipse. Do not commit your real API key or database password to Git.

## 4. Run
1. Right-click project → **Run As → Run on Server** → Tomcat 10.1.
2. Open `http://localhost:8080/QuizApplication/` (use the context path shown by Eclipse if different).
3. Enter a name, topic, difficulty, and question count, then start the quiz.
4. Visit **View quiz history** to see completed attempts.

## Troubleshooting
- JSP pages use the included `com.quiz.util.Html.escape` helper for HTML output encoding; no extra encoder library is required.
- **Gemini API error**: verify `GEMINI_API_KEY`, the configured model name, network access, and API quota. The key is sent using the `x-goog-api-key` header.
- **Database access denied**: set `QUIZ_DB_USER` and `QUIZ_DB_PASSWORD` correctly. The original ZIP contained a database password in JSP source; remove/rotate that credential and don't reuse it.
- **No questions available**: choose a supported difficulty and check that the Gemini API is enabled. Generated questions are saved only after validation.
- **Repeated questions**: existing question records are reused intentionally. The selector randomizes the pool but cannot guarantee a never-before-seen question if the pool is small.

## Security notes
- The API key is only used server-side. Never place it in JSP-rendered HTML or JavaScript.
- This demo identifies a user by entered name, not an authenticated account. Anyone can view the global history; add authentication and per-user authorization before public deployment.
- AI-generated answer keys can be wrong. Review generated questions before relying on them for high-stakes assessments.
