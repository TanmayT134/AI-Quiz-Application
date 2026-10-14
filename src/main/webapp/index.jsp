<%@ page language="java"
         contentType="text/html; charset=UTF-8"
         pageEncoding="UTF-8"
         import="java.sql.*,java.net.*,java.net.http.*,java.time.Duration,java.util.*" %>

<%!
    private String clean(String s) {
        return s == null ? "" : s.trim();
    }

    private String html(String s) {
        if (s == null) return "";
        return s.replace("&", "&amp;")
                .replace("<", "&lt;")
                .replace(">", "&gt;")
                .replace("\"", "&quot;")
                .replace("'", "&#39;");
    }

    private Connection getConnection() throws Exception {

        String url = System.getenv().getOrDefault(
            "QUIZ_DB_URL",
            "jdbc:mysql://localhost:3306/quiz_db?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC"
        );

        String user = System.getenv().getOrDefault(
            "QUIZ_DB_USER",
            "root"
        );

        String password = System.getenv(
            "QUIZ_DB_PASSWORD"
        );

        if (password == null) {
            password = "";
        }

        Class.forName("com.mysql.cj.jdbc.Driver");

        return DriverManager.getConnection(
            url,
            user,
            password
        );
    }

    private void createTables(Connection con) throws Exception {

        try (Statement st = con.createStatement()) {

            st.executeUpdate(
                "CREATE TABLE IF NOT EXISTS questions (" +
                "id INT AUTO_INCREMENT PRIMARY KEY," +
                "topic VARCHAR(100) NOT NULL," +
                "difficulty VARCHAR(20) NOT NULL," +
                "question_text TEXT NOT NULL," +
                "option_a TEXT NOT NULL," +
                "option_b TEXT NOT NULL," +
                "option_c TEXT NOT NULL," +
                "option_d TEXT NOT NULL," +
                "correct_option CHAR(1) NOT NULL," +
                "explanation TEXT," +
                "created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP," +
                "INDEX idx_topic_diff (topic, difficulty)" +
                ")"
            );

            st.executeUpdate(
                "CREATE TABLE IF NOT EXISTS attempts (" +
                "id INT AUTO_INCREMENT PRIMARY KEY," +
                "username VARCHAR(100) NOT NULL," +
                "topic VARCHAR(100) NOT NULL," +
                "difficulty VARCHAR(20) NOT NULL," +
                "total INT NOT NULL," +
                "score INT NULL," +
                "percentage DECIMAL(6,2) NULL," +
                "created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP" +
                ")"
            );

            st.executeUpdate(
                "CREATE TABLE IF NOT EXISTS attempt_questions (" +
                "id INT AUTO_INCREMENT PRIMARY KEY," +
                "attempt_id INT NOT NULL," +
                "question_id INT NOT NULL," +
                "question_order INT NOT NULL," +
                "FOREIGN KEY (attempt_id) REFERENCES attempts(id) " +
                "ON DELETE CASCADE," +
                "FOREIGN KEY (question_id) REFERENCES questions(id)," +
                "INDEX idx_attempt (attempt_id)" +
                ")"
            );
        }
    }

    private String jsonQuote(String s) {

        if (s == null) return "\"\"";

        StringBuilder b = new StringBuilder("\"");

        for (char c : s.toCharArray()) {

            switch (c) {

                case '"':
                    b.append("\\\"");
                    break;

                case '\\':
                    b.append("\\\\");
                    break;

                case '\n':
                    b.append("\\n");
                    break;

                case '\r':
                    b.append("\\r");
                    break;

                case '\t':
                    b.append("\\t");
                    break;

                default:
                    if (c < 32) {
                        b.append(String.format("\\u%04x", (int)c));
                    } else {
                        b.append(c);
                    }
            }
        }

        b.append("\"");

        return b.toString();
    }

    private String jsonUnescape(String s) {

        StringBuilder b = new StringBuilder();

        for (int i = 0; i < s.length(); i++) {

            char c = s.charAt(i);

            if (c != '\\' || i + 1 >= s.length()) {
                b.append(c);
                continue;
            }

            char n = s.charAt(++i);

            switch (n) {

                case '"':
                    b.append('"');
                    break;

                case '\\':
                    b.append('\\');
                    break;

                case '/':
                    b.append('/');
                    break;

                case 'b':
                    b.append('\b');
                    break;

                case 'f':
                    b.append('\f');
                    break;

                case 'n':
                    b.append('\n');
                    break;

                case 'r':
                    b.append('\r');
                    break;

                case 't':
                    b.append('\t');
                    break;

                case 'u':
                    if (i + 4 < s.length()) {
                        String hex =
                            s.substring(i + 1, i + 5);

                        try {
                            b.append(
                                (char) Integer.parseInt(hex, 16)
                            );
                            i += 4;
                        } catch (Exception e) {
                            b.append("\\u").append(hex);
                            i += 4;
                        }
                    }
                    break;

                default:
                    b.append(n);
            }
        }

        return b.toString();
    }

    private String extractGeminiText(String json) throws Exception {

        String marker = "\"text\"";

        int markerIndex = json.indexOf(marker);

        if (markerIndex < 0) {
            throw new Exception(
                "Gemini response does not contain generated text."
            );
        }

        int colonIndex = json.indexOf(
            ':',
            markerIndex + marker.length()
        );

        if (colonIndex < 0) {
            throw new Exception(
                "Invalid Gemini response."
            );
        }

        int start = colonIndex + 1;

        while (start < json.length()
                && Character.isWhitespace(json.charAt(start))) {
            start++;
        }

        if (start >= json.length()
                || json.charAt(start) != '"') {
            throw new Exception(
                "Gemini text field is not a JSON string."
            );
        }

        start++;

        StringBuilder result = new StringBuilder();

        boolean escaped = false;

        for (int i = start; i < json.length(); i++) {

            char c = json.charAt(i);

            if (escaped) {

                switch (c) {

                    case '"':
                        result.append('"');
                        break;

                    case '\\':
                        result.append('\\');
                        break;

                    case '/':
                        result.append('/');
                        break;

                    case 'b':
                        result.append('\b');
                        break;

                    case 'f':
                        result.append('\f');
                        break;

                    case 'n':
                        result.append('\n');
                        break;

                    case 'r':
                        result.append('\r');
                        break;

                    case 't':
                        result.append('\t');
                        break;

                    case 'u':

                        if (i + 4 >= json.length()) {
                            throw new Exception(
                                "Invalid Unicode escape in Gemini response."
                            );
                        }

                        String hex =
                            json.substring(i + 1, i + 5);

                        try {
                            result.append(
                                (char) Integer.parseInt(hex, 16)
                            );
                        } catch (NumberFormatException e) {
                            throw new Exception(
                                "Invalid Unicode escape in Gemini response."
                            );
                        }

                        i += 4;
                        break;

                    default:
                        result.append(c);
                }

                escaped = false;

            } else if (c == '\\') {

                escaped = true;

            } else if (c == '"') {

                return result.toString().trim();

            } else {

                result.append(c);
            }
        }

        throw new Exception(
            "Gemini response contains an unterminated text field."
        );
    }

    private List<String[]> generateQuestions(
            String topic,
            String difficulty,
            int count) throws Exception {

        String apiKey = System.getenv("GEMINI_API_KEY");

        if (apiKey == null || apiKey.isBlank()) {
            throw new Exception(
                "GEMINI_API_KEY is not configured. " +
                "Add it to your Tomcat environment."
            );
        }

        String model = System.getenv().getOrDefault(
            "GEMINI_MODEL",
            "gemini-3.8-flash"
        );

        String prompt =
            "Create exactly " + count +
            " original multiple-choice quiz questions about " +
            topic + ". " +

            "Difficulty: " + difficulty + ". " +

            "Return ONLY the requested records. " +

            "Each question must be exactly one line using this format: " +

            "QUESTION|OPTION_A|OPTION_B|OPTION_C|OPTION_D|CORRECT|EXPLANATION " +

            "CORRECT must be exactly A, B, C, or D. " +

            "There must be exactly one correct answer. " +

            "Do not use the pipe character | anywhere inside question, " +
            "options, or explanation. " +

            "Do not use numbering. " +
            "Do not use markdown. " +
            "Do not add introductory or closing text. " +
            "Generate exactly " + count + " lines.";

        String body =
            "{\"contents\":[{\"parts\":[{\"text\":" +
            jsonQuote(prompt) +
            "}]}]," +
            "\"generationConfig\":{" +
            "\"temperature\":0.4," +
            "\"responseMimeType\":\"text/plain\"" +
            "}}";

        HttpClient client =
            HttpClient.newBuilder()
                      .connectTimeout(Duration.ofSeconds(20))
                      .build();

        Exception lastError = null;

        for (int attempt = 1; attempt <= 4; attempt++) {

            try {

                HttpRequest request =
                    HttpRequest.newBuilder()
                        .uri(
                            URI.create(
                                "https://generativelanguage.googleapis.com/" +
                                "v1beta/models/" +
                                model +
                                ":generateContent"
                            )
                        )
                        .timeout(Duration.ofSeconds(90))
                        .header(
                            "Content-Type",
                            "application/json"
                        )
                        .header(
                            "x-goog-api-key",
                            apiKey
                        )
                        .POST(
                            HttpRequest.BodyPublishers.ofString(body)
                        )
                        .build();

                HttpResponse<String> response =
                    client.send(
                        request,
                        HttpResponse.BodyHandlers.ofString()
                    );

                int status = response.statusCode();

                if (status >= 200 && status < 300) {

                    String text =
                        extractGeminiText(response.body());

                    List<String[]> result =
                        new ArrayList<>();

                    String[] lines =
                        text.split("\\r?\\n");

                    for (String line : lines) {

                        line = line.trim();

                        if (line.isBlank()) continue;

                        String[] parts =
                            line.split("\\|", -1);

                        if (parts.length != 7) continue;

                        for (int i = 0; i < parts.length; i++) {
                            parts[i] = parts[i].trim();
                        }

                        String correct =
                            parts[5].toUpperCase(Locale.ROOT);

                        if (!Set.of("A", "B", "C", "D")
                                .contains(correct)) {
                            continue;
                        }

                        if (parts[0].isBlank()
                                || parts[1].isBlank()
                                || parts[2].isBlank()
                                || parts[3].isBlank()
                                || parts[4].isBlank()) {
                            continue;
                        }

                        parts[5] = correct;

                        result.add(parts);
                    }

                    if (result.size() < count) {
                        throw new Exception(
                            "Gemini generated only " +
                            result.size() +
                            " valid questions out of " +
                            count +
                            ". Please try again."
                        );
                    }

                    return new ArrayList<>(
                        result.subList(0, count)
                    );
                }

                String errorBody = response.body();

                if (status == 503 || status == 429) {

                    lastError = new Exception(
                        "Gemini API temporarily unavailable " +
                        "(HTTP " + status + ")."
                    );

                    Thread.sleep(
                        (long) Math.pow(2, attempt - 1) * 1500L
                    );

                } else {

                    throw new Exception(
                        "Gemini API HTTP " +
                        status +
                        ". Response: " +
                        errorBody
                    );
                }

            } catch (Exception e) {

                lastError = e;

                if (attempt == 4) {
                    break;
                }

                Thread.sleep(
                    (long) Math.pow(2, attempt - 1) * 1000L
                );
            }
        }

        throw new Exception(
            "Gemini could not generate the questions after " +
            "multiple attempts. " +
            (lastError == null
                ? ""
                : lastError.getMessage())
        );
    }

    private int countQuestions(
            Connection con,
            String topic,
            String difficulty) throws Exception {

        String sql =
            "SELECT COUNT(*) FROM questions " +
            "WHERE topic=? AND difficulty=?";

        try (PreparedStatement ps =
                 con.prepareStatement(sql)) {

            ps.setString(1, topic);
            ps.setString(2, difficulty);

            try (ResultSet rs = ps.executeQuery()) {

                rs.next();

                return rs.getInt(1);
            }
        }
    }

    private void saveQuestion(
            Connection con,
            String topic,
            String difficulty,
            String[] q) throws Exception {

        String sql =
            "INSERT INTO questions " +
            "(topic,difficulty,question_text,option_a,option_b," +
            "option_c,option_d,correct_option,explanation) " +
            "VALUES (?,?,?,?,?,?,?,?,?)";

        try (PreparedStatement ps =
                 con.prepareStatement(sql)) {

            ps.setString(1, topic);
            ps.setString(2, difficulty);
            ps.setString(3, q[0]);
            ps.setString(4, q[1]);
            ps.setString(5, q[2]);
            ps.setString(6, q[3]);
            ps.setString(7, q[4]);
            ps.setString(8, q[5]);
            ps.setString(9, q[6]);

            ps.executeUpdate();
        }
    }
