"""Run actual ENet peers in separate Godot processes, each using a temporary save.
Usage: python3 tests/run_coop_regressions.py [--capacity] [--visual] [--godot PATH]
"""
import argparse
import os
from pathlib import Path
import subprocess
import tempfile
import time

parser = argparse.ArgumentParser()
parser.add_argument('--capacity', action='store_true')
parser.add_argument('--relay', default='', help='ws(s)://host/multiplayer; empty uses ENet')
parser.add_argument('--visual', action='store_true')
parser.add_argument('--godot', default='/Users/tuotuo/Downloads/Godot.app/Contents/MacOS/Godot')
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
script = 'coop_capacity_regression.gd' if args.capacity else 'coop_network_regression.gd'
roles = ['host', 'client1', 'client2', 'client3'] if args.capacity else ['host', 'client']
failed = False
with tempfile.TemporaryDirectory(prefix='dustline-coop-') as temporary:
    prefix = str(Path(temporary) / 'session')
    # Stable per-run port with no dependency on the player's default room port.
    port = str(26000 + os.getpid() % 12000)
    peers = []
    try:
        for role in roles:
            log_path = Path(tempfile.gettempdir()) / ('dustline-coop-' + role + '.log')
            log = log_path.open('w')
            flags = ['--windowed', '--resolution', '1280x800', '--rendering-driver', 'metal', '--audio-driver', 'Dummy'] if args.visual and role == 'host' else ['--headless']
            command = [args.godot, *flags, '--log-file', str(Path(temporary) / (role + '-engine.log')), '--path', str(root), '--script', 'tests/' + script, '--', role, prefix, port, args.relay]
            process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT)
            peers.append((role, process, log, log_path))
        deadline = time.monotonic() + 300
        while any(process.poll() is None for _, process, _, _ in peers) and time.monotonic() < deadline:
            time.sleep(.25)
        for role, process, log, log_path in peers:
            if process.poll() is None:
                process.terminate()
                failed = True
            code = process.wait(timeout=10)
            log.close()
            output = log_path.read_text()
            print(f'{role}: exit {code}; log: {log_path}')
            print('\n'.join(line for line in output.splitlines() if 'COOP ' in line or 'FAIL ' in line or 'SCRIPT ERROR' in line or 'Snapshot bytes' in line))
            failed |= code != 0 or 'SCRIPT ERROR' in output or 'FAIL ' in output or 'COOP ' not in output
    finally:
        for _, process, log, _ in peers:
            if process.poll() is None:
                process.kill()
                process.wait()
            log.close()
raise SystemExit(1 if failed else 0)
