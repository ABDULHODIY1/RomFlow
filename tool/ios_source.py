#!/usr/bin/env python3
"""Writes the AltStore / SideStore source for the iPhone app.

With the source added once in SideStore or AltStore, RomFlow installs and
updates with one tap ("Get" / "Update"). The source is published next to
each release; its stable address is
https://github.com/<repo>/releases/latest/download/altstore-source.json

Usage: tool/ios_source.py <ipa> <download-url> <repo> <out.json>
"""
import datetime
import json
import os
import plistlib
import re
import sys
import zipfile

ipa, url, repo, out = sys.argv[1:5]

with zipfile.ZipFile(ipa) as z:
    name = next(n for n in z.namelist()
                if re.fullmatch(r"Payload/[^/]+\.app/Info\.plist", n))
    info = plistlib.loads(z.read(name))

raw = f"https://raw.githubusercontent.com/{repo}/main"
icon = f"{raw}/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png"
version = info["CFBundleShortVersionString"]
build = str(info["CFBundleVersion"])
today = datetime.date.today().isoformat()
about = ("Eshik va rom ustaxonalari uchun smeta, chizma, 3D, zavodlar narxi "
         "va buyurtmalar. Internetsiz ishlaydi, ma’lumotlar telefonda.")
privacy = {k: info[k] for k in ("NSCameraUsageDescription",
                                "NSPhotoLibraryUsageDescription") if k in info}
release = {
    "version": version,
    "buildVersion": build,
    "date": today,
    "localizedDescription": f"RomFlow {version}: "
                            f"https://github.com/{repo}/releases/tag/v{version}",
    "downloadURL": url,
    "size": os.path.getsize(ipa),
    "minOSVersion": info.get("MinimumOSVersion", "15.0"),
}
app = {
    "name": "RomFlow",
    "bundleIdentifier": info["CFBundleIdentifier"],
    "developerName": "RomFlow",
    "subtitle": "Smeta, chizma va 3D",
    "localizedDescription": about,
    "iconURL": icon,
    "tintColor": "1E6FD9",
    "category": "utilities",
    "screenshots": [f"{raw}/docs/screenshots/{n}.png"
                    for n in ("home", "desk", "compare", "3d")],
    "versions": [release],
    "appPermissions": {"entitlements": [], "privacy": privacy},
    # Older SideStore and AltStore builds read these.
    "version": version,
    "versionDate": today,
    "downloadURL": url,
    "size": release["size"],
}
source = {
    "name": "RomFlow",
    "identifier": "uz.romflow.source",
    "subtitle": "RomFlow ilovasi",
    "description": about,
    "iconURL": icon,
    "website": f"https://github.com/{repo}",
    "tintColor": "1E6FD9",
    "apps": [app],
    "news": [],
}
with open(out, "w", encoding="utf-8") as f:
    json.dump(source, f, ensure_ascii=False, indent=2)
print(f"{out}: RomFlow {version} ({build}), {release['size']} bytes")
