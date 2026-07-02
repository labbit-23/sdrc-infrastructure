#!/usr/bin/env python3
"""
SDRC Infrastructure: Sophos Firewall Management API
Runs on local machine only. Exposes Sophos restart endpoint.
Works even when WANs are down (for local admin emergency restart).
"""

from flask import Flask, jsonify
import os
import logging
import paramiko
import socket
from datetime import datetime, timezone

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def utc_now_iso():
    return datetime.now(timezone.utc).isoformat()

def restart_sophos_firewall(host, username, password, timeout=10):
    """SSH into Sophos and execute reboot command."""
    try:
        client = paramiko.SSHClient()
        client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        client.connect(host, username=username, password=password, timeout=timeout,
                      look_for_keys=False, allow_agent=False)

        stdin, stdout, stderr = client.exec_command("reboot")
        stdout.channel.recv_exit_status()
        client.close()

        return {
            "status": "success",
            "message": f"Reboot command sent to {host}",
            "timestamp": utc_now_iso()
        }
    except paramiko.AuthenticationException:
        return {"status": "error", "message": "SSH authentication failed"}
    except paramiko.SSHException as e:
        return {"status": "error", "message": f"SSH error: {str(e)[:100]}"}
    except socket.timeout:
        return {"status": "error", "message": f"SSH timeout after {timeout}s"}
    except Exception as e:
        return {"status": "error", "message": f"SSH restart failed: {str(e)[:100]}"}

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint."""
    return jsonify({"status": "ok", "timestamp": utc_now_iso()}), 200

@app.route('/api/infrastructure/sophos/restart', methods=['POST'])
def restart_sophos():
    """
    Restart Sophos firewall via SSH.
    Only accessible on local machine (192.168.134.185 / Tailscale 100.65.63.54).
    Use case: Emergency firewall restart when WANs are down.
    """
    host = os.environ.get("SOPHOS_SSH_HOST", "192.168.134.1").strip()
    username = os.environ.get("SOPHOS_SSH_USER", "").strip()
    password = os.environ.get("SOPHOS_SSH_PASSWORD", "").strip()

    if not username or not password:
        logger.error("Sophos SSH credentials not configured")
        return jsonify({
            "status": "error",
            "message": "SSH credentials not configured"
        }), 500

    try:
        logger.info(f"Sophos restart requested for {host}")
        result = restart_sophos_firewall(host, username, password, timeout=10)

        if result["status"] == "success":
            logger.info(f"Sophos restart successful: {result['message']}")
            return jsonify({
                "status": "success",
                "message": result["message"],
                "timestamp": result["timestamp"]
            }), 200
        else:
            logger.error(f"Sophos restart failed: {result['message']}")
            return jsonify({
                "status": "error",
                "message": result["message"]
            }), 500
    except Exception as exc:
        error_msg = f"Restart error: {str(exc)[:100]}"
        logger.error(error_msg)
        return jsonify({
            "status": "error",
            "message": error_msg
        }), 500

if __name__ == '__main__':
    # Run on local machine
    # Accessible via: http://192.168.134.185:5001 (LAN) or http://100.65.63.54:5001 (Tailscale)
    port = int(os.environ.get("SOPHOS_API_PORT", "5001"))
    debug = os.environ.get("SOPHOS_API_DEBUG", "0").lower() in {"1", "true", "yes"}

    logger.info(f"Starting Sophos API on port {port}")
    app.run(host='0.0.0.0', port=port, debug=debug)
