# Use a lightweight, official Python base image
FROM python:3.11-slim

# Set environment variables to ensure Python output is logged directly and no bytecode is written
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Set the working directory inside the container
WORKDIR /app

# Create a non-root user and group for enhanced container security
RUN groupadd -g 1000 appgroup && \
    useradd -u 1000 -g appgroup -s /bin/sh -m appuser

# Copy requirements first to leverage Docker build layer caching
COPY app/requirements.txt /app/requirements.txt

# Install dependencies without saving pip cache to keep image minimal
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the application files into the container
COPY app/ /app/

# Set correct ownership of the application directory to the non-root user
RUN chown -R appuser:appgroup /app

# Switch to the non-root user for execution
USER appuser

# Expose the application port
EXPOSE 5000

# Production-appropriate startup command using Gunicorn WSGI server
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "app:app"]
