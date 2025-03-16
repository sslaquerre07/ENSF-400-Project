# Use the specified Gradle image with Java 11
FROM gradle:7.6.1-jdk11

# Set working directory
WORKDIR /app

# Copy all project files into the container
COPY . .

RUN gradle --stop

CMD ["./gradlew", "apprun"]
