#!/usr/bin/env python3
"""Exercise the upload client against an independent, fragmented protocol peer."""
import struct
import unittest
import zlib
from jtag_console import LoaderClient, MAX_IMAGE, PROMPT


class Peer:
    def __init__(self, reject_crc=False):
        self.output = bytearray(b'RV32I JTAG loader v1\r\n' + PROMPT)
        self.image = bytearray()
        self.header = None
        self.valid = False
        self.reject_crc = reject_crc
        self.writes = []

    def read(self):
        result = bytes(self.output[:3])  # Headers, credits and prompts fragment.
        del self.output[:3]
        return result

    def write(self, data):
        self.writes.append(data)
        if self.header is not None:
            length, crc = self.header
            assert 0 < len(data) <= 32
            self.image.extend(data)
            assert len(self.image) <= length
            self.output.extend(b'+')
            if len(self.image) == length:
                self.valid = zlib.crc32(self.image) == crc and not self.reject_crc
                self.output.extend(b'\r\n' + (b'LOADED' if self.valid else b'ERR crc') + b'\r\n' + PROMPT)
                self.header = None
        elif data == b'?':
            self.output.extend(b'L: upload; G: run; ?: help\r\n' + PROMPT)
        elif data[:1] == b'L':
            assert len(data) == 9
            self.header = struct.unpack('<II', data[1:])
            assert 0 < self.header[0] <= MAX_IMAGE and self.header[0] % 4 == 0
            self.image.clear(); self.valid = False
            self.output.extend(b'SEND\r\n')
        elif data == b'G':
            self.output.extend((b'RUN\r\nHello\r\nEXIT 0000002A\r\n' if self.valid else b'ERR no image\r\n') + PROMPT)
        else:
            raise AssertionError(f'Unexpected host frame: {data!r}')


class UploadTests(unittest.TestCase):
    def test_padding_fragmentation_crc_and_run(self):
        peer = Peer(); client = LoaderClient(peer)
        client.synchronize()
        data = bytes(range(69))
        self.assertEqual(client.upload(data), 72)
        self.assertEqual(peer.image, data + b'\0\0\0')
        self.assertIn(b'EXIT 0000002A', client.run())

    def test_maximum_image_and_credit_chunks(self):
        peer = Peer(); peer.output.clear(); client = LoaderClient(peer)
        data = b'\x00\xFF\r\n' * (MAX_IMAGE // 4)
        self.assertEqual(client.upload(data), MAX_IMAGE)
        self.assertEqual(peer.image, data)
        self.assertEqual(len(peer.writes), 1 + MAX_IMAGE // 32)

    def test_invalid_size_sends_nothing(self):
        for data in [b'', bytes(MAX_IMAGE + 1)]:
            peer = Peer(); client = LoaderClient(peer)
            with self.assertRaises(ValueError): client.upload(data)
            self.assertFalse(peer.writes)

    def test_crc_rejection_does_not_run(self):
        peer = Peer(reject_crc=True); peer.output.clear(); client = LoaderClient(peer)
        with self.assertRaises(RuntimeError): client.upload(b'1234')
        self.assertNotIn(b'G', peer.writes)

    def test_no_image_and_disconnection_timeout(self):
        peer = Peer(); peer.output.clear(); client = LoaderClient(peer, timeout=0.5)
        with self.assertRaises(RuntimeError): client.run()
        client.timeout = 0.01
        with self.assertRaises(TimeoutError): client.until(b'never')


if __name__ == '__main__':
    unittest.main()
