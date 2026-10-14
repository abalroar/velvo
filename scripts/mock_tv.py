#!/usr/bin/env python3
"""Simulated Android TV Remote Service, for testing the app without a TV.

Speaks the same protocol as a real Android TV: pairing (polo) on --pair-port and the remote
protocol on --port, both TLS with a client certificate. Uses only the standard library and the
`openssl` command.

    python3 scripts/mock_tv.py --client-cert client.pem --code-file code.txt --log events.jsonl

--client-cert is the Mac's certificate (export it with `PhilipsTVMenubar --export-client-cert`).
The pairing code is printed and, with --code-file, written to that file.
"""
from __future__ import annotations

import argparse
import asyncio
import hashlib
import json
import secrets
import ssl
import subprocess
import tempfile
from pathlib import Path

FEATURES = 1 | 2 | 4 | 32 | 64 | 512
KEY_NAMES = {3: "HOME", 4: "BACK", 19: "DPAD_UP", 20: "DPAD_DOWN", 21: "DPAD_LEFT", 22: "DPAD_RIGHT",
             23: "DPAD_CENTER", 24: "VOLUME_UP", 25: "VOLUME_DOWN", 26: "POWER", 164: "VOLUME_MUTE",
             85: "MEDIA_PLAY_PAUSE", 178: "TV_INPUT", 243: "TV_INPUT_HDMI_1", 244: "TV_INPUT_HDMI_2"}
LAUNCHER = "com.google.android.tvlauncher"


# --- protobuf wire format -------------------------------------------------------------------

def varint(value: int) -> bytes:
    value &= (1 << 64) - 1
    out = bytearray()
    while value >= 0x80:
        out.append(value & 0x7F | 0x80)
        value >>= 7
    out.append(value)
    return bytes(out)


def read_varint(data: bytes, pos: int) -> tuple[int, int] | None:
    result = shift = 0
    while pos < len(data):
        byte = data[pos]
        result |= (byte & 0x7F) << shift
        pos += 1
        if not byte & 0x80:
            return result, pos
        shift += 7
    return None


def f_int(field: int, value: int) -> bytes:
    return varint(field << 3) + varint(value)


def f_bytes(field: int, value: bytes | str) -> bytes:
    if isinstance(value, str):
        value = value.encode()
    return varint(field << 3 | 2) + varint(len(value)) + value


def parse(data: bytes) -> dict[int, list]:
    fields: dict[int, list] = {}
    pos = 0
    while pos < len(data):
        key, pos = read_varint(data, pos)
        field, wire = key >> 3, key & 7
        if wire == 0:
            value, pos = read_varint(data, pos)
        elif wire == 2:
            length, pos = read_varint(data, pos)
            value, pos = data[pos:pos + length], pos + length
        else:
            raise ValueError(f"unsupported wire type {wire}")
        fields.setdefault(field, []).append(value)
    return fields


def first(fields: dict[int, list], field: int, default=None):
    return fields[field][-1] if field in fields else default


class Framed:
    """Varint length-prefixed messages over an asyncio stream."""

    def __init__(self, reader: asyncio.StreamReader, writer: asyncio.StreamWriter):
        self.reader, self.writer, self.buffer = reader, writer, b""

    async def read(self) -> bytes | None:
        while True:
            header = read_varint(self.buffer, 0)
            if header and len(self.buffer) >= header[1] + header[0]:
                length, start = header
                message, self.buffer = self.buffer[start:start + length], self.buffer[start + length:]
                return message
            chunk = await self.reader.read(65536)
            if not chunk:
                return None
            self.buffer += chunk

    def send(self, message: bytes) -> None:
        self.writer.write(varint(len(message)) + message)


# --- TV --------------------------------------------------------------------------------------

def modulus(cert: Path) -> bytes:
    out = subprocess.run(["openssl", "x509", "-noout", "-modulus", "-in", str(cert)], check=True, capture_output=True, text=True).stdout
    return bytes.fromhex(out.strip().split("=", 1)[1]).lstrip(b"\x00")