%>

<%
    String error = null;

    if ("POST".equalsIgnoreCase(request.getMethod())) {

        request.setCharacterEncoding("UTF-8");

        String username =
            clean(request.getParameter("username"));

        String topic =
            clean(request.getParameter("topic"));

        String difficulty =
            clean(request.getParameter("difficulty"));

        int count = 0;

        try {
            count = Integer.parseInt(
                request.getParameter("questionCount")
            );
        } catch (Exception ignored) {
        }

        if (username.isBlank()
                || username.length() > 100
                || topic.isBlank()
                || topic.length() > 100
                || !Set.of("Easy", "Medium", "Hard")
                    .contains(difficulty)
                || count < 1
                || count > 30) {

            error =
                "Please enter valid quiz details.";
        } else {

            try (Connection con = getConnection()) {

                createTables(con);

                int available =
                    countQuestions(
                        con,
                        topic,
                        difficulty
                    );

                if (available < count) {

                    int need = count - available;

                    int generateCount =
                        Math.min(need + 2, 30);

                    List<String[]> generated =
                        generateQuestions(
                            topic,
                            difficulty,
                            generateCount
                        );

                    for (String[] q : generated) {
                        saveQuestion(
                            con,
                            topic,
                            difficulty,
                            q
                        );
                    }
                }

                con.setAutoCommit(false);

                List<Integer> questionIds =
                    new ArrayList<>();

                String selectSql =
                    "SELECT id FROM questions " +
                    "WHERE topic=? AND difficulty=? " +
                    "ORDER BY RAND() LIMIT ?";

                try (PreparedStatement ps =
                         con.prepareStatement(selectSql)) {

                    ps.setString(1, topic);
                    ps.setString(2, difficulty);
                    ps.setInt(3, count);

                    try (ResultSet rs =
                             ps.executeQuery()) {

                        while (rs.next()) {
                            questionIds.add(
                                rs.getInt("id")
                            );
                        }
                    }
                }

                if (questionIds.size() != count) {

                    con.rollback();

                    throw new Exception(
                        "Not enough questions are available. " +
                        "Please try again."
                    );
                }

                int attemptId;

                String insertAttempt =
                    "INSERT INTO attempts " +
                    "(username,topic,difficulty,total) " +
                    "VALUES (?,?,?,?)";

                try (PreparedStatement ps =
                         con.prepareStatement(
                             insertAttempt,
                             Statement.RETURN_GENERATED_KEYS
                         )) {

                    ps.setString(1, username);
                    ps.setString(2, topic);
                    ps.setString(3, difficulty);
                    ps.setInt(4, count);

                    ps.executeUpdate();

                    try (ResultSet rs =
                             ps.getGeneratedKeys()) {

                        if (!rs.next()) {
                            throw new Exception(
                                "Could not create quiz attempt."
                            );
                        }

                        attemptId = rs.getInt(1);
                    }
                }

                String insertQuestion =
                    "INSERT INTO attempt_questions " +
                    "(attempt_id,question_id,question_order) " +
                    "VALUES (?,?,?)";

                try (PreparedStatement ps =
                         con.prepareStatement(insertQuestion)) {

                    for (int i = 0;
                         i < questionIds.size();
                         i++) {

                        ps.setInt(1, attemptId);
                        ps.setInt(2, questionIds.get(i));
                        ps.setInt(3, i + 1);

                        ps.addBatch();
                    }

                    ps.executeBatch();
                }

                con.commit();

                int secondsPerQuestion;

                switch (difficulty) {

                    case "Easy":
                        secondsPerQuestion = 30;
                        break;

                    case "Medium":
                        secondsPerQuestion = 45;
                        break;

                    default:
                        secondsPerQuestion = 60;
                        break;
                }

                long deadline =
                    System.currentTimeMillis()
                    + ((long) count
                    * secondsPerQuestion
                    * 1000L);

                session.setAttribute(
                    "quizAttemptId",
                    attemptId
                );

                session.setAttribute(
                    "quizUsername",
                    username
                );

                session.setAttribute(
                    "quizDeadlineMillis",
                    deadline
                );

                response.sendRedirect(
                    request.getContextPath()
                    + "/quiz.jsp"
                );

                return;
            } catch (Exception e) {

                error = e.getMessage();

                if (error == null || error.isBlank()) {
                    error =
                        "Unable to start quiz.";
                }
            }
        }
    }
