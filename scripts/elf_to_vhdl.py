#!/usr/bin/env python3
"""Convert a little-endian RV32 binary into program_image_pkg.vhd."""

from __future__ import annotations

import argparse
from pathlib import Path

ROM_BYTES = 16 * 1024


def render_package(data: bytes) -> str:
    if len(data) > ROM_BYTES:
        raise ValueError(f"image is {len(data)} bytes; ROM capacity is {ROM_BYTES}")

    padded = data + bytes((-len(data)) % 4)
    words = [int.from_bytes(padded[i : i + 4], "little") for i in range(0, len(padded), 4)]

    entries = [f'    {index} => x"{word:08X}",' for index, word in enumerate(words)]
    entries.append("    others => (others => '0')")
    aggregate = "\n".join(entries)

    return f"""library ieee;
use ieee.std_logic_1164.all;

use work.rv32i_pkg.all;
use work.memory_map_pkg.all;

package program_image_pkg is
  type program_image_t is array (0 to MEMORY_WORDS - 1) of word_t;

  -- Generated file. Do not edit manually.
  constant PROGRAM_IMAGE : program_image_t := (
{aggregate}
  );
end package;
"""


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("binary", type=Path, help="input flat binary")
    parser.add_argument("output", type=Path, help="output VHDL package")
    args = parser.parse_args()

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(render_package(args.binary.read_bytes()), encoding="ascii")


if __name__ == "__main__":
    main()
