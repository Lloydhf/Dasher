"""Portable locations for Ascent's source-bound regression harnesses."""
from pathlib import Path
import os,shutil
ROOT=Path(__file__).resolve().parents[1]
TESTS=ROOT/'tests'
QA=ROOT/'.test-output'
QA.mkdir(exist_ok=True)
LUAU=os.environ.get('LUAU_BIN') or shutil.which('luau')
LUAU_COMPILE=os.environ.get('LUAU_COMPILE_BIN') or shutil.which('luau-compile')
if not LUAU:raise SystemExit('Install Luau on PATH or set LUAU_BIN.')
if not LUAU_COMPILE:raise SystemExit('Install luau-compile on PATH or set LUAU_COMPILE_BIN.')
