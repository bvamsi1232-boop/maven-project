<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Vamsi DevOps Training</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 0;
            background-color: #f4f4f4;
        }
        header {
            background-color: #0073e6;
            color: white;
            padding: 20px 0;
            text-align: center;
        }
        nav {
            background-color: #333;
            overflow: hidden;
        }
        nav a {
            float: left;
            display: block;
            color: #f2f2f2;
            padding: 14px 20px;
            text-decoration: none;
        }
        nav a:hover {
            background-color: #575757;
        }
        .container {
            padding: 40px;
            text-align: center;
        }
        .services {
            display: flex;
            justify-content: space-around;
            margin-top: 30px;
        }
        .service-box {
            background-color: white;
            padding: 20px;
            width: 30%;
            box-shadow: 0 0 10px rgba(0,0,0,0.1);
        }
        footer {
            background-color: #0073e6;
            color: white;
            text-align: center;
            padding: 15px 0;
            position: fixed;
            bottom: 0;
            width: 100%;
        }
    </style>
</head>
<body>

<header>
    <h1>Welcome to Vamsi DevOps Training</h1>
    <p>Empowering Future Engineers with Real-World Cloud Skills</p>
</header>

<nav>
    <a href="#">Home</a>
    <a href="#">Courses</a>
    <a href="#">Labs</a>
    <a href="#">Contact</a>
</nav>

<div class="container">
    <h2>About Us</h2>
    <p>Vamsi DevOps Training delivers hands-on, modular learning using real AWS infrastructure and open-source tools. We prepare students for real-world CI/CD, monitoring, and deployment challenges.</p>

    <div class="services">
        <div class="service-box">
            <h3>Cloud Architecture</h3>
            <p>Designing scalable, secure, and cost-optimized AWS infrastructures across multi-account setups.</p>
        </div>
        <div class="service-box">
            <h3>DevOps Bootcamp</h3>
            <p>Step-by-step training with Bitbucket, Jenkins, GitHub Actions, SonarQube, and EKS recovery strategies.</p>
        </div>
        <div class="service-box">
            <h3>CI/CD Projects</h3>
            <p>Build and troubleshoot pipelines with real error traces, rollback logic, and audit-safe workflows.</p>
        </div>
    </div>
</div>

<footer>
    <p>&copy; 2025 Vamsi DevOps Training. All rights reserved.</p>
</footer>

</body>
</html>