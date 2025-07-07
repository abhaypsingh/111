import os
import argparse


def find_videos_without_subtitles(root_dir, video_exts=None, subtitle_exts=None):
    """Return a list of video files missing accompanying subtitle files."""
    video_exts = [ext.lower() for ext in (video_exts or ['.mp4'])]
    subtitle_exts = [ext.lower() for ext in (subtitle_exts or ['.lrc', '.txt', '.srt', '.vtt'])]

    missing = []

    for dirpath, _, filenames in os.walk(root_dir):
        for filename in filenames:
            base, ext = os.path.splitext(filename)
            if ext.lower() in video_exts:
                if not any(os.path.exists(os.path.join(dirpath, base + s_ext)) for s_ext in subtitle_exts):
                    missing.append(os.path.join(dirpath, filename))

    return missing


def main():
    parser = argparse.ArgumentParser(description="Find video files missing subtitle files.")
    parser.add_argument("root", help="Root directory to search")
    parser.add_argument("--video-exts", nargs="*", default=['.mp4'],
                        help="Video file extensions to check")
    parser.add_argument("--subtitle-exts", nargs="*", default=['.lrc', '.txt', '.srt', '.vtt'],
                        help="Subtitle file extensions")
    args = parser.parse_args()

    missing = find_videos_without_subtitles(args.root, args.video_exts, args.subtitle_exts)

    for path in missing:
        print(path)


if __name__ == "__main__":
    main()
