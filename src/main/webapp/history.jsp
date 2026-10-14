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
    List<Map<String,Object>> history =
        new ArrayList<>();

    String error = null;

    try (Connection con = getConnection()) {

        String sql =
            "SELECT id,username,topic,difficulty," +
            "score,total,percentage,created_at " +
            "FROM attempts " +
            "WHERE score IS NOT NULL " +
            "ORDER BY id ASC";

        try (PreparedStatement ps =
                 con.prepareStatement(sql)) {

            try (ResultSet rs =
                     ps.executeQuery()) {

                while (rs.next()) {

                    Map<String,Object> row =
                        new HashMap<>();

                    row.put(
                        "id",
                        rs.getInt("id")
                    );

                    row.put(
                        "username",
                        rs.getString("username")
                    );

                    row.put(
                        "topic",
                        rs.getString("topic")
                    );

                    row.put(
                        "difficulty",
                        rs.getString("difficulty")
                    );

                    row.put(
                        "score",
                        rs.getInt("score")
                    );

                    row.put(
                        "total",
                        rs.getInt("total")
                    );

                    row.put(
                        "percentage",
                        rs.getDouble("percentage")
                    );

                    row.put(
                        "created",
                        rs.getTimestamp(
                            "created_at"
                        )
                    );

                    history.add(row);
                }
            }
        }

    } catch (Exception e) {

        error = e.getMessage();

        if (error == null || error.isBlank()) {
            error = "Could not load quiz history.";
        }
    }
%>

<!DOCTYPE html>
<html lang="en">

<head>

<meta charset="UTF-8">

<meta name="viewport"
      content="width=device-width, initial-scale=1">

<title>Quiz History</title>

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
    max-width: 1100px;
    margin: auto;
}

.header {
    background:
        linear-gradient(120deg,#667eea,#764ba2);
    color: white;
    padding: 26px;
    border-radius: 16px;
    margin-bottom: 20px;
}

.header h1 {
    margin: 0;
}

.header p {
    margin: 8px 0 0;
    opacity: .9;
}

.card {
    background: white;
    border-radius: 14px;
    overflow: hidden;
    box-shadow:
        0 8px 30px rgba(39,51,107,.07);
}

.table-wrap {
    overflow-x: auto;
}

table {
    width: 100%;
    border-collapse: collapse;
}

th,
td {
    padding: 15px;
    text-align: left;
    border-bottom: 1px solid #edf0f6;
    white-space: nowrap;
}

th {
    background: #f7f8fc;
    font-size: 13px;
    color: #606981;
}

tr:hover td {
    background: #fafaff;
}

.badge {
    display: inline-block;
    padding: 6px 9px;
    border-radius: 7px;
    background: #eef0ff;
    color: #5366d6;
    font-size: 12px;
    font-weight: bold;
}

.score {
    font-weight: bold;
}

.empty {
    padding: 35px;
    text-align: center;
    color: #69718a;
}

.back {
    display: inline-block;
    margin-top: 18px;
    padding: 12px 18px;
    border-radius: 9px;
    background: #667eea;
    color: white;
    text-decoration: none;
    font-weight: bold;
}

.error {
    padding: 18px;
    background: #fff0f0;
    color: #a11;
    border-radius: 9px;
}

</style>

</head>

<body>

<main class="wrap">

<header class="header">

    <h1>
        Quiz History
    </h1>

    <p>
        Your completed AI quiz attempts
    </p>

</header>

<% if (error != null) { %>

    <div class="error">
        <%= html(error) %>
    </div>

<% } else if (history.isEmpty()) { %>

    <div class="card">

        <div class="empty">

            <h3>
                No quiz attempts yet.
            </h3>

            <p>
                Start your first AI-generated quiz.
            </p>

            <a class="back"
               href="<%= request.getContextPath() %>/index.jsp">
                Start Quiz
            </a>

        </div>

    </div>

<% } else { %>

    <div class="card">

        <div class="table-wrap">

            <table>

                <thead>

                <tr>
                    <th>#</th>
                    <th>Name</th>
                    <th>Topic</th>
                    <th>Difficulty</th>
                    <th>Score</th>
                    <th>Percentage</th>
                    <th>Date</th>
                </tr>

                </thead>

                <tbody>

                <%
                    int rowNumber = 0;

                    for (Map<String,Object> row :
                         history) {

                        rowNumber++;

                        double percentage =
                            (Double) row.get(
                                "percentage"
                            );
                %>

                <tr>

                    <td>
                        <%= rowNumber %>
                    </td>

                    <td>
                        <%= html(
                            String.valueOf(
                                row.get("username")
                            )
                        ) %>
                    </td>

                    <td>
                        <%= html(
                            String.valueOf(
                                row.get("topic")
                            )
                        ) %>
                    </td>

                    <td>
                        <span class="badge">
                            <%= html(
                                String.valueOf(
                                    row.get("difficulty")
                                )
                            ) %>
                        </span>
                    </td>

                    <td class="score">
                        <%= row.get("score") %>
                        /
                        <%= row.get("total") %>
                    </td>

                    <td>
                        <%= String.format(
                            Locale.US,
                            "%.2f%%",
                            percentage
                        ) %>
                    </td>

                    <td>
                        <%= row.get("created") %>
                    </td>

                </tr>

                <% } %>

                </tbody>

            </table>

        </div>

    </div>

    <a class="back"
       href="<%= request.getContextPath() %>/index.jsp">
        ← Start New Quiz
    </a>

<% } %>

</main>

</body>
</html>