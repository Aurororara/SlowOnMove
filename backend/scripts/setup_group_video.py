#!/usr/bin/env python3
"""Configure a companion SFU and Django together for local/LAN testing."""
import argparse
import ipaddress
import os
from pathlib import Path
import secrets
import shutil
import subprocess
import time
from urllib.error import URLError
from urllib.request import urlopen

BACKEND = Path(__file__).resolve().parents[1]
COMPOSE = BACKEND.parent / 'deploy' / 'video' / 'compose.yaml'
ENV_FILE = BACKEND / '.env.livekit'
RUNTIME = BACKEND / '.group-video'


def configure(host):
    # Explicit IP avoids accidentally advertising a Docker-only address to phones.
    address = ipaddress.IPv4Address(host)
    if address.is_unspecified or address.is_multicast:
        raise ValueError('請提供電腦的區網 IPv4 位址，不能使用 0.0.0.0。')
    previous = {}
    if ENV_FILE.exists():
        previous = dict(
            line.split('=', 1) for line in ENV_FILE.read_text().splitlines()
            if '=' in line and not line.startswith('#')
        )
    key = previous.get('LIVEKIT_API_KEY') or 'som_' + secrets.token_hex(12)
    secret = previous.get('LIVEKIT_API_SECRET') or secrets.token_urlsafe(48)
    if not key.replace('_', '').isalnum() or not all(
        char.isalnum() or char in '-_' for char in secret
    ):
        raise ValueError('現有 .env.livekit 格式不正確，請先檢查設定。')
    RUNTIME.mkdir(mode=0o700, exist_ok=True)
    config = RUNTIME / 'livekit.yaml'
    config.write_text(
        'port: 7880\n'
        'rtc:\n'
        '  tcp_port: 7881\n'
        '  udp_port: 7882\n'
        '  use_external_ip: false\n'
        f'  node_ip: "{address}"\n'
        'room:\n'
        '  max_participants: 30\n'
        'keys:\n'
        f'  "{key}": "{secret}"\n'
    )
    config.chmod(0o600)
    ENV_FILE.write_text(
        '# Generated for local/LAN video; keep this file out of Git.\n'
        f'LIVEKIT_URL=ws://{address}:7880\n'
        f'LIVEKIT_API_KEY={key}\n'
        f'LIVEKIT_API_SECRET={secret}\n'
    )
    ENV_FILE.chmod(0o600)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--host', required=True, help='手機可連到的電腦區網 IPv4')
    parser.add_argument('--configure-only', action='store_true')
    args = parser.parse_args()
    try:
        # Fail before writing if Docker cannot start the companion service.
        if not args.configure_only:
            if shutil.which('docker') is None:
                raise RuntimeError('請先安裝並啟動 Docker Desktop。')
            subprocess.run(['docker', 'info'], check=True, capture_output=True)
            subprocess.run(['docker', 'compose', 'version'], check=True, capture_output=True)
        configure(args.host)
        if args.configure_only:
            print('Django 與視訊服務設定已產生；尚未啟動視訊服務。')
            return
        env = dict(os.environ)
        env['VIDEO_BIND_ADDRESS'] = '127.0.0.1' if args.host.startswith('127.') else '0.0.0.0'
        subprocess.run(['docker', 'compose', '-f', str(COMPOSE), 'up', '-d'],
                       env=env, check=True)
        for _ in range(30):
            try:
                with urlopen('http://127.0.0.1:7880/', timeout=1) as response:
                    if response.status == 200:
                        print('視訊服務已啟動。請重啟 Django，讓它載入 .env.livekit。')
                        print(f'手機視訊位址：ws://{args.host}:7880')
                        print('在專案根目錄重新安裝 App：')
                        print(f'flutter run --dart-define=API_BASE_URL=http://{args.host}:8000/api/')
                        return
            except (URLError, TimeoutError, OSError):
                time.sleep(0.5)
        raise RuntimeError('視訊服務尚未就緒，請用 docker compose logs 檢查啟動狀態。')
    except (ValueError, RuntimeError, subprocess.CalledProcessError) as error:
        # Do not echo environment files, config YAML or credentials.
        parser.exit(1, f'啟動失敗：{error}\n')


if __name__ == '__main__':
    main()
