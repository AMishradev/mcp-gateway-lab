FROM python:3.13-slim
# Pinned so the lab behaves the same next month.
RUN pip install --no-cache-dir fastmcp==4.1.6
RUN useradd --create-home --uid 10001 app
WORKDIR /app
COPY server.py .
# Never run the MCP process as root (best-practice: BP-NON-ROOT).
USER app
EXPOSE 8000
CMD ["python", "server.py"]
