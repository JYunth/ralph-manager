#!/usr/bin/env python3
"""
Ralph Dashboard Daemon
Polls ralph.json every 5 seconds, serves dashboard on port 5000
"""

import json
import os
import time
from pathlib import Path
from datetime import datetime
from flask import Flask, jsonify, send_from_directory
from flask_cors import CORS

app = Flask(__name__, static_folder='static')
CORS(app)

# Config
RALPH_JSON = os.environ.get('RALPH_JSON', './ralph.json')
POLL_INTERVAL = 2  # seconds (faster updates)

cache = {
    'data': None,
    'last_read': 0,
    'mtime': 0
}

def load_ralph_json():
    """Load ralph.json with caching based on mtime"""
    try:
        path = Path(RALPH_JSON)
        if not path.exists():
            return None
        
        mtime = path.stat().st_mtime
        
        # Return cached if not modified
        if mtime == cache['mtime'] and cache['data'] is not None:
            return cache['data']
        
        # Load fresh
        with open(path, 'r') as f:
            data = json.load(f)
        
        cache['data'] = data
        cache['mtime'] = mtime
        cache['last_read'] = time.time()
        
        return data
    except Exception as e:
        return {'error': str(e)}

@app.route('/api/status')
def get_status():
    """API endpoint for ralph.json data"""
    return jsonify(load_ralph_json())

@app.route('/')
def index():
    """Serve dashboard"""
    return send_from_directory('static', 'index.html')

@app.route('/static/<path:path>')
def static_files(path):
    """Serve static assets"""
    return send_from_directory('static', path)

def poll_loop():
    """Background polling thread"""
    while True:
        load_ralph_json()
        time.sleep(POLL_INTERVAL)

if __name__ == '__main__':
    from threading import Thread
    
    # Start polling thread
    poll_thread = Thread(target=poll_loop, daemon=True)
    poll_thread.start()
    
    # Start server
    print(f"Ralph Dashboard: http://localhost:5000")
    print(f"Polling: {RALPH_JSON} every {POLL_INTERVAL}s")
    app.run(host='0.0.0.0', port=5000, debug=False)
