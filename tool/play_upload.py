"""Google Play upload helper used by CI.

  python3 tool/play_upload.py check            # verify the service account can open an edit; list tracks
  python3 tool/play_upload.py upload AAB_PATH  # upload the bundle to the closed-testing track and send it to review

Needs PLAY_SERVICE_ACCOUNT_JSON (the whole JSON key) in the environment. PLAY_TRACK defaults to "alpha"
(the default closed-testing track). Release notes come from store/release-notes-<version>.txt, where
<version> is the pubspec version without the build number; each language is wrapped in <en-US>...</en-US>.
"""
import json
import os
import re
import sys

from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

PACKAGE = "com.tidynook.game"
TRACK = os.environ.get("PLAY_TRACK", "alpha")


def service():
    raw = os.environ.get("PLAY_SERVICE_ACCOUNT_JSON", "").strip()
    if not raw:
        sys.exit("PLAY_SERVICE_ACCOUNT_JSON is not set")
    try:
        info = json.loads(raw)
    except ValueError:
        sys.exit("PLAY_SERVICE_ACCOUNT_JSON is not valid JSON: paste the whole key file, from { to }")
    creds = service_account.Credentials.from_service_account_info(
        info, scopes=["https://www.googleapis.com/auth/androidpublisher"])
    print("Service account:", info.get("client_email"))
    return build("androidpublisher", "v3", credentials=creds, cache_discovery=False)


def pubspec_version():
    for line in open("pubspec.yaml", encoding="utf-8"):
        m = re.match(r"^version:\s*([0-9.]+)\+(\d+)", line)
        if m:
            return m.group(1), int(m.group(2))
    sys.exit("no version in pubspec.yaml")


def release_notes(version):
    path = f"store/release-notes-{version}.txt"
    if not os.path.exists(path):
        print("No release notes file", path)
        return []
    text = open(path, encoding="utf-8").read()
    notes = []
    for lang, body in re.findall(r"<([A-Za-z-]+)>\s*(.*?)\s*</\1>", text, re.S):
        notes.append({"language": lang, "text": body.strip()[:500]})
    print("Release notes for:", ", ".join(n["language"] for n in notes))
    return notes


def check():
    svc = service()
    edits = svc.edits()
    edit = edits.insert(packageName=PACKAGE, body={}).execute()
    try:
        tracks = edits.tracks().list(packageName=PACKAGE, editId=edit["id"]).execute()
        for t in tracks.get("tracks", []):
            rel = [(r.get("name"), r.get("status"), r.get("versionCodes")) for r in t.get("releases", [])]
            print("track", t["track"], rel)
        print("PLAY CHECK OK")
    finally:
        edits.delete(packageName=PACKAGE, editId=edit["id"]).execute()


def upload(aab):
    version, code = pubspec_version()
    svc = service()
    edits = svc.edits()
    edit = edits.insert(packageName=PACKAGE, body={}).execute()
    eid = edit["id"]
    media = MediaFileUpload(aab, mimetype="application/octet-stream", resumable=True)
    bundle = edits.bundles().upload(packageName=PACKAGE, editId=eid, media_body=media).execute()
    print("Uploaded bundle versionCode", bundle["versionCode"])
    if int(bundle["versionCode"]) != code:
        print("warning: pubspec build number", code, "differs from bundle", bundle["versionCode"])
    body = {"track": TRACK, "releases": [{
        "name": f"{bundle['versionCode']} ({version})",
        "versionCodes": [str(bundle["versionCode"])],
        "status": "completed",
        "releaseNotes": release_notes(version),
    }]}
    edits.tracks().update(packageName=PACKAGE, editId=eid, track=TRACK, body=body).execute()
    res = edits.commit(packageName=PACKAGE, editId=eid).execute()
    print("Committed edit", res.get("id"), "to track", TRACK, "- PLAY UPLOAD OK")


if __name__ == "__main__":
    if len(sys.argv) >= 2 and sys.argv[1] == "check":
        check()
    elif len(sys.argv) >= 3 and sys.argv[1] == "upload":
        upload(sys.argv[2])
    else:
        sys.exit(__doc__)
