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

def get_live_device_info() -> dict | None:
    """
    Connects to live USB iPhone via usbmuxd and queries real-time hardware,
    device, and dual-SIM CarrierBundleInfoArray info over SSL lockdown.
    Returns None if no device is physically attached via USB.
    """
    client = UsbmuxClient()
    try:
        devices = client.list_devices()
    except Exception:
        return None

    if not devices:
        return None

    dev = devices[0]
    udid = dev.get("SerialNumber")
    device_id = dev.get("DeviceID")
    if not udid or not device_id:
        return None

    rec = get_pairing_record(udid)
    if not rec:
        return {
            "connected": True,
            "paired": False,
            "udid": udid,
            "device_name": "未配对设备（请在手机上点击信任此电脑）",
            "sim1": {},
            "sim2": {}
        }

    s = None
    ssl_s = None
    try:
        s = client.connect_device_port(device_id, LOCKDOWN_PORT)

        def send_recv(sock, req):
            payload = plistlib.dumps(req)
            sock.sendall(struct.pack('>I', len(payload)) + payload)
            hdr = sock.recv(4)
            if len(hdr) < 4:
                return None
            resp_len = struct.unpack('>I', hdr)[0]
            data = b''
            while len(data) < resp_len:
                chunk = sock.recv(min(4096, resp_len - len(data)))
                if not chunk:
                    break
                data += chunk
            return plistlib.loads(data)

        # Start Lockdown Session
        resp = send_recv(s, {
            'Request': 'StartSession',
            'HostID': rec['HostID'],
            'SystemBUID': rec.get('SystemBUID', '')
        })

        if not resp or not resp.get('EnableSessionSSL'):
            return {
                "connected": True,
                "paired": False,
                "udid": udid,
                "device_name": "需要解锁并信任此电脑",
                "sim1": {},
                "sim2": {}
            }

        # Wrap SSL
        import tempfile
        with tempfile.NamedTemporaryFile('wb', delete=False) as cert_f, tempfile.NamedTemporaryFile('wb', delete=False) as key_f:
            cert_f.write(rec['HostCertificate'])
            key_f.write(rec['HostPrivateKey'])
            cert_path = cert_f.name
            key_path = key_f.name

        try:
            ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
            ctx.check_hostname = False
            ctx.verify_mode = ssl.CERT_NONE
            ctx.load_cert_chain(certfile=cert_path, keyfile=key_path)
            ssl_s = ctx.wrap_socket(s)
        finally:
            try:
                os.unlink(cert_path)
                os.unlink(key_path)
            except Exception:
                pass

        # Query all live root properties
        root_val = send_recv(ssl_s, {'Request': 'GetValue'}).get('Value', {})

        device_name = root_val.get('DeviceName', 'iPhone')
        product_type = root_val.get('ProductType', 'iPhone')
        product_version = root_val.get('ProductVersion', '')
        build_version = root_val.get('BuildVersion', '')

        carrier_arr = root_val.get('CarrierBundleInfoArray', [])
        sim1 = {}
        sim2 = {}

        for item in carrier_arr:
            slot = item.get('Slot', '')
            if slot == 'kOne':
                sim1 = {
                    'imsi': item.get('InternationalMobileSubscriberIdentity', ''),
                    'iccid': item.get('IntegratedCircuitCardIdentity', ''),
                    'mcc': item.get('MCC', ''),
                    'mnc': item.get('MNC', ''),
                    'bundle_id': item.get('CFBundleIdentifier', ''),
                    'bundle_version': item.get('CFBundleVersion', ''),
                }
            elif slot == 'kTwo':
                sim2 = {
                    'imsi': item.get('InternationalMobileSubscriberIdentity', ''),
                    'iccid': item.get('IntegratedCircuitCardIdentity', ''),
                    'mcc': item.get('MCC', ''),
                    'mnc': item.get('MNC', ''),
                    'bundle_id': item.get('CFBundleIdentifier', ''),
                    'bundle_version': item.get('CFBundleVersion', ''),
                }

        # Fallback for single SIM or direct keys
        if not sim1.get('imsi') and root_val.get('InternationalMobileSubscriberIdentity'):
            sim1['imsi'] = root_val.get('InternationalMobileSubscriberIdentity')
        if not sim2.get('imsi') and root_val.get('InternationalMobileSubscriberIdentity2'):
            sim2['imsi'] = root_val.get('InternationalMobileSubscriberIdentity2')

        return {
            "connected": True,
            "paired": True,
            "udid": udid,
            "device_name": device_name,
            "product_type": product_type,
            "product_version": product_version,
            "build_version": build_version,
            "sim1": sim1,
            "sim2": sim2
        }
    except Exception as e:
        return {
            "connected": True,
            "paired": True,
            "udid": udid,
            "error": str(e),
            "sim1": {},
            "sim2": {}
        }
    finally:
        if ssl_s:
            try:
                ssl_s.close()
            except Exception:
                pass
        elif s:
            try:
                s.close()
            except Exception:
                pass

