"""Fetch only Godot Web templates from the official large TPZ using HTTP ranges."""
from __future__ import annotations

import os
import struct
import urllib.request
import zlib
from pathlib import Path

URL = "https://github.com/godotengine/godot-builds/releases/download/4.7.1-stable/Godot_v4.7.1-stable_export_templates.tpz"
TARGET = Path(os.environ["APPDATA"]) / "Godot" / "export_templates" / "4.7.1.stable"


def request_range(start: int, end: int) -> bytes:
    req = urllib.request.Request(URL, headers={"Range": f"bytes={start}-{end}", "User-Agent": "SkyforgeRunner/1.0"})
    with urllib.request.urlopen(req, timeout=120) as response:
        return response.read()


def content_length() -> int:
    req = urllib.request.Request(URL, method="HEAD", headers={"User-Agent": "SkyforgeRunner/1.0"})
    with urllib.request.urlopen(req, timeout=60) as response:
        return int(response.headers["Content-Length"])


def main() -> None:
    total = content_length()
    tail_size = min(total, 1024 * 1024)
    tail = request_range(total - tail_size, total - 1)
    eocd_pos = tail.rfind(b"PK\x05\x06")
    if eocd_pos < 0:
        raise RuntimeError("ZIP end-of-central-directory was not found")
    _, _, _, _, _, cd_size, cd_offset, _ = struct.unpack_from("<4s4H2IH", tail, eocd_pos)
    central = request_range(cd_offset, cd_offset + cd_size - 1)
    entries: list[tuple[str, int, int, int]] = []
    pos = 0
    while pos + 46 <= len(central) and central[pos : pos + 4] == b"PK\x01\x02":
        values = struct.unpack_from("<4s6H3I5H2I", central, pos)
        method = values[4]
        compressed_size = values[8]
        name_len, extra_len, comment_len = values[10], values[11], values[12]
        local_offset = values[16]
        name = central[pos + 46 : pos + 46 + name_len].decode("utf-8")
        entries.append((name, method, compressed_size, local_offset))
        pos += 46 + name_len + extra_len + comment_len

    web_names = ("web_release.zip", "web_debug.zip", "web_nothreads_release.zip", "web_nothreads_debug.zip", "version.txt")
    wanted = [entry for entry in entries if entry[0].endswith(web_names)]
    if not any(name.endswith("web_nothreads_release.zip") for name, *_ in wanted):
        raise RuntimeError("web_nothreads_release.zip was not found in template package")
    TARGET.mkdir(parents=True, exist_ok=True)
    for name, method, compressed_size, local_offset in wanted:
        header = request_range(local_offset, local_offset + 29)
        if header[:4] != b"PK\x03\x04":
            raise RuntimeError(f"Invalid local header for {name}")
        _, _, _, _, _, _, _, _, _, name_len, extra_len = struct.unpack("<4s5H3I2H", header)
        data_start = local_offset + 30 + name_len + extra_len
        compressed = request_range(data_start, data_start + compressed_size - 1)
        if method == 0:
            payload = compressed
        elif method == 8:
            payload = zlib.decompress(compressed, -zlib.MAX_WBITS)
        else:
            raise RuntimeError(f"Unsupported ZIP method {method} for {name}")
        destination = TARGET / Path(name).name
        destination.write_bytes(payload)
        print(f"Installed {destination.name}: {len(payload):,} bytes")
    print(f"Web templates ready at {TARGET}")


if __name__ == "__main__":
    main()
