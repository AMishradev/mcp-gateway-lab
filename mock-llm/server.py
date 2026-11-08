"""Fake Anthropic Messages API so Kong's ai-proxy plugin can be practised at $0.

Answers POST /v1/messages with a canned reply and a realistic `usage` block, so Kong's token logging works.
"""
import json
from http.server import BaseHTTPRequestHandler, HTTPServer


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        body = json.loads(self.rfile.read(int(self.headers.get("Content-Length", 0))) or b"{}")
        last = next((m for m in reversed(body.get("messages", [])) if m.get("role") == "user"), {})
        text = last.get("content") if isinstance(last.get("content"), str) else json.dumps(last.get("content"))
        reply = f"(mock model) you said: {str(text)[:200]}"
        out = {"id": "msg_mock", "type": "message", "role": "assistant", "model": body.get("model", "mock"),
               "content": [{"type": "text", "text": reply}], "stop_reason": "end_turn",
               "usage": {"input_tokens": max(1, len(json.dumps(body)) // 4), "output_tokens": max(1, len(reply) // 4)}}
        data = json.dumps(out).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, fmt, *args):  # quiet
        pass


if __name__ == "__main__":
    HTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
