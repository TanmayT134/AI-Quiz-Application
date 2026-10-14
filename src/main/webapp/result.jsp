<%@ page language="java"
         contentType="text/html; charset=UTF-8"
         pageEncoding="UTF-8"
         import="java.sql.*,java.util.*" %>

<%!
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

        String password =
            System.getenv("QUIZ_DB_PASSWORD");

        if (password == null) {
            password = "";
        }

        Class.forName(
            "com.mysql.cj.jdbc.Driver"
        );

        return DriverManager.getConnection(
            url,
            user,
            password
        );
    }
%>

<%
    request.setCharacterEncoding("UTF-8");

    int attemptId = 0;

    try {

        String id =
            request.getParameter("attemptId");

        if (id != null) {
            attemptId = Integer.parseInt(id);
        }

    } catch (Exception ignored) {
    }

    if (attemptId == 0) {

        Integer sessionAttempt =
            (Integer) session.getAttribute(
                "quizAttemptId"
            );

        if (sessionAttempt != null) {
            attemptId = sessionAttempt;
        }
    }

    if (attemptId == 0) {

        response.sendRedirect(
            request.getContextPath()
            + "/index.jsp"
        );

        return;
    }

    String username = "";
    String topic = "";
    String difficulty = "";

    int total = 0;
    int score = 0;

    double percentage = 0;

    boolean alreadySubmitted = false;

    try (Connection con = getConnection()) {

        String infoSql =
            "SELECT username,topic,difficulty,total,score," +
            "percentage FROM attempts WHERE id=?";

        try (PreparedStatement ps =
                 con.prepareStatement(infoSql)) {

            ps.setInt(1, attemptId);

            try (ResultSet rs =
                     ps.executeQuery()) {

                if (!rs.next()) {

                    response.sendRedirect(
                        request.getContextPath()
                        + "/index.jsp"
                    );

                    return;
                }

                username =
                    rs.getString("username");

                topic =
                    rs.getString("topic");

                difficulty =
                    rs.getString("difficulty");

                total =
                    rs.getInt("total");

                Object savedScore =
                    rs.getObject("score");

                if (savedScore != null) {

                    alreadySubmitted = true;

                    score =
                        rs.getInt("score");

                    percentage =
                        rs.getDouble("percentage");
                }
            }
        }

        /*
         * If result has not already been saved,
         * calculate it now.
         */
        if (!alreadySubmitted
                && "POST".equalsIgnoreCase(
                    request.getMethod())) {

            String questionSql =
                "SELECT q.id,q.correct_option " +
                "FROM attempt_questions aq " +
                "JOIN questions q " +
                "ON q.id=aq.question_id " +
                "WHERE aq.attempt_id=?";

            List<Integer> questionIds =
                new ArrayList<>();

            Map<Integer,String> correctAnswers =
                new HashMap<>();

            try (PreparedStatement ps =
                     con.prepareStatement(questionSql)) {

                ps.setInt(1, attemptId);

                try (ResultSet rs =
                         ps.executeQuery()) {

                    while (rs.next()) {

                        int id =
                            rs.getInt("id");

                        String correct =
                            rs.getString(
                                "correct_option"
                            );

                        questionIds.add(id);

                        correctAnswers.put(
                            id,
                            correct
                        );
                    }
                }
            }

            /*
             * Score answers.
             *
             * If time expired, the submitted answers
             * are still scored, while unanswered
             * questions remain incorrect.
             */
            for (Integer id : questionIds) {

                String submitted =
                    request.getParameter(
                        "q_" + id
                    );

                String correct =
                    correctAnswers.get(id);

                if (submitted != null
                        && correct != null
                        && submitted.equalsIgnoreCase(
                            correct
                        )) {

                    score++;
                }
            }

            percentage =
                total == 0
                    ? 0
                    : ((double) score / total) * 100.0;

            String updateSql =
                "UPDATE attempts " +
                "SET score=?,percentage=? " +
                "WHERE id=? AND score IS NULL";

            try (PreparedStatement ps =
                     con.prepareStatement(
                         updateSql
                     )) {

                ps.setInt(1, score);

                ps.setDouble(
                    2,
                    percentage
                );

                ps.setInt(
                    3,
                    attemptId
                );

                ps.executeUpdate();
            }

        } else if (!alreadySubmitted) {

            /*
             * If someone directly opens result.jsp
             * without submitting the quiz, send
             * them back.
             */
            response.sendRedirect(
                request.getContextPath()
                + "/quiz.jsp"
            );

            return;
        }

        /*
         * Re-read the final saved score.
         */
        String finalSql =
            "SELECT username,topic,difficulty,total," +
            "score,percentage FROM attempts WHERE id=?";

        try (PreparedStatement ps =
                 con.prepareStatement(finalSql)) {

            ps.setInt(1, attemptId);

            try (ResultSet rs =
                     ps.executeQuery()) {

                if (rs.next()) {

                    username =
                        rs.getString("username");

                    topic =
                        rs.getString("topic");

                    difficulty =
                        rs.getString("difficulty");

                    total =
                        rs.getInt("total");

                    score =
                        rs.getInt("score");

                    percentage =
                        rs.getDouble("percentage");
                }
            }
        }

    } catch (Exception e) {

        application.log(
            "Result processing failed",
            e
        );

        response.sendRedirect(
            request.getContextPath()
            + "/index.jsp"
        );

        return;
    }

    /*
     * Clear active quiz session values.
     */
    session.removeAttribute(
        "quizAttemptId"
    );

    session.removeAttribute(
        "quizDeadlineMillis"
    );

    session.removeAttribute(
        "quizUsername"
    );

    String message;

    if (percentage >= 80) {
        message = "Excellent work!";
    } else if (percentage >= 60) {
        message = "Good job!";
    } else if (percentage >= 40) {
        message = "Keep practicing!";
    } else {
        message = "Don't give up. Try again!";
    }
