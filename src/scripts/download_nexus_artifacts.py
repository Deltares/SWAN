#!/usr/bin/env python3
import argparse
import base64
import getpass
import sys
import zipfile
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import quote, unquote, urlparse
from urllib.request import Request, urlopen

BASE_URI = "https://internal-artifacts.deltares.nl/repository/swan-dev/"
ARTIFACT_NAME = "41.51.9_ifx2024.2.0_win.zip"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Download a Nexus artifact from swan-dev and extract it into version/platform folders."
    )
    parser.add_argument("--tokenname", help="Nexus token name")
    parser.add_argument("--tokenpass", help="Nexus token password")
    parser.add_argument("--version", help="Artifact version folder name")
    parser.add_argument("--platform", help="Artifact platform folder name")
    parser.add_argument("--destination", help="Existing destination directory")
    return parser.parse_args()


def prompt_if_missing(value: str | None, prompt_text: str, secret: bool = False) -> str:
    if value and value.strip():
        return value.strip()

    while True:
        entered = getpass.getpass(prompt_text) if secret else input(prompt_text)
        entered = entered.strip()
        if entered:
            return entered
        print("Value is required.", file=sys.stderr)


def validate_folder_name(name: str, arg_name: str) -> str:
    cleaned = name.strip()
    if not cleaned:
        raise ValueError(f"{arg_name} is required.")
    if Path(cleaned).name != cleaned or any(sep in cleaned for sep in ["/", "\\"]):
        raise ValueError(f"{arg_name} must be a single folder name (no path separators).")
    return cleaned


def prepare_folders(destination: str, version: str, platform: str) -> tuple[Path, Path]:
    destination_path = Path(destination).expanduser().resolve()

    if not destination_path.exists() or not destination_path.is_dir():
        raise ValueError(f"--destination must be an existing folder: {destination_path}")

    safe_version = validate_folder_name(version, "--version")
    safe_platform = validate_folder_name(platform, "--platform")

    version_folder = destination_path / safe_version
    platform_folder = version_folder / safe_platform

    # Only fail when both version and platform folder already exist
    if version_folder.exists() and platform_folder.exists():
        raise ValueError(
            f"Destination already exists: {platform_folder}"
        )

    # Guard against path collisions with files
    if version_folder.exists() and not version_folder.is_dir():
        raise ValueError(f"Version path exists but is not a folder: {version_folder}")
    if platform_folder.exists() and not platform_folder.is_dir():
        raise ValueError(f"Platform path exists but is not a folder: {platform_folder}")

    platform_folder.mkdir(parents=True, exist_ok=True)
    return version_folder, platform_folder


def build_artifact_uri(version: str, platform: str) -> str:
    version_part = quote(version.strip("/\\"), safe="")
    platform_part = quote(platform.strip("/\\"), safe="")
    return f"{BASE_URI}{version_part}/{platform_part}/{ARTIFACT_NAME}"


def download_file(uri: str, token_name: str, token_pass: str, destination_folder: Path) -> Path:
    credentials = f"{token_name}:{token_pass}".encode("utf-8")
    auth_header = f"Basic {base64.b64encode(credentials).decode('ascii')}"

    request = Request(uri)
    request.add_header("Authorization", auth_header)
    request.add_header("Accept", "*/*")

    with urlopen(request) as response:
        if response.status < 200 or response.status >= 300:
            raise RuntimeError(f"Unexpected HTTP status: {response.status}")

        file_name = Path(unquote(urlparse(uri).path)).name
        zip_path = destination_folder / file_name

        with open(zip_path, "wb") as f:
            while True:
                chunk = response.read(1024 * 1024)
                if not chunk:
                    break
                f.write(chunk)

    return zip_path



def unzip_artifact(zip_path: Path, extract_to: Path) -> None:
    if not zipfile.is_zipfile(zip_path):
        raise ValueError(f"Downloaded file is not a valid zip archive: {zip_path}")

    extract_root = extract_to.resolve()

    with zipfile.ZipFile(zip_path, "r") as zf:
        infos = zf.infolist()

        normalized_names: list[str] = []
        for info in infos:
            name = info.filename.replace("\\", "/").strip("/")
            if name:
                normalized_names.append(name)

        top_levels = {name.split("/", 1)[0] for name in normalized_names}
        strip_prefix = None
        if len(top_levels) == 1:
            candidate = next(iter(top_levels))
            if all(n == candidate or n.startswith(candidate + "/") for n in normalized_names):
                strip_prefix = candidate + "/"

        for info in infos:
            src_name = info.filename.replace("\\", "/").strip("/")
            if not src_name:
                continue

            if strip_prefix:
                if src_name == strip_prefix[:-1]:
                    continue
                if src_name.startswith(strip_prefix):
                    src_name = src_name[len(strip_prefix):]

            if not src_name:
                continue

            dest_path = (extract_root / src_name).resolve()

            if dest_path != extract_root and extract_root not in dest_path.parents:
                raise ValueError(f"Unsafe path in zip: {info.filename}")

            if info.is_dir():
                dest_path.mkdir(parents=True, exist_ok=True)
                continue

            dest_path.parent.mkdir(parents=True, exist_ok=True)
            with zf.open(info, "r") as src, open(dest_path, "wb") as dst:
                while True:
                    chunk = src.read(1024 * 1024)
                    if not chunk:
                        break
                    dst.write(chunk)
    zip_path.unlink()





def main() -> int:
    args = parse_args()

    message = "\n  To get your token name/pass:\n  - Go to https://internal-artifacts.deltares.nl\n  - My account (top right corner)\n  - User Token\n  - Access User Token\n"
    token_name = prompt_if_missing(args.tokenname, message + "Token name: ")
    token_pass = prompt_if_missing(args.tokenpass, "Token pass: ", secret=True)

    message = "\n  Version example: 41.51.9\n  Check Nexus for available versions\n"
    version = prompt_if_missing(args.version, message + "Version: ")
    
    message = "\n  Platform options: win or lnx\n"
    platform = prompt_if_missing(args.platform, message + "Platform: ")
    
    message = "\n  Destination folder example: C:\\artifacts\n"
    destination = prompt_if_missing(args.destination, message + "Destination folder: ")

    try:
        version_folder, platform_folder = prepare_folders(destination, version, platform)

        artifact_uri = build_artifact_uri(version, platform)
        print(f"Downloading from: {artifact_uri}")

        zip_path = download_file(artifact_uri, token_name, token_pass, version_folder)
        print(f"Downloaded zip: {zip_path}")

        unzip_artifact(zip_path, platform_folder)
        print(f"Extracted to: {platform_folder}")
        return 0

    except HTTPError as ex:
        print(f"HTTP error: {ex.code} {ex.reason}", file=sys.stderr)
    except URLError as ex:
        print(f"Connection error: {ex.reason}", file=sys.stderr)
    except Exception as ex:
        print(f"Failed: {ex}", file=sys.stderr)

    return 1


if __name__ == "__main__":
    raise SystemExit(main())
