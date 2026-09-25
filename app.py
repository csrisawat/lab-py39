import os
import sys
import time
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse

try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass

PORT = int(os.environ.get("PORT", 3000))
APP_NAME = os.environ.get("APP_NAME", "lab-py39")
DB_HOST = os.environ.get("DB_HOST", "localhost")
DB_PASSWORD = os.environ.get("DB_PASSWORD", "")
API_KEY = os.environ.get("API_KEY", "")

START_TIME = time.time()


def masked_secret(val):
    if val:
        return "***" + val[-4:]
    return "(not set)"


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        path = urlparse(self.path).path

        if path == "/health":
            body = f'{{"status":"ok","uptime":{time.time() - START_TIME:.2f}}}'
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(body.encode())
            return

        python_version = sys.version.split()[0]
        html = f"""
<h1>Hello World from {APP_NAME}!</h1>
<p>Python {python_version} running on port {PORT}</p>
<hr>
<h3>Environment Config</h3>
<ul>
  <li><b>APP_NAME:</b> {APP_NAME}</li>
  <li><b>DB_HOST:</b> {DB_HOST}</li>
  <li><b>DB_PASSWORD:</b> {masked_secret(DB_PASSWORD)}</li>
  <li><b>API_KEY:</b> {masked_secret(API_KEY)}</li>
</ul>
"""
        self.send_response(200)
        self.send_header("Content-Type", "text/html")
        self.end_headers()
        self.wfile.write(html.encode())

    def log_message(self, fmt, *args):
        print(f"[{APP_NAME}] {fmt % args}")


if __name__ == "__main__":
    print(f"[{APP_NAME}] Server running on port {PORT}")
    print(f"  Python  = {sys.version.split()[0]}")
    print(f"  DB_HOST = {DB_HOST}")
    print(f"  DB_PASSWORD = {masked_secret(DB_PASSWORD)}")
    print(f"  API_KEY = {masked_secret(API_KEY)}")

    server = HTTPServer(("0.0.0.0", PORT), Handler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print(f"\n[{APP_NAME}] Shutting down.")
        server.server_close()
