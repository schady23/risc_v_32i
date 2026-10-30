# Progress Report 7 results

Report 7 covers October 23 through October 29 2026. Its form follows Report 6,
and its goal assessment follows the three goals set in that report. The
retained Report 6 and original output-folder assets are unchanged.

## Goal assessment

1. **Build and validate the current JTAG design — complete.** Quartus Prime
   Lite 25.1 IP generation, a full build, fit review and explicit timing checks
   passed October 29. This is three days later than the October 26 target.
   Worst setup/hold/recovery/removal slacks are +2.339/+0.096/+16.793/+0.403 ns
   across available operating corners; all unconstrained-path counts are zero.
   See the [build record](../../validation/2026-10-29-jtag-timing/README.md).
2. **Test the CPU on the DE10-Lite — partially complete.** The user-provided
   photo and screenshot document physical hello upload, CRC verification,
   execution, return and rerun on October 29, ahead of the October 30 target.
   A reset-after-upload/fresh-upload sequence and interrupted-transfer/error
   recovery are not captured and are carried forward. See the
   [board record](../../validation/2026-10-29-board/README.md).
3. **Verify a second uploaded assembly application — complete.** The new
   `mixed_ram.S` application checks five running sums against fixed constants,
   passes the loader integration simulation, and is visibly uploaded and run
   twice on the board. Its 425-byte binary is padded to 428 bytes for upload;
   the expected return is 15 (`EXIT 0000000F`). This finished October 29 ahead
   of the November 6 target. The Markdown upload guide now links the procedure
   and physical evidence; refreshing the illustrated DOCX guide is a new goal.

## New goals and schedule

- **November 6:** complete recorded board reset, fresh-upload, interrupted
  transfer and bad-CRC recovery checks, with cable selection and SOF identity.
- **November 6:** update and verify the illustrated user guide using the tested
  build, Python setup, both application procedures and recovery evidence.
- **November 12:** draft the final report and demonstration plan for a planned
  November 19 review checkpoint. Preserve the existing November 24 through
  December 4 final report and demonstration window as a planning target.

The [previous Gantt](report-7-previous-gantt.png) is byte-for-byte the current
chart from Report 6. The [updated Gantt](report-7-current-gantt.png) distinguishes
actual October 29 build/board-application results from planned follow-up work.
Its completed CPU/reset row consolidates the earlier milestones in the
previous chart; it does not claim new reset coverage this week.

## Evidence and checks

- The final DOCX renders to six pages. Every page was visually inspected;
  the form's orphaned status row and an appendix spill were corrected. Page
  geometry and all preserve-only template parts were verified. The
  [verification record](report-7-verification.json) stores report/evidence
  hashes and the final review results.
- [Original board photo](report-7-board-photo.jpg) and
  [original console screenshot](report-7-console.png) are embedded in the DOCX.
  The screenshot uses native Word cropping of empty right-hand space only;
  the source PNG remains unchanged.
- [Fresh regression](report-7-regression.txt): 11 fixed benches, an additional
  mixed-application integration run, 14 directed programs and five host tests
  pass. Existing time-zero `numeric_std` settling warnings remain.
- [Fresh timing check](report-7-timing-check.txt): passes all operating corners,
  with zero unconstrained clocks/ports/paths. Six vendor JTAG empty-filter
  warnings remain; the 3 ns external JTAG I/O assumptions are documented.
- `scripts/build_report7.py` rebuilds the DOCX from the retained Report 6 form
  and [dated goal content](report-7-content.json), using python-docx and Pillow.
  Run it with the document skill's workspace Python. Its package checks retain
  original template styles, numbering, icons, custom XML and other opaque
  parts byte for byte. Rendering and full page-image inspection are required
  after regeneration.

The source images are visual evidence rather than raw console logs. They do
not independently identify the programmed SOF hash; the archived build hash
is reported separately. No physical recovery, exhaustive RAM test, new
architectural certification, or upstream certification result is inferred.
