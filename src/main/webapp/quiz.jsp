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

        Class.forName("com.mysql.cj.jdbc.Driver");

        return DriverManager.getConnection(
            url,
            user,
            password
        );
    }
%>

<%
    Integer attemptId =
        (Integer) session.getAttribute(
            "quizAttemptId"
        );

    Long deadline =
        (Long) session.getAttribute(
            "quizDeadlineMillis"
        );

    if (attemptId == null || deadline == null) {

        response.sendRedirect(
            request.getContextPath()
            + "/index.jsp"
        );

        return;
    }

    long remainingSeconds =
        Math.max(
            0L,
            (deadline
             - System.currentTimeMillis()
             + 999L) / 1000L
        );

    String username =
        String.valueOf(
            session.getAttribute(
                "quizUsername"
            )
        );

    List<Map<String,Object>> questions =
        new ArrayList<>();

    String topic = "";
    String difficulty = "";

    try (Connection con = getConnection()) {

        String sql =
            "SELECT q.id,q.question_text,q.option_a," +
            "q.option_b,q.option_c,q.option_d," +
            "a.topic,a.difficulty " +
            "FROM attempt_questions aq " +
            "JOIN questions q ON q.id=aq.question_id " +
            "JOIN attempts a ON a.id=aq.attempt_id " +
            "WHERE aq.attempt_id=? " +
            "ORDER BY aq.question_order";

        try (PreparedStatement ps =
                 con.prepareStatement(sql)) {

            ps.setInt(1, attemptId);

            try (ResultSet rs =
                     ps.executeQuery()) {

                while (rs.next()) {

                    Map<String,Object> q =
                        new HashMap<>();

                    q.put("id",
                          rs.getInt("id"));

                    q.put("question",
                          rs.getString("question_text"));

                    q.put("a",
                          rs.getString("option_a"));

                    q.put("b",
                          rs.getString("option_b"));

                    q.put("c",
                          rs.getString("option_c"));

                    q.put("d",
                          rs.getString("option_d"));

                    questions.add(q);

                    topic =
                        rs.getString("topic");

                    difficulty =
                        rs.getString("difficulty");
                }
            }
        }

    } catch (Exception e) {

        application.log(
            "Quiz loading failed",
            e
        );
    }
%>

<!DOCTYPE html>
<html lang="en">

<head>

<meta charset="UTF-8">

<meta name="viewport"
      content="width=device-width, initial-scale=1">

<title>Your Quiz</title>

<style>

* {
    box-sizing: border-box;
}

body {
    margin: 0;
    padding: 28px 16px;
    font-family: Arial, sans-serif;
    background: #f4f6ff;
    color: #252a3a;
}

.wrap {
    max-width: 850px;
    margin: auto;
}

.top {
    background:
        linear-gradient(120deg,#667eea,#764ba2);
    color: white;
    padding: 26px;
    border-radius: 16px;
    margin-bottom: 20px;
}

.top h1 {
    margin: 0;
    font-size: 27px;
}

.top p {
    margin: 8px 0 0;
    opacity: .9;
}

.timer {
    display: inline-flex;
    align-items: center;
    gap: 9px;
    margin-top: 17px;
    padding: 10px 16px;
    border-radius: 10px;
    background: rgba(255,255,255,.14);
    border: 1px solid rgba(255,255,255,.3);
    font-weight: bold;
}

#timerValue {
    font-size: 21px;
    font-variant-numeric: tabular-nums;
    letter-spacing: 1px;
}

.timer.warning {
    color: #ffe49a;
    border-color: #ffe49a;
}

.timer.expired {
    color: #ffd0d0;
    border-color: #ff8b8b;
    background: rgba(150,0,0,.25);
}

.q {
    background: white;
    border: 1px solid #e5e8f5;
    padding: 22px;
    border-radius: 13px;
    margin: 14px 0;
    box-shadow: 0 5px 18px rgba(39,51,107,.04);
}

.q h3 {
    font-size: 17px;
    line-height: 1.5;
    margin: 0 0 15px;
}

.opt {
    display: flex;
    align-items: flex-start;
    gap: 10px;
    padding: 12px;
    border: 1px solid #e3e6f0;
    border-radius: 9px;
    margin: 8px 0;
    cursor: pointer;
}

.opt:hover {
    background: #f4f5ff;
    border-color: #aab4fa;
}

.opt input {
    margin-top: 3px;
    accent-color: #667eea;
}