class MockTV:
    def __init__(self, args: argparse.Namespace):
        self.args = args
        self.workdir = Path(tempfile.mkdtemp(prefix="mock-tv-"))
        self.cert, self.key = self.workdir / "server.pem", self.workdir / "server.key"
        subprocess.run(["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-keyout", str(self.key),
                        "-out", str(self.cert), "-days", "30", "-subj", "/CN=MockTV"], check=True, capture_output=True)
        self.client_modulus = modulus(Path(args.client_cert))
        self.server_modulus = modulus(self.cert)
        self.volume, self.muted, self.app, self.on = 12, False, LAUNCHER, True
        self.expected_secret: bytes | None = None

    def context(self) -> ssl.SSLContext:
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.load_cert_chain(self.cert, self.key)
        context.verify_mode = ssl.CERT_REQUIRED
        context.load_verify_locations(self.args.client_cert)
        return context

    def log(self, event: str, **data) -> None:
        line = json.dumps({"event": event, **data})
        print(line, flush=True)
        if self.args.log:
            with open(self.args.log, "a") as fp:
                fp.write(line + "\n")

    # Pairing: request -> options -> configuration -> (code on screen) -> secret

    @staticmethod
    def outer(body: bytes, status: int = 200) -> bytes:
        return f_int(1, 2) + f_int(2, status) + body

    async def pairing(self, reader, writer) -> None:
        link = Framed(reader, writer)
        self.log("pairing_connected")
        while (raw := await link.read()) is not None:
            message = parse(raw)
            if 10 in message:
                request = parse(first(message, 10))
                self.log("pairing_request", client=first(request, 2, b"").decode(), service=first(request, 1, b"").decode())
                link.send(self.outer(f_bytes(11, f_bytes(1, "MockTV"))))
            elif 20 in message:
                link.send(self.outer(f_bytes(20, f_bytes(1, f_int(1, 3) + f_int(2, 6)) + f_int(3, 1))))
            elif 30 in message:
                nonce = secrets.token_bytes(2)
                exponent = bytes([1, 0, 1])
                digest = hashlib.sha256(self.client_modulus + exponent + self.server_modulus + exponent + nonce).digest()
                self.expected_secret = digest
                code = f"{digest[0]:02X}{nonce.hex().upper()}"
                self.log("pairing_code", code=code)
                if self.args.code_file:
                    Path(self.args.code_file).write_text(code)
                link.send(self.outer(f_bytes(31, b"")))
            elif 40 in message:
                secret = first(parse(first(message, 40)), 1, b"")
                if secret == self.expected_secret:
                    self.log("paired")
                    link.send(self.outer(f_bytes(41, f_bytes(1, secret))))
                else:
                    self.log("pairing_bad_secret")
                    link.send(self.outer(b"", status=402))
            await writer.drain()
        writer.close()

    # Remote: configure -> set active -> start, app, volume; pings every 5 s

    def volume_message(self) -> bytes:
        return f_bytes(50, f_int(6, 100) + f_int(7, self.volume) + f_int(8, int(self.muted)))

    def app_message(self) -> bytes:
        return f_bytes(20, f_bytes(1, f_bytes(12, self.app)))

    async def remote(self, reader, writer) -> None:
        link = Framed(reader, writer)
        self.log("remote_connected")
        link.send(f_bytes(1, f_int(1, FEATURES) + f_bytes(2, f_bytes(1, "MockTV") + f_bytes(2, "Philips") + f_bytes(6, "5.0"))))
        await writer.drain()

        async def ping() -> None:
            n = 0
            while True:
                await asyncio.sleep(5)
                n += 1
                link.send(f_bytes(8, f_int(1, n) + f_int(2, n)))
                await writer.drain()

        pinger = asyncio.create_task(ping())
        try:
            while (raw := await link.read()) is not None:
                message = parse(raw)
                if 1 in message:
                    features = first(parse(first(message, 1)), 1, 0)
                    self.log("configured", features=features)
                    link.send(f_bytes(2, b""))
                elif 2 in message:
                    self.log("active", features=first(parse(first(message, 2)), 1, 0))
                    link.send(f_bytes(40, f_int(1, int(self.on))))
                    link.send(self.app_message())
                    link.send(self.volume_message())
                elif 9 in message:
                    self.log("pong", value=first(parse(first(message, 9)), 1, 0))
                elif 10 in message:
                    inject = parse(first(message, 10))
                    code = first(inject, 1, 0)
                    self.log("key", code=code, name=KEY_NAMES.get(code, str(code)), direction=first(inject, 2, 0))
                    self.apply_key(link, code)
                elif 90 in message:
                    app_link = first(parse(first(message, 90)), 1, b"").decode()
                    self.log("app_link", link=app_link)
                    if "id=" in app_link:
                        self.app = app_link.split("id=", 1)[1]
                        link.send(self.app_message())
                elif 21 in message:
                    edit = parse(first(message, 21))
                    info = parse(first(edit, 3, b""))
                    text = first(parse(first(info, 2, b"")), 3, b"").decode()
                    self.log("text", text=text, ime_counter=first(edit, 1, 0), field_counter=first(edit, 2, 0))
                await writer.drain()
        finally:
            pinger.cancel()
            writer.close()
            self.log("remote_closed")

    def apply_key(self, link: Framed, code: int) -> None:
        if code in (24, 25):
            self.volume = max(0, min(100, self.volume + (1 if code == 24 else -1)))
            link.send(self.volume_message())
        elif code == 164:
            self.muted = not self.muted
            link.send(self.volume_message())
        elif code == 3:
            self.app = LAUNCHER
            link.send(self.app_message())
        elif code == 26:
            self.on = not self.on
            link.send(f_bytes(40, f_int(1, int(self.on))))

    async def serve(self) -> None:
        context = self.context()
        pairing = await asyncio.start_server(self.pairing, self.args.bind, self.args.pair_port, ssl=context)
        remote = await asyncio.start_server(self.remote, self.args.bind, self.args.port, ssl=context)
        self.log("listening", pair_port=self.args.pair_port, port=self.args.port)
        async with pairing, remote:
            await asyncio.gather(pairing.serve_forever(), remote.serve_forever())


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--client-cert", required=True, help="PEM certificate of the client allowed to connect")
    parser.add_argument("--bind", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=6466)
    parser.add_argument("--pair-port", type=int, default=6467)
    parser.add_argument("--code-file")
    parser.add_argument("--log")
    asyncio.run(MockTV(parser.parse_args()).serve())


if __name__ == "__main__":
    main()
