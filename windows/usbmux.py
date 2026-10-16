"""
CarrierLock - USBMux and Lockdown communication client for Windows
"""

import socket
import struct
import plistlib
import os
import sys
import ssl

USBMUX_PORT = 27015
LOCKDOWN_PORT = 62078
LOCKDOWN_DIR = r"C:\ProgramData\Apple\Lockdown"

def get_pairing_record(udid: str) -> dict | None:
    path = os.path.join(LOCKDOWN_DIR, f"{udid}.plist")
    if os.path.isfile(path):
        try:
            with open(path, "rb") as f:
                return plistlib.load(f)
        except Exception:
            return None
    return None

def find_paired_udids() -> list[str]:
    udids = []
    if os.path.isdir(LOCKDOWN_DIR):
        for name in os.listdir(LOCKDOWN_DIR):
            if name.endswith(".plist") and not name.startswith("SystemConfiguration"):
                udids.append(name[:-6])
    return udids

class UsbmuxClient:
    def __init__(self, host="127.0.0.1", port=USBMUX_PORT):
        self.host = host
        self.port = port
        self.sock = None
        self.tag = 1

    def connect(self):
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.sock.settimeout(5.0)
        self.sock.connect((self.host, self.port))

    def close(self):
        if self.sock:
            try:
                self.sock.close()
            except Exception:
                pass
            self.sock = None

    def send_packet(self, req: dict):
        payload = plistlib.dumps(req)
        header = struct.pack("<IIII", 16 + len(payload), 1, 8, self.tag)
        self.tag += 1
        self.sock.sendall(header + payload)

    def recv_packet(self) -> dict:
        header = self.sock.recv(16)
        if len(header) < 16:
            raise ConnectionError("Short usbmux header")
        length, version, req_type, tag = struct.unpack("<IIII", header)
        payload = b""
        remaining = length - 16
        while remaining > 0:
            chunk = self.sock.recv(min(remaining, 4096))
            if not chunk:
                break
            payload += chunk
            remaining -= len(chunk)
        return plistlib.loads(payload)

    def list_devices(self) -> list[dict]:
        self.connect()
        try:
            req = {
                "MessageType": "Listen",
                "ClientVersionString": "CarrierLock-Windows",
                "ProgName": "CarrierLock",
            }
            self.send_packet(req)
            resp = self.recv_packet()
            devices = []
            self.sock.settimeout(0.5)
            while True:
                try:
                    event = self.recv_packet()
                    if event.get("MessageType") == "Attached":
                        devices.append(event.get("Properties", {}))
                except (socket.timeout, ConnectionError):
                    break
            return devices
        finally:
            self.close()

    def connect_device_port(self, device_id: int, port: int) -> socket.socket:
        self.connect()
        # port in usbmux is big-endian htons
        port_be = ((port << 8) & 0xFF00) | ((port >> 8) & 0x00FF)
        req = {
            "MessageType": "Connect",
            "ClientVersionString": "CarrierLock-Windows",
            "ProgName": "CarrierLock",
            "DeviceID": device_id,
            "PortNumber": port_be,
        }
        self.send_packet(req)
        resp = self.recv_packet()
        if resp.get("Number") != 0:
            self.close()
            raise ConnectionError(f"usbmux connect failed with code {resp.get('Number')}")
        s = self.sock
        self.sock = None
        return s
