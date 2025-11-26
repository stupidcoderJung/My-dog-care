from http.server import HTTPServer, BaseHTTPRequestHandler
import json

class SimpleHTTPRequestHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path == '/events/batch':
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length)
            
            try:
                data = json.loads(post_data)
                if isinstance(data, list):
                    print(f"📦 Received batch of {len(data)} packets")
                    if len(data) > 0:
                        first = data[0]
                        print(f"   - Timestamp: {first.get('timestamp')}")
                        print(f"   - Dogs: {len(first.get('dogs', []))}")
                else:
                    print("⚠️ Received non-list data")
                
                response = {"inserted": len(data) if isinstance(data, list) else 0}
                self.send_response(200)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps(response).encode('utf-8'))
                
            except json.JSONDecodeError:
                print("❌ Failed to decode JSON")
                self.send_response(400)
                self.end_headers()
        else:
            self.send_response(404)
            self.end_headers()

    def do_GET(self):
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"Mock Backend Running")

if __name__ == '__main__':
    print("🚀 Mock Backend running on http://0.0.0.0:8001")
    httpd = HTTPServer(('0.0.0.0', 8001), SimpleHTTPRequestHandler)
    httpd.serve_forever()
