#!/usr/bin/env python3
import argparse
import json
import sys

import whisper


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("audio_path")
    parser.add_argument("--model", default="base")
    parser.add_argument("--language", default="pt")
    args = parser.parse_args()

    model = whisper.load_model(args.model)
    result = model.transcribe(
        args.audio_path,
        language=args.language,
        task="transcribe",
        fp16=False,
        verbose=False,
    )
    payload = {
        "text": (result.get("text") or "").strip(),
        "language": result.get("language") or args.language,
        "model": args.model,
        "segments": len(result.get("segments") or []),
    }
    sys.stdout.write(json.dumps(payload, ensure_ascii=False))


if __name__ == "__main__":
    main()
