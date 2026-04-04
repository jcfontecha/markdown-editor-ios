#!/usr/bin/env python3

import argparse
import base64
import json
import mimetypes
import os
import subprocess
import sys
import urllib.error
import urllib.request
import uuid
from pathlib import Path


DEFAULT_ENV_FILE = Path("apps/web/.env.local")
DEFAULT_MAX_DIMENSION = 512


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate an image from a prompt using the OpenAI Images API."
    )
    parser.add_argument("--prompt", help="Prompt to send verbatim to the API")
    parser.add_argument(
        "--prompt-stdin",
        action="store_true",
        help="Read the prompt verbatim from stdin",
    )
    parser.add_argument("--output", required=True, help="PNG output path")
    parser.add_argument(
        "--image",
        action="append",
        default=[],
        help="Reference image path to upload. Repeat for multiple input images.",
    )
    parser.add_argument("--model", default="gpt-image-1-mini")
    parser.add_argument("--n", type=int, default=1)
    parser.add_argument("--size", default="1024x1024")
    parser.add_argument("--quality", default="medium")
    parser.add_argument(
        "--max-dimension",
        type=int,
        default=DEFAULT_MAX_DIMENSION,
        help="Resize the generated output in-place to this maximum pixel dimension using sips",
    )
    parser.add_argument(
        "--background",
        default="transparent",
        choices=("transparent", "opaque", "auto"),
        help="Background setting for the generated image",
    )
    parser.add_argument(
        "--moderation",
        default="auto",
        help="Moderation mode to send to the API",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print the JSON payload without calling the API",
    )
    args = parser.parse_args()

    if bool(args.prompt) == bool(args.prompt_stdin):
        parser.error("provide exactly one of --prompt or --prompt-stdin")

    return args


def read_prompt(args: argparse.Namespace) -> str:
    if args.prompt_stdin:
        prompt = sys.stdin.read().strip()
    else:
        prompt = args.prompt.strip()

    if not prompt:
        raise SystemExit("prompt must not be empty")

    return prompt


def load_api_key() -> str:
    api_key = os.environ.get("OPENAI_API_KEY")
    if api_key:
        return api_key

    if not DEFAULT_ENV_FILE.exists():
        raise SystemExit(
            "OPENAI_API_KEY is not set and apps/web/.env.local was not found"
        )

    for line in DEFAULT_ENV_FILE.read_text().splitlines():
        if line.startswith("OPENAI_API_KEY="):
            value = line.split("=", 1)[1].strip().strip('"').strip("'")
            if value:
                return value
            break

    raise SystemExit("OPENAI_API_KEY not found in apps/web/.env.local")


def request_image(api_key: str, payload: dict) -> bytes:
    request = urllib.request.Request(
        "https://api.openai.com/v1/images/generations",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
        method="POST",
    )

    try:
        with urllib.request.urlopen(request) as response:
            data = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        body = error.read().decode("utf-8", errors="replace")
        raise SystemExit(f"OpenAI API error {error.code}: {body}") from error

    try:
        encoded = data["data"][0]["b64_json"]
    except (KeyError, IndexError) as error:
        raise SystemExit("OpenAI API returned no image data") from error

    return base64.b64decode(encoded)


def build_multipart_body(
    fields: list[tuple[str, str]],
    files: list[tuple[str, Path]],
) -> tuple[str, bytes]:
    boundary = f"----OpenAIBoundary{uuid.uuid4().hex}"
    body = bytearray()

    for name, value in fields:
        body.extend(f"--{boundary}\r\n".encode("utf-8"))
        body.extend(
            f'Content-Disposition: form-data; name="{name}"\r\n\r\n'.encode("utf-8")
        )
        body.extend(value.encode("utf-8"))
        body.extend(b"\r\n")

    for field_name, path in files:
        mime_type = mimetypes.guess_type(path.name)[0] or "application/octet-stream"
        body.extend(f"--{boundary}\r\n".encode("utf-8"))
        body.extend(
            (
                f'Content-Disposition: form-data; name="{field_name}"; '
                f'filename="{path.name}"\r\n'
            ).encode("utf-8")
        )
        body.extend(f"Content-Type: {mime_type}\r\n\r\n".encode("utf-8"))
        body.extend(path.read_bytes())
        body.extend(b"\r\n")

    body.extend(f"--{boundary}--\r\n".encode("utf-8"))
    return f"multipart/form-data; boundary={boundary}", bytes(body)


def request_image_edit(
    api_key: str,
    fields: list[tuple[str, str]],
    images: list[Path],
) -> bytes:
    content_type, body = build_multipart_body(
        fields,
        [("image[]", image_path) for image_path in images],
    )
    request = urllib.request.Request(
        "https://api.openai.com/v1/images/edits",
        data=body,
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": content_type,
        },
        method="POST",
    )

    try:
        with urllib.request.urlopen(request) as response:
            data = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        body = error.read().decode("utf-8", errors="replace")
        raise SystemExit(f"OpenAI API error {error.code}: {body}") from error

    try:
        encoded = data["data"][0]["b64_json"]
    except (KeyError, IndexError) as error:
        raise SystemExit("OpenAI API returned no image data") from error

    return base64.b64decode(encoded)


def resize_image(path: Path, max_dimension: int) -> None:
    if max_dimension <= 0:
        raise SystemExit("--max-dimension must be greater than zero")

    try:
        subprocess.run(
            ["sips", "-Z", str(max_dimension), str(path)],
            check=True,
            capture_output=True,
            text=True,
        )
    except FileNotFoundError as error:
        raise SystemExit("sips is required for --max-dimension resizing") from error
    except subprocess.CalledProcessError as error:
        raise SystemExit(error.stderr.strip() or "sips resize failed") from error


def main() -> int:
    args = parse_args()
    prompt = read_prompt(args)
    payload = {
        "model": args.model,
        "prompt": prompt,
        "n": args.n,
        "size": args.size,
        "quality": args.quality,
        "background": args.background,
        "moderation": args.moderation,
    }
    image_paths = [Path(path) for path in args.image]

    for path in image_paths:
        if not path.exists():
            raise SystemExit(f"reference image not found: {path}")

    if args.dry_run:
        preview = {
            "endpoint": "/v1/images/edits" if image_paths else "/v1/images/generations",
            "payload": payload,
        }
        if image_paths:
            preview["images"] = [str(path) for path in image_paths]
        print(json.dumps(preview, indent=2))
        return 0

    api_key = load_api_key()
    if image_paths:
        image_bytes = request_image_edit(
            api_key,
            [(name, str(value)) for name, value in payload.items()],
            image_paths,
        )
    else:
        image_bytes = request_image(api_key, payload)

    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_bytes(image_bytes)
    if args.max_dimension:
        resize_image(output_path, args.max_dimension)
    print(output_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
