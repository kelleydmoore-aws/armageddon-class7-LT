#!/bin/bash
cloud-init clean
dnf update -y
dnf install -y python3-pip
dnf install -y mariadb105
pip3 install flask pymysql boto3
# Create project directories and static test file early
mkdir -p /opt/rdsapp/static
echo "This is a test static file for caching proof." > /opt/rdsapp/static/example.txt
chmod 644 /opt/rdsapp/static/example.txt
chown -R ec2-user:ec2-user /opt/rdsapp # Make sure Flask can read/write logs/static
mkdir -p /opt/rdsapp
cat >/opt/rdsapp/app.py <<'PY'
import json
import os
import boto3
import pymysql
import logging
import datetime
from flask import Flask, request, jsonify
# Setup logging
logging.basicConfig(
    filename='/opt/rdsapp/app.log',
    level=logging.INFO,
    format='%(asctime)s %(levelname)s %(name)s %(threadName)s : %(message)s'
)
logger = logging.getLogger(__name__)
REGION = os.environ.get("AWS_REGION", "us-east-1")
SECRET_ID = os.environ.get("SECRET_ID", "edo/rds/mysql")
secrets = boto3.client("secretsmanager", region_name=REGION)
def get_db_creds():
    try:
        resp = secrets.get_secret_value(SecretId=SECRET_ID)
        s = json.loads(resp["SecretString"])
        return s
    except Exception as e:
        logger.error(f"Failed to retrieve secret {SECRET_ID}: {str(e)}")
        raise
def get_conn():
    c = get_db_creds()
    host = c["host"]
    user = c["username"]
    password = c["password"]
    port = int(c.get("port", 3306))
    db = c.get("dbname", "labdb")
    try:
        return pymysql.connect(host=host, user=user, password=password, port=port, database=db, autocommit=True)
    except Exception as e:
        logger.error(f"DB connection failed: {str(e)}")
        raise
app = Flask(__name__)
@app.route("/")
def home():
    logger.info("Accessed home page")
    return """
    <h2>EC2 -> RDS Notes App</h2>
    <p>POST /add?note=hello</p>
    <p>GET /list</p>
    <p>GET /api/list (JSON version)</p>
    """
@app.route("/init")
def init_db():
    logger.info("Initializing database")
    c = get_db_creds()
    host = c["host"]
    user = c["username"]
    password = c["password"]
    port = int(c.get("port", 3306))
    try:
        conn = pymysql.connect(host=host, user=user, password=password, port=port, autocommit=True)
        cur = conn.cursor()
        cur.execute("CREATE DATABASE IF NOT EXISTS labdb;")
        cur.execute("USE labdb;")
        cur.execute("""
            CREATE TABLE IF NOT EXISTS notes (
                id INT AUTO_INCREMENT PRIMARY KEY,
                note VARCHAR(255) NOT NULL
            );
        """)
        cur.close()
        conn.close()
        logger.info("Database and table initialized successfully")
        return "Initialized labdb + notes table."
    except Exception as e:
        logger.error(f"DB init failed: {str(e)}")
        return f"Initialization failed: {str(e)}", 500
@app.route("/add", methods=["POST", "GET"])
def add_note():
    note = request.args.get("note", "").strip()
    if not note:
        logger.warning("Add note requested without 'note' parameter")
        return "Missing note param. Try: /add?note=hello", 400
    try:
        conn = get_conn()
        cur = conn.cursor()
        cur.execute("INSERT INTO notes(note) VALUES(%s);", (note,))
        cur.close()
        conn.close()
        logger.info(f"Inserted note: {note}")
        return f"Inserted note: {note}"
    except Exception as e:
        logger.error(f"Add note failed: {str(e)}")
        return f"Insert failed: {str(e)}", 500
