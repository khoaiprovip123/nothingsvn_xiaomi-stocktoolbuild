#!/usr/bin/env python3
"""Upload a ROM zip to Google Drive (resumable).

Usage:
    python3 upload_rom_api.py <file_path> [--folder_id ID] [--path a/b/c]

Credentials come from a Google OAuth token.pickle next to this script
(or at $GDRIVE_TOKEN_PATH). Generate it once with the Google OAuth flow.
"""
import argparse
import os
import pickle
import sys

from google.auth.transport.requests import Request
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

# Scopes needed for Drive API (Uploading files)
SCOPES = ["https://www.googleapis.com/auth/drive.file"]

# Folder mimetype in Google Drive.
FOLDER_MIME = "application/vnd.google-apps.folder"


def token_path() -> str:
    """Resolve the OAuth token location: env override, else next to this file."""
    override = os.environ.get("GDRIVE_TOKEN_PATH")
    if override:
        return override
    return os.path.join(os.path.dirname(os.path.abspath(__file__)), "token.pickle")


def get_credentials():
    path = token_path()
    creds = None

    if os.path.exists(path):
        with open(path, "rb") as token:
            creds = pickle.load(token)

    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            print("Refreshing access token...")
            creds.refresh(Request())
            with open(path, "wb") as token:
                pickle.dump(creds, token)
        else:
            print(f"Error: Invalid or missing token.pickle at {path}. Please generate it first.")
            sys.exit(1)

    return creds


def escape_query(value: str) -> str:
    """Escape a literal for use inside a single-quoted Drive API query string."""
    return value.replace("\\", "\\\\").replace("'", "\\'")


def get_or_create_folder(service, folder_name, parent_id=None):
    query = (
        f"name='{escape_query(folder_name)}' "
        f"and mimeType='{FOLDER_MIME}' "
        f"and trashed=false"
    )
    if parent_id:
        query += f" and '{escape_query(parent_id)}' in parents"

    results = service.files().list(q=query, spaces="drive", fields="files(id, name)").execute()
    files = results.get("files", [])

    if files:
        return files[0].get("id")

    file_metadata = {"name": folder_name, "mimeType": FOLDER_MIME}
    if parent_id:
        file_metadata["parents"] = [parent_id]
    folder = service.files().create(body=file_metadata, fields="id").execute()
    return folder.get("id")


def resolve_path(service, path, root_folder_id=None):
    if not path:
        return root_folder_id

    parts = [p for p in path.split("/") if p]
    current_parent = root_folder_id

    for part in parts:
        current_parent = get_or_create_folder(service, part, current_parent)

    return current_parent


def upload_rom(file_path, folder_id=None, path=None):
    if not os.path.exists(file_path):
        print(f"Error: The file '{file_path}' does not exist.")
        sys.exit(1)

    creds = get_credentials()

    try:
        service = build("drive", "v3", credentials=creds)

        # Resolve path to get final folder ID
        final_folder_id = resolve_path(service, path, folder_id)

        file_name = os.path.basename(file_path)
        file_metadata = {"name": file_name}

        if final_folder_id:
            file_metadata["parents"] = [final_folder_id]

        print(f"Preparing to upload: {file_name}")

        media = MediaFileUpload(file_path, resumable=True)

        request = service.files().create(
            body=file_metadata,
            media_body=media,
            fields="id",
        )

        response = None
        while response is None:
            status, response = request.next_chunk()
            if status:
                print(f"Uploaded {int(status.progress() * 100)}%")

        print(f"Upload Complete! File ID: {response.get('id')}")
        return response.get("id")

    except Exception as e:
        print(f"An error occurred during upload: {e}")
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(description="Upload a file to Google Drive.")
    parser.add_argument("file_path", help="Path to the file to upload")
    parser.add_argument("--folder_id", help="Google Drive Root Folder ID", default=None)
    parser.add_argument("--path", help="Path to create inside root folder", default=None)

    args = parser.parse_args()
    upload_rom(args.file_path, args.folder_id, args.path)


if __name__ == "__main__":
    main()
