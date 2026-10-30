# DE10-Lite board execution October 29 2026

The user supplied a board photo and terminal screenshot after following the
JTAG programming and application-upload procedure. Together they document a
powered, connected DE10-Lite and successful physical execution of both
uploaded applications. The original assets are retained byte for byte in
the progress-report evidence directory and embedded in Progress Report 7.

- [Board photo](../../progress_reports/evidence/report-7-board-photo.jpg),
  originally `output/pictures/IMG_6829.JPG`, with EXIF capture time
  October 29 2026 at 20:57:15.
- [Console screenshot](../../progress_reports/evidence/report-7-console.png),
  originally `output/pictures/screenshot-2026-10-29_20-57-33.png`.

## Visible application results

| Test | Captured result |
| --- | --- |
| Loader console | Three `RV32I JTAG loader v1` banners and `ready>` prompts before uploads |
| Hello upload | 328 bytes loaded at `0x10000`; CPU CRC32 verification reported |
| Hello execution | Expected hello message, `EXIT 0000002A`, `ready>` |
| Hello rerun | A separate `run` command produces the same message, exit value and prompt |
| Mixed RAM upload | 428 padded bytes loaded at `0x10000`; CPU CRC32 verification reported |
| Mixed RAM execution | `Mixed RAM loop passed: 1 3 6 10 15`, `EXIT 0000000F`, `ready>` |
| Mixed RAM rerun | A separate `run` command produces the same success message, exit value and prompt |

The screenshot shows the console and upload/run commands directly. It supports
native JTAG host-library communication and execution of uploaded code from
RAM. The photo shows the board beside the same console session. The mixed
application compares all five final RAM words against fixed constants before
printing its success message; its scope is five words and this workload.

## Build identity and evidence boundaries

The [current build and timing record](../2026-10-29-jtag-timing/README.md)
archives the successful Quartus build and this SOF SHA256:

```text
9d47f4ddc5c03f823a16a764951a4dadb9ad7cc92df3df66133d5b12743686fd
```

This is the archived build identity available for the session. Neither the
photo nor screenshot independently displays the programmed SOF hash, cable
identifier, or Programmer completion result. No stronger artifact-to-board
identity claim is made from those images alone.

Repeated loader banners are visible before the application uploads. A
complete reset-after-upload sequence, rejection of execution until a fresh
upload, interrupted-transfer recovery, and physical bad-CRC rejection are
not captured. These are carried into Report 7's November 6 hardware-recovery
goal, together with an acceptance checklist and a console log tied to the
SOF hash and cable selection.

The [upload guide](../../uart.md) contains the tested happy-path procedure.
The illustrated DOCX guide is scheduled for updating by November 6. The
earlier dated validation records retain their historical pending-board status.