@app.route("/list")
def list_notes():
    logger.info("Listing notes")
    try:
        conn = get_conn()
        cur = conn.cursor()
        cur.execute("SELECT id, note FROM notes ORDER BY id DESC;")
        rows = cur.fetchall()
        cur.close()
        conn.close()
        out = "<h3>Notes</h3><ul>"
        for r in rows:
            out += f"<li>{r[0]}: {r[1]}</li>"
        out += "</ul>"
        if not rows:
            out = "No notes yet."
            logger.info("No notes found")
        else:
            logger.info(f"Retrieved {len(rows)} notes")
        return out
    except Exception as e:
        logger.error(f"List notes failed: {str(e)}")
        return f"Cannot list notes: {str(e)}", 500
# New JSON API endpoint for /api/list
@app.route("/api/list")
def api_list():
    logger.info("API /api/list accessed")
    try:
        conn = get_conn()
        cur = conn.cursor()
        cur.execute("SELECT id, note FROM notes ORDER BY id DESC;")
        rows = cur.fetchall()
        cur.close()
        conn.close()
        return jsonify([{"id": r[0], "note": r[1]} for r in rows])
    except Exception as e:
        logger.error(f"API list failed: {str(e)}")
        return jsonify({"error": str(e)}), 500
@app.route('/api/public-feed')
def public_feed():
    now = datetime.datetime.utcnow().isoformat() + 'Z'
    minute = datetime.datetime.utcnow().minute
    message = f"Message of the minute: {minute:02d} - Fresh from origin at request time!"
    data = {
        "server_time_utc": now,
        "message_of_the_minute": message,
        "note": "This should be cached by CloudFront for 30 seconds (s-maxage=30)"
    }
    response = jsonify(data)
    response.headers['Cache-Control'] = 'public, s-maxage=30, max-age=0'
    logger.info(f"Public feed served: {now}")
    return response
@app.route('/api/private-feed')
def private_feed():
    now = datetime.datetime.utcnow().isoformat() + 'Z'
    data = {
        "server_time_utc": now,
        "message": "Always fresh - never cached"
    }
    response = jsonify(data)
    logger.info(f"Private feed served: {now}")
    return response
# Define private paths that should NEVER be cached
PRIVATE_PATHS = {
    '/api/list',
    '/list',
    '/add',
    '/api/private-feed',
}
@app.after_request
def add_no_cache_headers(response):
    if request.path in PRIVATE_PATHS:
        response.headers['Cache-Control'] = 'private, no-store'
        response.headers['Pragma'] = 'no-cache'
        response.headers['Expires'] = '0'
    return response
if __name__ == "__main__":
    logger.info("Starting Flask app")
    app.run(host="0.0.0.0", port=80)
PY
cat >/etc/systemd/system/rdsapp.service <<'SERVICE'
[Unit]
Description=EC2 to RDS Notes App
After=network.target
[Service]
WorkingDirectory=/opt/rdsapp
Environment=SECRET_ID=edo/rds/mysql
ExecStart=/usr/bin/python3 /opt/rdsapp/app.py
Restart=always
[Install]
WantedBy=multi-user.target
SERVICE
systemctl daemon-reload
systemctl enable rdsapp
systemctl start rdsapp
=== ADD CLOUDWATCH AGENT BELOW THIS LINE ===
# Install unified CloudWatch Agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent-us-east-1/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
rpm -U ./amazon-cloudwatch-agent.rpm
# Create config directory if needed
mkdir -p /opt/aws/amazon-cloudwatch-agent/bin
cat >/opt/aws/amazon-cloudwatch-agent/bin/config.json <<'EOF'
{
  "agent": {
    "run_as_user": "cwagent"
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/opt/rdsapp/*.log",
            "log_group_name": "/aws/ec2/edo-rds-app",
            "log_stream_name": "{instance_id}"
          }
        ]
      }
    }
  }
}
EOF
# Start the agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
-a fetch-config -m ec2 \
-c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json -s
# Test log
logger "RDS App and CloudWatch Agent started successfully $(date)"