
# ==========================================
# Stage 1: Build Spring Boot Application
# ==========================================
FROM maven:3.9.9-eclipse-temurin-17 AS build

WORKDIR /build

# Copy Maven configuration
COPY pom.xml .

# Download dependencies
RUN mvn -B -q dependency:go-offline

# Copy application source code
COPY src ./src

# Build executable JAR
RUN mvn -B -q package -DskipTests


# ==========================================
# Stage 2: Runtime Image
# ==========================================
FROM eclipse-temurin:17-jre-alpine

# Create non-root user and certificate directory
RUN addgroup -S -g 10001 app && \
    adduser -S -u 10001 -G app -H -s /sbin/nologin app && \
    mkdir -p /app/certs && \
    wget -q -O /app/certs/global-bundle.pem \
    https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem && \
    chmod 444 /app/certs/global-bundle.pem

WORKDIR /app

# Copy executable JAR from build stage
COPY --from=build /build/target/student-service.jar /app/app.jar

# Set ownership
RUN chown -R 10001:10001 /app

# Run application as non-root user
USER 10001:10001

# Application port
EXPOSE 8080

# Docker health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=3 \
  CMD wget -q -O - http://localhost:8080/actuator/health/liveness | grep -q UP || exit 1

# Start Spring Boot application
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75", "-Djava.security.egd=file:/dev/urandom", "-jar", "/app/app.jar"]