%>

<!DOCTYPE html>
<html lang="en">
<head>

<meta charset="UTF-8">
<meta name="viewport"
      content="width=device-width, initial-scale=1">

<title>AI Quiz</title>

<style>

* {
    box-sizing: border-box;
}

body {
    margin: 0;
    min-height: 100vh;
    font-family: Arial, sans-serif;
    background: linear-gradient(135deg,#eef1ff,#f8f4ff);
    color: #252a3a;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 25px;
}

.card {
    width: 100%;
    max-width: 600px;
    background: white;
    padding: 34px;
    border-radius: 18px;
    box-shadow: 0 15px 45px rgba(39,51,107,.12);
}

h1 {
    margin: 0;
    font-size: 30px;
}

.subtitle {
    color: #68708a;
    margin: 10px 0 28px;
    line-height: 1.5;
}

label {
    display: block;
    margin: 17px 0 7px;
    font-weight: bold;
}

input,
select {
    width: 100%;
    padding: 13px;
    border: 1px solid #dfe3f0;
    border-radius: 9px;
    font-size: 15px;
    outline: none;
}

input:focus,
select:focus {
    border-color: #667eea;
}

.btn {
    width: 100%;
    margin-top: 24px;
    padding: 15px;
    border: 0;
    border-radius: 10px;
    background: linear-gradient(120deg,#667eea,#764ba2);
    color: white;
    font-size: 16px;
    font-weight: bold;
    cursor: pointer;
}

.btn:hover {
    opacity: .92;
}

.links {
    text-align: center;
    margin-top: 18px;
}

.links a {
    color: #667eea;
    text-decoration: none;
    font-weight: bold;
}

.error {
    background: #fff0f0;
    border: 1px solid #ffcaca;
    color: #a11;
    padding: 13px;
    border-radius: 9px;
    margin-bottom: 18px;
}

.info {
    margin-top: 20px;
    padding: 13px;
    background: #f4f5ff;
    border-radius: 9px;
    color: #555d78;
    font-size: 14px;
    line-height: 1.6;
}

</style>

</head>

<body>

<div class="card">

    <h1>AI Quiz</h1>

    <p class="subtitle">
        Generate an AI-powered quiz based on your
        topic and difficulty.
    </p>

    <% if (error != null) { %>

        <div class="error">
            <%= html(error) %>
        </div>

    <% } %>

    <form method="post">

        <label>Username</label>

        <input type="text"
               name="username"
               maxlength="100"
               required
               placeholder="Enter your name">

        <label>Topic</label>

        <input type="text"
               name="topic"
               maxlength="100"
               required
               placeholder="e.g. Java, Python, DBMS">

        <label>Difficulty</label>

        <select name="difficulty" required>

            <option value="">Select difficulty</option>
            <option value="Easy">Easy</option>
            <option value="Medium">Medium</option>
            <option value="Hard">Hard</option>

        </select>

        <label>Number of Questions</label>

        <select name="questionCount" required>

            <option value="">Select number</option>
            <option value="5">5</option>
            <option value="10">10</option>
            <option value="15">15</option>
            <option value="20">20</option>
            <option value="30">30</option>

        </select>

        <button class="btn" type="submit">
            Start AI Quiz
        </button>

    </form>

    <div class="info">
        <strong>Timer:</strong><br>
        Easy — 30 seconds/question<br>
        Medium — 45 seconds/question<br>
        Hard — 60 seconds/question
    </div>

    <div class="links">
        <a href="history.jsp">View Quiz History</a>
    </div>

</div>

</body>
</html>