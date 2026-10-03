#!/usr/bin/env python3
import os
import subprocess
import shutil
import sys

ASEPRITE = os.environ.get('ASEPRITE', 'aseprite')
TILED = os.environ.get('TILED', 'tiled')

BASE_DIRECTORY = os.path.join(os.curdir, 'assets')

ASEPRITE_ARGS = ['--sheet-pack', '--shape-padding', '1', '--trim',
                 '--merge-duplicates', '--format', 'json-array', '--list-tags']

artifacts: list[str] = []
dry_run: bool = False

def needs_update(src_path: str, dst_path: str) -> bool:
    # first, determine if out_path is out of date
    has_mtime = False
    if os.path.exists(dst_path):
        has_mtime = True
        out_mtime = os.path.getmtime(dst_path)
    
    if has_mtime:
        return os.path.getmtime(src_path) > out_mtime
    else:
        return True


def copy_file(src_path: str, dst_path: str) -> bool:
    src_path = os.path.normpath(src_path)
    dst_path = os.path.normpath(dst_path)

    artifacts.append(dst_path)
    if not dry_run and needs_update(src_path, dst_path):
        print(f"[CPY] {src_path} => {dst_path}")
        os.makedirs(os.path.dirname(dst_path), exist_ok=True)
        shutil.copy(src_path, dst_path)
        return True
    else:
        return False


def process_tmx(src_path: str, dst_path: str) -> bool:
    (filename, _) = os.path.splitext(os.path.basename(src_path))
    intermediate_path = os.path.join(os.path.dirname(src_path), filename + '.lua')
    dst_path = os.path.splitext(dst_path)[0] + '.lua'
    
    artifacts.append(dst_path)
    if dry_run or not needs_update(src_path, dst_path): return True

    src_path = os.path.normpath(src_path)
    intermediate_path = os.path.normpath(intermediate_path)

    print(f'[TMX] {src_path} => {dst_path}')
    tiled = subprocess.run([TILED, '--export-map', 'lua', src_path, intermediate_path])
    if tiled.returncode != 0:
        return False
    
    os.makedirs(os.path.dirname(dst_path), exist_ok=True)
    os.replace(intermediate_path, dst_path)
    return True


def process_tsx(src_path: str, dst_path: str) -> bool:
    (filename, _) = os.path.splitext(os.path.basename(src_path))
    intermediate_path = os.path.join(os.path.dirname(src_path), filename + '.lua')
    dst_path = os.path.splitext(dst_path)[0] + '.lua'

    artifacts.append(dst_path)
    if dry_run or not needs_update(src_path, dst_path): return True

    src_path = os.path.normpath(src_path)
    intermediate_path = os.path.normpath(intermediate_path)

    print(f'[TSX] {src_path} => {dst_path}')
    tiled = subprocess.run([TILED, '--export-tileset', 'lua', src_path, intermediate_path])
    if tiled.returncode != 0:
        return False
    
    os.makedirs(os.path.dirname(dst_path), exist_ok=True)
    os.replace(intermediate_path, dst_path)
    return True


def process_ase(src_path: str, dst_path: str) -> bool:
    (filename, _) = os.path.splitext(os.path.basename(src_path))
    dst_json_path = os.path.splitext(dst_path)[0] + '.json'
    dst_png_path = os.path.splitext(dst_path)[0] + '.png'

    artifacts.append(dst_json_path)
    artifacts.append(dst_png_path)
    if dry_run or not needs_update(src_path, dst_json_path): return True

    src_path = os.path.normpath(src_path)
    dst_json_path = os.path.normpath(dst_json_path)
    dst_png_path = os.path.normpath(dst_png_path)

    print(f'[ASE] {src_path} => {dst_json_path}')
    os.makedirs(os.path.dirname(dst_json_path), exist_ok=True)
    ase = subprocess.run([ASEPRITE,
                          '-b', src_path,
                          '--data', dst_json_path,
                          '--sheet', dst_png_path] + ASEPRITE_ARGS)
    if ase.returncode != 0:
        return False
    
    return True


def scan_directory(dirpath: str) -> bool:
    succ = True
    src_dir = os.path.normpath(os.path.join('assets', dirpath))
    dst_dir = os.path.normpath(os.path.join('app', 'res', dirpath))

    if not os.path.exists(src_dir): return succ
    for basename in os.listdir(src_dir):
        path = os.path.join(src_dir, basename)

        if os.path.isdir(path):
            if basename != 'noexport':
                if not scan_directory(os.path.join(dirpath, basename)):
                    succ = False
        else:
            dst_path = os.path.join(dst_dir, basename)
            (_, fileext) = os.path.splitext(basename)

            match fileext:
                case '.ase' | '.aseprite':
                    if not process_ase(path, dst_path):
                        succ = False
                case '.tmx':
                    if not process_tmx(path, dst_path):
                        succ = False
                case '.tsx':
                    if not process_tsx(path, dst_path):
                        succ = False
                case _:
                    if not copy_file(path, dst_path):
                        succ = False

    return succ


def main():
    global dry_run
    
    for i in range(1, len(sys.argv)):
        if sys.argv[i] == '--dry-run':
            dry_run = True
    
    s = False
    while True:
        if not scan_directory('.'):
            break

        s = True
        break

    if dry_run:
        for artifact in artifacts:
            rel_path = os.path.normpath(os.path.relpath(artifact, 'app/res'))
            sys.stdout.write(rel_path.replace('\\', '/'))
            sys.stdout.write('\n')
    else:
        # create .gitignore for artifacts
        with open('app/res/.gitignore', 'w') as f:
            for artifact in artifacts:
                rel_path = os.path.normpath(os.path.relpath(artifact, 'app/res'))
                f.write(rel_path.replace('\\', '/'))
                f.write('\n')

    if not s: sys.exit(1)


if __name__ == '__main__': main()