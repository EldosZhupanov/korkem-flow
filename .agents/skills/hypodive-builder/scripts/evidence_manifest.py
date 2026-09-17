#!/usr/bin/env python3
"""Hash explicitly selected committed evidence; never execute manifest content.

This is an integrity check, not a signature, experiment runner or preregistration.
Python standard library only. See ../HANDOFF_PROTOCOL.md for the freeze workflow.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys


def git(repo: Path, *args: str) -> bytes:
    result = subprocess.run(['git', '-C', str(repo), *args], capture_output=True)
    if result.returncode:
        raise ValueError(f'git {args[0]} failed: {result.stderr.decode(errors="replace").strip()}')
    return result.stdout


def root(repo: str) -> Path:
    return Path(git(Path(repo), 'rev-parse', '--show-toplevel').decode().strip()).resolve()


def evidence_path(repo: Path, name: str) -> Path:
    if not isinstance(name, str) or not name or any(ord(c) < 32 for c in name):
        raise ValueError('evidence paths must be nonempty strings without control characters')
    relative = PurePosixPath(name)
    if relative.is_absolute() or '..' in relative.parts or relative.as_posix() != name:
        raise ValueError(f'evidence path must be canonical and repository-relative: {name}')
    path = repo
    for part in relative.parts:
        path = path / part
        if path.is_symlink():
            raise ValueError(f'symlink evidence is not supported: {name}')
    if not path.is_file() or not path.resolve().is_relative_to(repo):
        raise ValueError(f'evidence must be a regular file inside the repository: {name}')
    return path


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def committed_bytes(repo: Path, commit: str, name: str) -> bytes:
    # Validate against the commit itself, not just hashes supplied by a manifest.
    entry = git(repo, 'ls-tree', commit, '--', name)
    if not entry.startswith((b'100644 blob ', b'100755 blob ')):
        raise ValueError(f'not a regular tracked file at recorded commit: {name}')
    return git(repo, 'show', f'{commit}:{name}')


def create(args: argparse.Namespace) -> None:
    repo = root(args.repo)
    output = Path(args.output)
    if output.exists() or output.is_symlink():
        raise ValueError('manifest already exists; use a new freeze, never overwrite')
    if git(repo, 'status', '--porcelain', '--untracked-files=all'):
        raise ValueError('freeze requires a clean working tree, including untracked files')
    commit = git(repo, 'rev-parse', 'HEAD').decode().strip()
    names = sorted(set(args.files))
    if len(names) != len(args.files):
        raise ValueError('duplicate evidence paths')
    records = []
    for name in names:
        data = evidence_path(repo, name).read_bytes()
        if data != committed_bytes(repo, commit, name):
            raise ValueError(f'working bytes differ from the evaluated commit: {name}')
        records.append({'path': name, 'bytes': len(data), 'sha256': digest(data)})
    manifest = {
        'schema_version': 1,
        'algorithm': 'sha256',
        'created_utc': datetime.now(timezone.utc).isoformat(),
        'commit': commit,
        'branch': git(repo, 'rev-parse', '--abbrev-ref', 'HEAD').decode().strip(),
        'files': records,
    }
    if (git(repo, 'rev-parse', 'HEAD').decode().strip() != commit or
            git(repo, 'status', '--porcelain', '--untracked-files=all')):
        raise ValueError('repository changed while hashing; retry from a clean freeze')
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open('x', encoding='utf-8') as handle:
        json.dump(manifest, handle, indent=2, ensure_ascii=False)
        handle.write('\n')
    print(f'Created manifest for {len(records)} files at {commit}')


def verify(args: argparse.Namespace) -> None:
    repo = root(args.repo)
    with Path(args.manifest).open(encoding='utf-8') as handle:
        manifest = json.load(handle)
    if not isinstance(manifest, dict) or manifest.get('schema_version') != 1:
        raise ValueError('unsupported manifest schema')
    if manifest.get('algorithm') != 'sha256':
        raise ValueError('unsupported hash algorithm')
    commit = manifest.get('commit')
    if not isinstance(commit, str) or not re.fullmatch(r'[0-9a-f]{40}|[0-9a-f]{64}', commit):
        raise ValueError('recorded commit must be a full hexadecimal object ID')
    records = manifest.get('files')
    if not isinstance(records, list) or not records:
        raise ValueError('manifest requires a nonempty file list')
    seen = set()
    for record in records:
        if not isinstance(record, dict):
            raise ValueError('invalid file record')
        name = record.get('path')
        path = evidence_path(repo, name)
        if name in seen:
            raise ValueError('duplicate evidence paths')
        seen.add(name)
        expected_hash, size = record.get('sha256'), record.get('bytes')
        if (not isinstance(expected_hash, str) or
                not re.fullmatch(r'[0-9a-f]{64}', expected_hash) or
                type(size) is not int or size < 0):
            raise ValueError(f'invalid hash/size metadata for {name}')
        for label, data in [('working file', path.read_bytes()),
                            ('recorded commit', committed_bytes(repo, commit, name))]:
            if len(data) != size or digest(data) != expected_hash:
                raise ValueError(f'integrity mismatch in {label}: {name}')
    print(f'Verified {len(records)} files against working bytes and commit {commit}')


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    make = commands.add_parser('create', help='freeze explicit tracked files from a clean repository')
    make.add_argument('--repo', required=True)
    make.add_argument('--output', required=True)
    make.add_argument('--files', nargs='+', required=True, help='repository-relative file paths')
    check = commands.add_parser('verify', help='verify recorded-commit and working-file bytes')
    check.add_argument('--repo', required=True)
    check.add_argument('--manifest', required=True)
    args = parser.parse_args()
    try:
        (create if args.command == 'create' else verify)(args)
    except (ValueError, OSError) as exc:
        print(f'ERROR: {exc}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
