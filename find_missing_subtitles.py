#!/usr/bin/env python3
"""Utility to list .mp4 files missing subtitle files.

This script recursively traverses a directory looking for .mp4 files that do
not have accompanying subtitle files with the same base name.
"""

import os
import argparse
from typing import Iterable, List


def find_missing_subtitles(directory: str, video_ext: str = ".mp4", subtitle_exts: Iterable[str] = (".lrc", ".txt", ".srt", ".vtt")) -> List[str]:
    """Return a list of video files without matching subtitle files.

    Args:
        directory: Top-level directory to search.
        video_ext: Extension of video files to find.
        subtitle_exts: Iterable of subtitle file extensions to check for.

    Returns:
        A list of absolute paths to video files lacking subtitle files.
    """
    missing = []
    video_ext = video_ext.lower()
    subtitle_exts = tuple(ext.lower() for ext in subtitle_exts)

    for root, _dirs, files in os.walk(directory):
        for name in files:
            if name.lower().endswith(video_ext):
                base = os.path.splitext(name)[0]
                video_path = os.path.join(root, name)
                # Check if any subtitle file exists with the same base name
                if not any(os.path.exists(os.path.join(root, base + ext)) for ext in subtitle_exts):
                    missing.append(video_path)

    return missing


def parse_args(argv: Iterable[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Find video files missing subtitles")
    parser.add_argument(
        "directory",
        nargs="?",
        default=".",
        help="Top-level directory to traverse (default: current directory)",
    )
    parser.add_argument(
        "--video-ext",
        default=".mp4",
        help="Video file extension to search for (default: .mp4)",
    )
    parser.add_argument(
        "--subtitle-exts",
        nargs="*",
        default=[".lrc", ".txt", ".srt", ".vtt"],
        help="Subtitle extensions to check for (default: .lrc .txt .srt .vtt)",
    )
    return parser.parse_args(argv)


def main(argv: Iterable[str] | None = None) -> None:
    args = parse_args(argv)
    missing = find_missing_subtitles(args.directory, args.video_ext, args.subtitle_exts)
    for path in missing:
        print(path)


if __name__ == "__main__":
    main()
