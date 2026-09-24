"""Portable locations for the inherited Ascent 0.5 regression harnesses."""
from pathlib import Path
import os
import shutil
ROOT = Path(__file__).resolve().parents[1]
QA = ROOT / '.test-output'
QA.mkdir(exist_ok=True)
LUAU = os.environ.get('LUAU_BIN') or shutil.which('luau')
if not LUAU:
    raise SystemExit('Install the Luau CLI on PATH or set LUAU_BIN to the luau executable.')