%>

<!DOCTYPE html>
<html lang="en">

<head>

<meta charset="UTF-8">

<meta name="viewport"
      content="width=device-width, initial-scale=1">

<title>Quiz Result</title>

<style>

* {
    box-sizing: border-box;
}

body {
    margin: 0;
    min-height: 100vh;
    font-family: Arial, sans-serif;
    background: linear-gradient(
        135deg,#eef1ff,#f8f4ff
    );
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 20px;
    color: #252a3a;
}

.card {
    width: 100%;
    max-width: 600px;
    background: white;
    padding: 35px;
    border-radius: 18px;
    text-align: center;
    box-shadow:
        0 15px 45px rgba(39,51,107,.12);
}

.icon {
    width: 70px;
    height: 70px;
    margin: 0 auto 18px;
    border-radius: 50%;
    background: #eef0ff;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 32px;
}

h1 {
    margin: 0;
}

.message {
    color: #69718a;
    margin: 10px 0 25px;
}

.score {
    font-size: 48px;
    font-weight: bold;
    color: #667eea;
    margin: 15px 0;
}

.details {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 12px;
    margin: 25px 0;
}

.detail {
    background: #f6f7fc;
    padding: 15px;
    border-radius: 10px;
}

.detail strong {
    display: block;
    margin-bottom: 5px;
}

.actions {
    display: flex;
    gap: 10px;
    flex-wrap: wrap;
}

.btn {
    flex: 1;
    min-width: 180px;
    padding: 14px;
    border-radius: 10px;
    text-decoration: none;
    background: #667eea;
    color: white;
    font-weight: bold;
}

.btn.secondary {
    background: #eef0ff;
    color: #5366d6;
}

@media(max-width:500px) {

    .card {
        padding: 25px 18px;
    }

    .details {
        grid-template-columns: 1fr;
    }
}

</style>

</head>

<body>

<div class="card">

    <div class="icon">
        ✓
    </div>

    <h1>
        Quiz Completed
    </h1>

    <p class="message">
        <%= html(message) %>
    </p>

    <div class="score">
        <%= score %> / <%= total %>
    </div>

    <div class="details">

        <div class="detail">
            <strong>Name</strong>
            <%= html(username) %>
        </div>

        <div class="detail">
            <strong>Topic</strong>
            <%= html(topic) %>
        </div>

        <div class="detail">
            <strong>Difficulty</strong>
            <%= html(difficulty) %>
        </div>

        <div class="detail">
            <strong>Percentage</strong>
            <%= String.format(
                Locale.US,
                "%.2f%%",
                percentage
            ) %>
        </div>

    </div>

    <div class="actions">

        <a class="btn"
           href="<%= request.getContextPath() %>/index.jsp">
            Take Another Quiz
        </a>

        <a class="btn secondary"
           href="<%= request.getContextPath() %>/history.jsp">
            View History
        </a>

    </div>

</div>

</body>
</html>