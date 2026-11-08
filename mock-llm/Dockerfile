FROM python:3.13-slim
RUN useradd --create-home --uid 10001 app
WORKDIR /app
COPY server.py .
USER app
EXPOSE 8080
CMD ["python", "server.py"]
