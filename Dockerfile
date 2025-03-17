# Use the specified Gradle image with Java 11
FROM gradle:7.6.1-jdk11

# Set working directory
WORKDIR /app

# Copy all project files into the container
COPY . .

# Stop any running Gradle daemons
RUN gradle --stop

# Configure Gradle to run in daemon mode and not expect key presses
ENV GRADLE_OPTS="-Dorg.gradle.daemon=false"

# Run the application in non-interactive mode
CMD ["./gradlew", "appRun", "--no-daemon", "--console=plain"]

###################### IMPORTANT ##########################
# COMMANDS
# docker build -t ensf-400-project .
# docker run -p 8080:8080 -i ensf-400-project