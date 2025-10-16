# Use stable Tomcat 9 with JDK 17
FROM tomcat:9.0.82-jdk17-temurin

# Set maintainer label (modern syntax)
LABEL maintainer="bvamsi1232@gmail.com"

# Clean default webapps (optional for clarity)
RUN rm -rf /usr/local/tomcat/webapps/*

# Copy your WAR file into Tomcat's ROOT context
COPY ./webapp.war /usr/local/tomcat/webapps/ROOT.war