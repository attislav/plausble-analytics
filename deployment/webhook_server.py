#!/usr/bin/env python3
"""
GitHub Webhook Server for Plausible Analytics Auto-Deployment
Listens for GitHub push events and triggers deployment
"""

import os
import hmac
import hashlib
import subprocess
import logging
from http.server import HTTPServer, BaseHTTPRequestHandler
import json

# Configuration
WEBHOOK_SECRET = os.getenv('WEBHOOK_SECRET', 'change-me-to-a-secure-secret')
DEPLOY_SCRIPT = '/opt/plausible/deployment/deploy.sh'
PORT = 9000

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/plausible-webhook.log'),
        logging.StreamHandler()
    ]
)

class WebhookHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path != '/webhook':
            self.send_response(404)
            self.end_headers()
            return

        # Get the signature from headers
        signature = self.headers.get('X-Hub-Signature-256')
        if not signature:
            logging.warning('Missing signature header')
            self.send_response(401)
            self.end_headers()
            self.wfile.write(b'Missing signature')
            return

        # Read the payload
        content_length = int(self.headers.get('Content-Length', 0))
        payload = self.rfile.read(content_length)

        # Verify the signature
        if not self.verify_signature(payload, signature):
            logging.warning('Invalid signature')
            self.send_response(401)
            self.end_headers()
            self.wfile.write(b'Invalid signature')
            return

        # Parse the payload
        try:
            data = json.loads(payload.decode('utf-8'))
        except json.JSONDecodeError:
            logging.error('Invalid JSON payload')
            self.send_response(400)
            self.end_headers()
            self.wfile.write(b'Invalid JSON')
            return

        # Check if it's a push to master
        ref = data.get('ref', '')
        if ref != 'refs/heads/master':
            logging.info(f'Ignoring push to {ref} (not master)')
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b'Not master branch, ignoring')
            return

        # Trigger deployment
        logging.info(f'Received push to master from {data.get("pusher", {}).get("name", "unknown")}')
        self.trigger_deployment(data)

        self.send_response(200)
        self.end_headers()
        self.wfile.write(b'Deployment triggered')

    def verify_signature(self, payload, signature_header):
        """Verify the GitHub webhook signature"""
        if not signature_header.startswith('sha256='):
            return False

        expected_signature = signature_header.split('=')[1]
        secret_bytes = WEBHOOK_SECRET.encode('utf-8')
        computed_signature = hmac.new(secret_bytes, payload, hashlib.sha256).hexdigest()

        return hmac.compare_digest(computed_signature, expected_signature)

    def trigger_deployment(self, data):
        """Trigger the deployment script"""
        try:
            commit_message = data.get('head_commit', {}).get('message', 'Unknown')
            commit_sha = data.get('after', 'Unknown')[:7]

            logging.info(f'Triggering deployment for commit {commit_sha}: {commit_message}')

            # Run deployment script in background
            subprocess.Popen(
                [DEPLOY_SCRIPT],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                start_new_session=True
            )

            logging.info('Deployment script started successfully')
        except Exception as e:
            logging.error(f'Failed to trigger deployment: {str(e)}')

    def log_message(self, format, *args):
        """Override to use our logger"""
        logging.info(format % args)


def run_server():
    server_address = ('127.0.0.1', PORT)
    httpd = HTTPServer(server_address, WebhookHandler)
    logging.info(f'Starting webhook server on port {PORT}...')
    logging.info(f'Webhook endpoint: http://127.0.0.1:{PORT}/webhook')
    httpd.serve_forever()


if __name__ == '__main__':
    if WEBHOOK_SECRET == 'change-me-to-a-secure-secret':
        logging.warning('⚠️  WARNING: Using default webhook secret! Please set WEBHOOK_SECRET environment variable.')

    run_server()
