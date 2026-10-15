#!/usr/bin/env python3
"""Upload/run RV32I applications or open a console using the USB-Blaster."""
import argparse
import os
from pathlib import Path
import struct
import sys
import threading
import time
import zlib

PROMPT = b'ready> '
MAX_IMAGE = 12 * 1024


class LoaderClient:
    """Protocol layer; transport supplies write(bytes) and nonblocking read()."""
    def __init__(self, transport, timeout=10.0):
        self.transport, self.timeout = transport, timeout
        self.pending = bytearray()

    def until(self, marker):
        deadline = time.monotonic() + self.timeout
        while marker not in self.pending:
            if time.monotonic() >= deadline:
                raise TimeoutError('Loader response timed out. If the CPU trapped or the upload was interrupted, press KEY(0).')
            self.pending.extend(self.transport.read())
            time.sleep(0.001)
        end = self.pending.index(marker) + len(marker)
        result = bytes(self.pending[:end])
        del self.pending[:end]
        return result

    def synchronize(self):
        # Drain an old banner/prompt before requesting a fresh response.
        deadline = time.monotonic() + 0.15
        while time.monotonic() < deadline:
            self.transport.read()
            time.sleep(0.005)
        self.pending.clear()
        self.transport.write(b'?')
        response = self.until(PROMPT)
        if b'L: upload' not in response:
            raise RuntimeError('Unexpected loader response; press KEY(0) and reconnect.')

    def upload(self, data):
        if not data or len(data) > MAX_IMAGE:
            raise ValueError('Application must contain 1..12288 bytes linked at 0x10000.')
        data += bytes((-len(data)) % 4)
        self.transport.write(b'L' + struct.pack('<II', len(data), zlib.crc32(data)))
        self.until(b'SEND\r\n')
        for offset in range(0, len(data), 32):
            self.transport.write(data[offset:offset+32])
            self.until(b'+')
        response = self.until(PROMPT)
        if b'LOADED\r\n' not in response:
            raise RuntimeError('Loader rejected the image: ' + response.decode('ascii', errors='replace'))
        return len(data)

    def run(self):
        self.transport.write(b'G')
        response = self.until(PROMPT)
        if b'ERR no image' in response:
            raise RuntimeError('No valid image is loaded.')
        return response


def console(channel):
    """Line-oriented console; one thread reads, a lock protects library calls."""
    lock = threading.Lock()
    stop = threading.Event()

    def reader():
        try:
            while not stop.is_set():
                with lock:
                    data = channel.read()
                if data:
                    sys.stdout.buffer.write(data); sys.stdout.buffer.flush()
                stop.wait(0.01)
        except Exception as error:
            print(f'\nJTAG read failed: {error}', file=sys.stderr)
            stop.set()

    thread = threading.Thread(target=reader, daemon=True)
    thread.start()
    print('JTAG console: press Enter to send a line; Ctrl+C exits. KEY(0) restarts the loader.')
    try:
        for line in sys.stdin:
            if stop.is_set(): break
            with lock:
                channel.write(line.encode('utf-8'))
    except KeyboardInterrupt:
        pass
    finally:
        stop.set(); thread.join()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cable', help='USB-Blaster cable name; auto-select when omitted')
    parser.add_argument('--device', type=int, default=-1)
    parser.add_argument('--instance', type=int, default=-1)
    parser.add_argument('--quartus-root', type=Path, help='Quartus directory containing bin64')
    parser.add_argument('--timeout', type=float, default=10.0, help='loader/program response timeout in seconds')
    sub = parser.add_subparsers(dest='action', required=True)
    sub.add_parser('console')
    upload = sub.add_parser('upload')
    upload.add_argument('binary', type=Path)
    upload.add_argument('--run', action='store_true')
    sub.add_parser('run')
    args = parser.parse_args()
    # Validate files before opening hardware. Import needs the Quartus DLLs.
    try:
        data = args.binary.read_bytes() if args.action == 'upload' else None
    except OSError as error:
        parser.error(str(error))
    if data is not None and (not data or len(data) > MAX_IMAGE):
        parser.error('Application must contain 1..12288 bytes linked at 0x10000')
    if args.timeout <= 0: parser.error('--timeout must be positive')
    if args.quartus_root:
        os.environ['QUARTUS_ROOTDIR'] = str(args.quartus_root.resolve())
    channel = None
    try:
        import intel_jtag_uart
        channel = intel_jtag_uart.intel_jtag_uart(
            cable_name=args.cable, device_nr=args.device, instance_nr=args.instance)
        if args.action == 'console':
            console(channel)
        else:
            client = LoaderClient(channel, args.timeout)
            client.synchronize()
            if data is not None:
                count = client.upload(data)
                print(f'Loaded {count} bytes at 0x10000; CRC32 verified by CPU.')
            if args.action == 'run' or args.run:
                sys.stdout.buffer.write(client.run()); sys.stdout.buffer.flush()
    except ImportError:
        parser.exit(1, 'Install host support: python -m pip install -r software/requirements.txt\n')
    except Exception as error:
        parser.exit(1, f'JTAG connection/loader error: {error}\nCheck Quartus libraries, USB-Blaster, FPGA image, and close other JTAG terminals.\n')
    finally:
        if channel is not None: channel.close()


if __name__ == '__main__':
    main()
