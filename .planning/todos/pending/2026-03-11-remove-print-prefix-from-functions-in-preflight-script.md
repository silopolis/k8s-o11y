---
created: 2026-03-11T16:01:52.508Z
title: Remove print prefix from functions in preflight script
area: tooling
files:
  - scripts/preflight.sh:35-57
---

## Problem

The `scripts/preflight.sh` script uses verbose `print_` prefixes for its output functions:

- `print_header()` (line 35)
- `print_pass()` (line 41)
- `print_fail()` (line 45)
- `print_warn()` (line 50)
- `print_info()` (line 55)

These verbose prefixes make the code harder to read and don't follow modern shell scripting conventions. The `print_` prefix is redundant since all these functions already output text.

## Solution

Rename the functions to remove the `print_` prefix:

- `print_header()` → `header()`
- `print_pass()` → `pass()`
- `print_fail()` → `fail()`
- `print_warn()` → `warn()`
- `print_info()` → `info()`

Also update all call sites throughout the script (lines 60, 63, 65, 70, 73, 77, 79, 85, 88, 90, 95, 98, 100, 106, 113, 115, 120, 125, 126, 129, 134, 138, 141, 146, 150, 154, 161, 165, 167, 169, 175, 177, 181, 183, 187, 189, 192, 196).

This makes the code cleaner and more concise while maintaining readability.