.btn {
    width: 100%;
    padding: 15px;
    border: 0;
    border-radius: 10px;
    background: #667eea;
    color: white;
    font-size: 16px;
    font-weight: bold;
    cursor: pointer;
    margin: 12px 0;
}

.btn:hover {
    background: #5366d6;
}

.empty {
    background: white;
    padding: 25px;
    border-radius: 12px;
}

</style>

</head>

<body>

<main class="wrap">

<header class="top">

    <h1>
        Ready, <%= html(username) %>?
    </h1>

    <p>
        <%= questions.size() %>
        questions ·
        <%= html(topic) %> ·
        <%= html(difficulty) %>
    </p>

    <div class="timer"
         id="quizTimer"
         role="timer">

        <span id="timerLabel">
            Time remaining:
        </span>

        <span id="timerValue">
            --:--
        </span>

    </div>

</header>

<% if (questions.isEmpty()) { %>

    <div class="empty">

        <h3>Could not load this quiz.</h3>

        <a href="index.jsp">
            Start again
        </a>

    </div>

<% } else { %>

<form id="quizForm"
      method="post"
      action="result.jsp">

    <input type="hidden"
           name="attemptId"
           value="<%= attemptId %>">

    <%
        int number = 0;

        for (Map<String,Object> q : questions) {

            number++;

            int id =
                (Integer) q.get("id");
    %>

    <section class="q">

        <h3>
            <%= number %>.
            <%= html(
                String.valueOf(
                    q.get("question")
                )
            ) %>
        </h3>

        <label class="opt">

            <input type="radio"
                   name="q_<%= id %>"
                   value="A"
                   required>

            <span>
                <strong>A.</strong>
                <%= html(
                    String.valueOf(q.get("a"))
                ) %>
            </span>

        </label>

        <label class="opt">

            <input type="radio"
                   name="q_<%= id %>"
                   value="B">

            <span>
                <strong>B.</strong>
                <%= html(
                    String.valueOf(q.get("b"))
                ) %>
            </span>

        </label>

        <label class="opt">

            <input type="radio"
                   name="q_<%= id %>"
                   value="C">

            <span>
                <strong>C.</strong>
                <%= html(
                    String.valueOf(q.get("c"))
                ) %>
            </span>

        </label>

        <label class="opt">

            <input type="radio"
                   name="q_<%= id %>"
                   value="D">

            <span>
                <strong>D.</strong>
                <%= html(
                    String.valueOf(q.get("d"))
                ) %>
            </span>

        </label>

    </section>

    <% } %>

    <button class="btn"
            type="submit"
            id="submitButton">

        Submit Quiz

    </button>

</form>

<% } %>

</main>

<script>

(() => {

    let remaining =
        <%= remainingSeconds %>;

    const timer =
        document.getElementById(
            "quizTimer"
        );

    const display =
        document.getElementById(
            "timerValue"
        );

    const label =
        document.getElementById(
            "timerLabel"
        );

    const form =
        document.getElementById(
            "quizForm"
        );

    let submitted = false;
    let interval = null;

    function updateTimer() {

        const safe =
            Math.max(0, remaining);

        const minutes =
            Math.floor(safe / 60);

        const seconds =
            safe % 60;

        display.textContent =
            String(minutes).padStart(2,"0")
            + ":"
            + String(seconds).padStart(2,"0");

        if (safe <= 60) {
            timer.classList.add(
                "warning"
            );
        }

        if (safe <= 10) {
            timer.classList.add(
                "expired"
            );
        }

        if (safe <= 0) {

            label.textContent =
                "Time expired:";

            if (interval !== null) {
                clearInterval(interval);
                interval = null;
            }

            if (!submitted && form) {

                submitted = true;

                /*
                 * Bypass HTML required validation.
                 * Unanswered questions will be
                 * treated as incorrect by result.jsp.
                 */
                HTMLFormElement.prototype.submit.call(
                    form
                );
            }

            return;
        }

        remaining--;
    }

    updateTimer();

    if (remaining > 0) {

        interval =
            setInterval(
                updateTimer,
                1000
            );
    }

    if (form) {

        form.addEventListener(
            "submit",
            function(event) {

                if (submitted) {
                    event.preventDefault();
                    return;
                }

                submitted = true;

                if (interval !== null) {
                    clearInterval(interval);
                    interval = null;
                }
            }
        );
    }

})();

</script>

</body>
</html>