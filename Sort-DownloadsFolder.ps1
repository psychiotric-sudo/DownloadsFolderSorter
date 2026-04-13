Set-Location $PSScriptRoot
# ===================================================================
# Downloads Folder Organizer - ULTRA EDITION v2
# Features: Idle Priority, Loop-Ready, 5-Pass Cleanup,
#           In-Progress Protection, SHA256 Dedup, Date Sorting,
#           Exhaustive Extension Mappings (500+ extensions),
#           CAD/Engineering, Medical, GIS, Science, Game Dev,
#           3D/VR/AR, Security, Crypto, Mobile, Legacy/DOS,
#           Fonts, eBooks, Subtitles, Disk Images, Containers,
#           Firmware, Database, Network, Web Dev, Audio Production,
#           Video Production, Machine Learning, Emulation, and more.
#           VERBOSE LOGGING for debug/development phase.
# ===================================================================

# ---------------------------------------------------------------
# VERBOSE LOGGING -- Set to $true during development/testing,
#                   Set to $false for silent background operation
# ---------------------------------------------------------------
$VerboseLogging = $false

# Log file path (only used when $VerboseLogging = $true)
$LogFile = "$env:USERPROFILE\Downloads\_organizer_log.txt"

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "MOVE", "SKIP", "DEDUP", "WARN", "ERROR", "CYCLE", "CLEAN")]
        [string]$Level = "INFO"
    )
    if (-not $VerboseLogging) { return }
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp][$Level] $Message"

    # Console color coding
    switch ($Level) {
        "MOVE" { Write-Host $line -ForegroundColor Green }
        "SKIP" { Write-Host $line -ForegroundColor DarkGray }
        "DEDUP" { Write-Host $line -ForegroundColor Cyan }
        "WARN" { Write-Host $line -ForegroundColor Yellow }
        "ERROR" { Write-Host $line -ForegroundColor Red }
        "CYCLE" { Write-Host $line -ForegroundColor Magenta }
        "CLEAN" { Write-Host $line -ForegroundColor DarkCyan }
        default { Write-Host $line -ForegroundColor White }
    }

    # Also append to log file
    try { Add-Content -Path $LogFile -Value $line -ErrorAction SilentlyContinue } catch {}
}

# ---------------------------------------------------------------
# Set process to Idle priority to stay invisible to performance
# ---------------------------------------------------------------
$Process = [System.Diagnostics.Process]::GetCurrentProcess()
$Process.PriorityClass = "Idle"
Write-Log "Organizer started. PID: $($Process.Id) | VerboseLogging: $VerboseLogging" "INFO"

# ---------------------------------------------------------------
# CYCLE COUNTER
# ---------------------------------------------------------------
$CycleCount = 0

while ($true) {
    $CycleCount++
    Write-Log "===== CYCLE $CycleCount BEGIN =====" "CYCLE"
    $CycleStart = Get-Date
    $movedCount = 0
    $skippedCount = 0
    $dedupCount = 0
    $errorCount = 0

    try {
        $downloads = [Environment]::GetFolderPath("UserProfile") + "\Downloads"
        $documents = [Environment]::GetFolderPath("MyDocuments")
        $pictures = [Environment]::GetFolderPath("MyPictures")
        $music = [Environment]::GetFolderPath("MyMusic")
        $videos = [Environment]::GetFolderPath("MyVideos")

        Write-Log "Downloads: $downloads | Documents: $documents" "INFO"

        $excludeFolders = @(
            "Thumbnails", ".thumbnails", "System Volume Information",
            '$Recycle.Bin', "AppData", ".git", "node_modules", "__pycache__",
            ".vs", ".vscode", ".idea", "bin", "obj"
        )

        function ShouldExclude([string]$path) {
            foreach ($folder in $excludeFolders) {
                if ($path -like "*\$folder*") { return $true }
            }
            $file = Get-Item -Path $path -Force -ErrorAction SilentlyContinue
            if ($file -and ($file.Attributes -band [System.IO.FileAttributes]::Hidden)) { return $true }
            return $false
        }

        function Get-FileHash-Custom([string]$filePath) {
            try {
                $stream = [System.IO.File]::OpenRead($filePath)
                $sha256 = [System.Security.Cryptography.SHA256]::Create()
                $hash = $sha256.ComputeHash($stream)
                $stream.Close()
                return [System.BitConverter]::ToString($hash).Replace("-", "").ToLower()
            }
            catch { return $null }
        }

        function IsFileInUse([string]$filePath) {
            try {
                $stream = [System.IO.File]::Open($filePath, 'Open', 'Read', 'None')
                $stream.Close()
                return $false
            }
            catch { return $true }
        }

        # ===============================================================
        # CONFLICT RESOLUTION NOTES (for ambiguous extensions)
        # Every key appears exactly ONCE. Priority rule documented inline.
        #   .ptx     -> RAW Camera (Pentax) over Pro Tools session
        #   .rm      -> Music (RealAudio) over Video stream
        #   .cap     -> RAW Camera (Phase One) over Security/Firmware
        #   .prproj  -> Video Production (single entry)
        #   .aep     -> Video Production (single entry)
        #   .aet     -> Video Production (single entry)
        #   .stl     -> CAD/STL 3D Print over Subtitle .stl
        #   .ass     -> Subtitles (SubStation Alpha) over Arnold .ass
        #   .hdr     -> Pictures (HDR image) over Medical header
        #   .mat     -> Science/MATLAB over 3D Materials
        #   .fit     -> Science/Astronomy FITS over GPS .fit
        #   .h5      -> Machine Learning/Keras over HDF5 Science
        #   .3ds     -> CAD/3DS 3D over Emulation ROM
        #   .img     -> Virtual Machines/Raw Disk Images (most common)
        #   .key     -> Security/Private Keys over Apple Keynote
        #   .pub     -> Security/Public Keys over MS Publisher
        #   .bin     -> Firmware/Binary over ML weights / Executables
        #   .ts      -> Video (Transport Stream) over TypeScript
        #   .rs      -> Code/Rust over 3D Redshift scene
        #   .m       -> Code/Objective-C over Science/MATLAB .m
        #   .vhd     -> Virtual Machines/Hyper-V over Code/VHDL
        #   .ps1     -> Code/PowerShell over Emulation PlayStation
        #   .cmd     -> Code/Batch (single entry)
        #   .json    -> Data/JSON (single entry)
        #   .geojson -> GIS/GeoJSON (single entry)
        #   .md      -> Text/Markdown over Emulation Sega Genesis
        #   .conf    -> System/Config (single entry)
        #   .inf     -> System/INF over Executables/Setup
        #   .reg     -> System/Registry (single entry)
        #   .out     -> System/Logs over Firmware ELF Output
        #   .bak     -> System/Backups over Database Backups
        #   .mdf     -> Database/SQL Server over Emulation Disc
        #   .dbf     -> Database/dBASE over GIS Shapefile sidecar
        #   .nsf     -> Music/NES Sound Format over Lotus Notes DB
        #   .keystore-> Security/Java Keystores over Mobile dup
        #   .aab     -> Packages/Android Bundles over Mobile dup
        #   .pdb     -> Database/PDB over eBooks PDB
        #   .bdf     -> Fonts (bitmap) over Medical biosignals BDF
        #   .psf     -> Music/PSF chiptune over Fonts PSF bitmap
        #   .jar     -> Packages/Java JAR over Archives JAR
        # ===============================================================

        $fileTypes = @{

            # --- PICTURES / RASTER ---
            ".jpg"             = $pictures
            ".jpeg"            = $pictures
            ".jpe"             = $pictures
            ".png"             = $pictures
            ".gif"             = $pictures
            ".bmp"             = $pictures
            ".tiff"            = $pictures
            ".tif"             = $pictures
            ".webp"            = $pictures
            ".svg"             = $pictures
            ".ico"             = $pictures
            ".heic"            = $pictures
            ".heif"            = $pictures
            ".avif"            = $pictures
            ".jxl"             = $pictures
            ".hdr"             = $pictures
            ".exr"             = $pictures
            ".tga"             = $pictures
            ".pcx"             = $pictures
            ".ppm"             = $pictures
            ".pgm"             = $pictures
            ".pbm"             = $pictures
            ".xbm"             = $pictures
            ".xpm"             = $pictures
            ".wbmp"            = $pictures
            ".cur"             = $pictures
            ".ani"             = $pictures
            ".dib"             = $pictures
            ".jfif"            = $pictures
            ".jp2"             = $pictures
            ".j2k"             = $pictures
            ".jpx"             = $pictures
            ".jpm"             = $pictures
            ".mj2"             = $pictures
            ".sgi"             = $pictures
            ".rgba"            = $pictures
            ".rgb"             = $pictures
            ".iff"             = $pictures
            ".lbm"             = $pictures
            ".pict"            = $pictures
            ".pct"             = $pictures
            ".pic"             = $pictures
            ".wmf"             = $pictures
            ".emf"             = $pictures
            ".cgm"             = $pictures

            # --- PICTURES / RAW CAMERA ---
            ".raw"             = $pictures
            ".cr2"             = $pictures
            ".cr3"             = $pictures
            ".nef"             = $pictures
            ".nrw"             = $pictures
            ".arw"             = $pictures
            ".srf"             = $pictures
            ".sr2"             = $pictures
            ".orf"             = $pictures
            ".raf"             = $pictures
            ".rw2"             = $pictures
            ".rwl"             = $pictures
            ".dng"             = $pictures
            ".pef"             = $pictures
            ".ptx"             = $pictures
            ".srw"             = $pictures
            ".x3f"             = $pictures
            ".bay"             = $pictures
            ".cap"             = $pictures
            ".iiq"             = $pictures
            ".eip"             = $pictures
            ".fff"             = $pictures
            ".mef"             = $pictures
            ".mos"             = $pictures
            ".mrw"             = $pictures
            ".3fr"             = $pictures
            ".kdc"             = $pictures
            ".dcr"             = $pictures
            ".k25"             = $pictures
            ".rwz"             = $pictures
            ".erf"             = $pictures
            ".nex"             = $pictures

            # --- MUSIC / AUDIO ---
            ".mp3"             = $music
            ".wav"             = $music
            ".flac"            = $music
            ".aac"             = $music
            ".ogg"             = $music
            ".wma"             = $music
            ".m4a"             = $music
            ".aiff"            = $music
            ".aif"             = $music
            ".alac"            = $music
            ".opus"            = $music
            ".mid"             = $music
            ".midi"            = $music
            ".amr"             = $music
            ".ape"             = $music
            ".au"              = $music
            ".ra"              = $music
            ".rm"              = $music
            ".mka"             = $music
            ".wv"              = $music
            ".tta"             = $music
            ".spx"             = $music
            ".caf"             = $music
            ".snd"             = $music
            ".gsm"             = $music
            ".ac3"             = $music
            ".dts"             = $music
            ".eac3"            = $music
            ".mpc"             = $music
            ".mp2"             = $music
            ".mp1"             = $music
            ".xm"              = $music
            ".mod"             = $music
            ".it"              = $music
            ".s3m"             = $music
            ".669"             = $music
            ".mtm"             = $music
            ".med"             = $music
            ".ult"             = $music
            ".stm"             = $music
            ".far"             = $music
            ".amf"             = $music
            ".psf"             = $music
            ".psf2"            = $music
            ".minipsf"         = $music
            ".gsf"             = $music
            ".minigsf"         = $music
            ".spc"             = $music
            ".nsf"             = $music
            ".vgm"             = $music
            ".vgz"             = $music
            ".sid"             = $music
            ".gym"             = $music
            ".adx"             = $music
            ".hca"             = $music
            ".at3"             = $music
            ".at9"             = $music

            # --- AUDIO PRODUCTION ---
            ".als"             = "$music\Ableton Live"
            ".alc"             = "$music\Ableton Live"
            ".alp"             = "$music\Ableton Live"
            ".flp"             = "$music\FL Studio"
            ".fst"             = "$music\FL Studio"
            ".logic"           = "$music\Logic Pro"
            ".logicx"          = "$music\Logic Pro"
            ".ptf"             = "$music\Pro Tools"
            ".ptxt"            = "$music\Pro Tools"
            ".bwf"             = "$music\Broadcast WAV"
            ".rx2"             = "$music\REX Files"
            ".rex"             = "$music\REX Files"
            ".rcy"             = "$music\REX Files"
            ".nki"             = "$music\Kontakt Instruments"
            ".nkm"             = "$music\Kontakt Instruments"
            ".nkp"             = "$music\Kontakt Instruments"
            ".nkx"             = "$music\Kontakt Instruments"
            ".vstpreset"       = "$music\VST Presets"
            ".aupreset"        = "$music\Audio Unit Presets"
            ".sfz"             = "$music\SFZ Samples"
            ".sf2"             = "$music\SoundFonts"
            ".sf3"             = "$music\SoundFonts"
            ".dls"             = "$music\SoundFonts"

            # --- VIDEO ---
            ".mp4"             = $videos
            ".avi"             = $videos
            ".mkv"             = $videos
            ".mov"             = $videos
            ".wmv"             = $videos
            ".flv"             = $videos
            ".webm"            = $videos
            ".m4v"             = $videos
            ".mpeg"            = $videos
            ".mpg"             = $videos
            ".mpe"             = $videos
            ".3gp"             = $videos
            ".3g2"             = $videos
            ".vob"             = $videos
            ".ogv"             = $videos
            ".ts"              = $videos
            ".mts"             = $videos
            ".m2ts"            = $videos
            ".m2t"             = $videos
            ".m2v"             = $videos
            ".m1v"             = $videos
            ".divx"            = $videos
            ".xvid"            = $videos
            ".asf"             = $videos
            ".rmvb"            = $videos
            ".f4v"             = $videos
            ".f4p"             = $videos
            ".f4a"             = $videos
            ".f4b"             = $videos
            ".amv"             = $videos
            ".nsv"             = $videos
            ".roq"             = $videos
            ".ivf"             = $videos
            ".gifv"            = $videos
            ".dv"              = $videos
            ".qt"              = $videos
            ".yuv"             = $videos
            ".hevc"            = $videos
            ".h264"            = $videos
            ".h265"            = $videos
            ".264"             = $videos
            ".265"             = $videos
            ".mjpg"            = $videos
            ".mjpeg"           = $videos

            # --- VIDEO PRODUCTION ---
            ".prproj"          = "$videos\Adobe Premiere Pro"
            ".aep"             = "$videos\Adobe After Effects"
            ".aet"             = "$videos\Adobe After Effects"
            ".drp"             = "$videos\DaVinci Resolve"
            ".drfp"            = "$videos\DaVinci Resolve"
            ".veg"             = "$videos\Vegas Pro"
            ".vf"              = "$videos\Vegas Pro"
            ".kdenlive"        = "$videos\Kdenlive"
            ".fcp"             = "$videos\Final Cut Pro"
            ".fcpx"            = "$videos\Final Cut Pro"
            ".fcpbundle"       = "$videos\Final Cut Pro"
            ".capx"            = "$videos\Camtasia"

            # --- SUBTITLES & CAPTIONS ---
            ".srt"             = "$videos\Subtitles"
            ".sub"             = "$videos\Subtitles"
            ".ass"             = "$videos\Subtitles"
            ".ssa"             = "$videos\Subtitles"
            ".vtt"             = "$videos\Subtitles"
            ".lrc"             = "$videos\Subtitles"
            ".idx"             = "$videos\Subtitles"
            ".smi"             = "$videos\Subtitles"
            ".sbv"             = "$videos\Subtitles"
            ".dfxp"            = "$videos\Subtitles"
            ".ttml"            = "$videos\Subtitles"

            # --- MS OFFICE / WORD ---
            ".doc"             = "$documents\Microsoft Word"
            ".docx"            = "$documents\Microsoft Word"
            ".docm"            = "$documents\Microsoft Word"
            ".dot"             = "$documents\Microsoft Word"
            ".dotx"            = "$documents\Microsoft Word"
            ".dotm"            = "$documents\Microsoft Word"
            ".rtf"             = "$documents\Microsoft Word"
            ".odt"             = "$documents\Microsoft Word"
            ".fodt"            = "$documents\Microsoft Word"
            ".ott"             = "$documents\Microsoft Word"
            ".wps"             = "$documents\Microsoft Word"
            ".wpt"             = "$documents\Microsoft Word"
            ".wpd"             = "$documents\Microsoft Word"
            ".docb"            = "$documents\Microsoft Word"
            ".pages"           = "$documents\Apple Pages"

            # --- MS OFFICE / EXCEL ---
            ".xls"             = "$documents\Microsoft Excel"
            ".xlsx"            = "$documents\Microsoft Excel"
            ".xlsm"            = "$documents\Microsoft Excel"
            ".xlsb"            = "$documents\Microsoft Excel"
            ".xlt"             = "$documents\Microsoft Excel"
            ".xltx"            = "$documents\Microsoft Excel"
            ".xltm"            = "$documents\Microsoft Excel"
            ".csv"             = "$documents\Microsoft Excel"
            ".ods"             = "$documents\Microsoft Excel"
            ".fods"            = "$documents\Microsoft Excel"
            ".ots"             = "$documents\Microsoft Excel"
            ".numbers"         = "$documents\Apple Numbers"
            ".dif"             = "$documents\Microsoft Excel"
            ".sylk"            = "$documents\Microsoft Excel"
            ".slk"             = "$documents\Microsoft Excel"

            # --- MS OFFICE / POWERPOINT ---
            ".ppt"             = "$documents\Microsoft PowerPoint"
            ".pptx"            = "$documents\Microsoft PowerPoint"
            ".pptm"            = "$documents\Microsoft PowerPoint"
            ".pot"             = "$documents\Microsoft PowerPoint"
            ".potx"            = "$documents\Microsoft PowerPoint"
            ".potm"            = "$documents\Microsoft PowerPoint"
            ".pps"             = "$documents\Microsoft PowerPoint"
            ".ppsx"            = "$documents\Microsoft PowerPoint"
            ".ppsm"            = "$documents\Microsoft PowerPoint"
            ".odp"             = "$documents\Microsoft PowerPoint"
            ".fodp"            = "$documents\Microsoft PowerPoint"
            ".otp"             = "$documents\Microsoft PowerPoint"
            ".key"             = "$documents\Security\Private Keys"

            # --- MS OFFICE / OTHERS ---
            ".mdb"             = "$documents\Microsoft Access"
            ".accdb"           = "$documents\Microsoft Access"
            ".accde"           = "$documents\Microsoft Access"
            ".accdt"           = "$documents\Microsoft Access"
            ".pub"             = "$documents\Security\Public Keys"
            ".one"             = "$documents\Microsoft OneNote"
            ".onetoc2"         = "$documents\Microsoft OneNote"
            ".vsdx"            = "$documents\Microsoft Visio"
            ".vsd"             = "$documents\Microsoft Visio"
            ".vss"             = "$documents\Microsoft Visio"
            ".vst"             = "$documents\Microsoft Visio"
            ".vssx"            = "$documents\Microsoft Visio"
            ".vstx"            = "$documents\Microsoft Visio"
            ".mpp"             = "$documents\Microsoft Project"
            ".mpt"             = "$documents\Microsoft Project"
            ".pst"             = "$documents\Microsoft Outlook"
            ".ost"             = "$documents\Microsoft Outlook"
            ".msg"             = "$documents\Microsoft Outlook"
            ".eml"             = "$documents\Email"
            ".emlx"            = "$documents\Email"
            ".mbox"            = "$documents\Email"
            ".mbx"             = "$documents\Email"

            # --- ADOBE SUITE ---
            ".psd"             = "$documents\Adobe Photoshop"
            ".psb"             = "$documents\Adobe Photoshop"
            ".pdd"             = "$documents\Adobe Photoshop"
            ".ai"              = "$documents\Adobe Illustrator"
            ".ait"             = "$documents\Adobe Illustrator"
            ".eps"             = "$documents\Adobe Illustrator"
            ".indd"            = "$documents\Adobe InDesign"
            ".indt"            = "$documents\Adobe InDesign"
            ".indl"            = "$documents\Adobe InDesign"
            ".indb"            = "$documents\Adobe InDesign"
            ".xd"              = "$documents\Adobe XD"
            ".sesx"            = "$documents\Adobe Audition"
            ".fla"             = "$documents\Adobe Animate"
            ".xfl"             = "$documents\Adobe Animate"
            ".sfw"             = "$documents\Adobe Animate"
            ".lrcat"           = "$documents\Adobe Lightroom"
            ".lrtemplate"      = "$documents\Adobe Lightroom"
            ".lrprev"          = "$documents\Adobe Lightroom"

            # --- PDF / DOCUMENTS ---
            ".pdf"             = "$documents\PDFs"
            ".xps"             = "$documents\PDFs"
            ".oxps"            = "$documents\PDFs"
            ".djvu"            = "$documents\PDFs"
            ".djv"             = "$documents\PDFs"

            # --- CAD / AUTODESK / ENGINEERING ---
            ".dwg"             = "$documents\Autodesk AutoCAD"
            ".dxf"             = "$documents\Autodesk AutoCAD"
            ".dwf"             = "$documents\Autodesk AutoCAD"
            ".dwfx"            = "$documents\Autodesk AutoCAD"
            ".dws"             = "$documents\Autodesk AutoCAD"
            ".dwt"             = "$documents\Autodesk AutoCAD"
            ".max"             = "$documents\Autodesk 3ds Max"
            ".fbx"             = "$documents\Autodesk FBX"
            ".iam"             = "$documents\Autodesk Inventor"
            ".ipt"             = "$documents\Autodesk Inventor"
            ".ipj"             = "$documents\Autodesk Inventor"
            ".idw"             = "$documents\Autodesk Inventor"
            ".rvt"             = "$documents\Autodesk Revit"
            ".rfa"             = "$documents\Autodesk Revit"
            ".rft"             = "$documents\Autodesk Revit"
            ".rte"             = "$documents\Autodesk Revit"
            ".nwd"             = "$documents\Autodesk Navisworks"
            ".nwc"             = "$documents\Autodesk Navisworks"
            ".nwf"             = "$documents\Autodesk Navisworks"
            ".sat"             = "$documents\CAD\ACIS"
            ".sab"             = "$documents\CAD\ACIS"
            ".iges"            = "$documents\CAD\IGES"
            ".igs"             = "$documents\CAD\IGES"
            ".step"            = "$documents\CAD\STEP"
            ".stp"             = "$documents\CAD\STEP"
            ".stl"             = "$documents\CAD\STL 3D Print"
            ".obj"             = "$documents\CAD\OBJ 3D"
            ".3ds"             = "$documents\CAD\3DS 3D"
            ".dae"             = "$documents\CAD\Collada"
            ".ifc"             = "$documents\CAD\IFC BIM"
            ".ifcxml"          = "$documents\CAD\IFC BIM"
            ".skp"             = "$documents\SketchUp"
            ".sldprt"          = "$documents\SolidWorks"
            ".sldasm"          = "$documents\SolidWorks"
            ".slddrw"          = "$documents\SolidWorks"
            ".x_t"             = "$documents\CAD\Parasolid"
            ".x_b"             = "$documents\CAD\Parasolid"
            ".prt"             = "$documents\CAD\NX"
            ".catpart"         = "$documents\CATIA"
            ".catproduct"      = "$documents\CATIA"
            ".catdrawing"      = "$documents\CATIA"

            # --- 3D / VR / AR ---
            ".blend"           = "$documents\Blender"
            ".blend1"          = "$documents\Blender"
            ".c4d"             = "$documents\Cinema 4D"
            ".ma"              = "$documents\Autodesk Maya"
            ".mb"              = "$documents\Autodesk Maya"
            ".abc"             = "$documents\3D\Alembic"
            ".usd"             = "$documents\3D\USD"
            ".usda"            = "$documents\3D\USD"
            ".usdc"            = "$documents\3D\USD"
            ".usdz"            = "$documents\3D\USD"
            ".gltf"            = "$documents\3D\glTF"
            ".glb"             = "$documents\3D\glTF"
            ".ply"             = "$documents\3D\Point Cloud"
            ".pts"             = "$documents\3D\Point Cloud"
            ".lxo"             = "$documents\3D\Modo"
            ".lxp"             = "$documents\3D\Modo"
            ".hip"             = "$documents\3D\Houdini"
            ".hipnc"           = "$documents\3D\Houdini"
            ".hda"             = "$documents\3D\Houdini"
            ".hdanc"           = "$documents\3D\Houdini"
            ".vdb"             = "$documents\3D\OpenVDB"
            ".mtl"             = "$documents\3D\Materials"
            ".vrmesh"          = "$documents\3D\V-Ray"
            ".vrscene"         = "$documents\3D\V-Ray"
            ".rib"             = "$documents\3D\RenderMan"

            # --- GIS / GEOSPATIAL ---
            ".shp"             = "$documents\GIS\Shapefiles"
            ".shx"             = "$documents\GIS\Shapefiles"
            ".prj"             = "$documents\GIS\Shapefiles"
            ".sbn"             = "$documents\GIS\Shapefiles"
            ".sbx"             = "$documents\GIS\Shapefiles"
            ".geojson"         = "$documents\GIS\GeoJSON"
            ".topojson"        = "$documents\GIS\TopoJSON"
            ".kml"             = "$documents\GIS\KML"
            ".kmz"             = "$documents\GIS\KML"
            ".gpx"             = "$documents\GIS\GPS"
            ".tcx"             = "$documents\GIS\GPS"
            ".nmea"            = "$documents\GIS\GPS"
            ".mbtiles"         = "$documents\GIS\Tiles"
            ".tpk"             = "$documents\GIS\ArcGIS"
            ".mxd"             = "$documents\GIS\ArcGIS"
            ".mxdx"            = "$documents\GIS\ArcGIS"
            ".lyr"             = "$documents\GIS\ArcGIS"
            ".lpk"             = "$documents\GIS\ArcGIS"
            ".qgs"             = "$documents\GIS\QGIS"
            ".qgz"             = "$documents\GIS\QGIS"
            ".gpkg"            = "$documents\GIS\GeoPackage"
            ".e00"             = "$documents\GIS\E00"
            ".las"             = "$documents\GIS\LiDAR"
            ".laz"             = "$documents\GIS\LiDAR"
            ".ecw"             = "$documents\GIS\Raster"
            ".dem"             = "$documents\GIS\Terrain"
            ".hgt"             = "$documents\GIS\Terrain"
            ".dt0"             = "$documents\GIS\DTED"
            ".dt1"             = "$documents\GIS\DTED"
            ".dt2"             = "$documents\GIS\DTED"

            # --- MEDICAL / SCIENTIFIC IMAGING ---
            ".dcm"             = "$documents\Medical\DICOM"
            ".dicom"           = "$documents\Medical\DICOM"
            ".nii"             = "$documents\Medical\NIfTI"
            ".mnc"             = "$documents\Medical\MINC"
            ".mnc2"            = "$documents\Medical\MINC"
            ".mgh"             = "$documents\Medical\FreeSurfer"
            ".mgz"             = "$documents\Medical\FreeSurfer"
            ".edf"             = "$documents\Medical\EDF Biosignals"
            ".hl7"             = "$documents\Medical\HL7"
            ".cda"             = "$documents\Medical\CDA"
            ".fcs"             = "$documents\Medical\Flow Cytometry"

            # --- SCIENCE / DATA / RESEARCH ---
            ".mat"             = "$documents\Science\MATLAB"
            ".fig"             = "$documents\Science\MATLAB"
            ".nb"              = "$documents\Science\Mathematica"
            ".cdf"             = "$documents\Science\CDF"
            ".nc"              = "$documents\Science\NetCDF"
            ".hdf"             = "$documents\Science\HDF"
            ".hdf5"            = "$documents\Science\HDF5"
            ".he5"             = "$documents\Science\HDF5"
            ".fits"            = "$documents\Science\Astronomy FITS"
            ".fit"             = "$documents\Science\Astronomy FITS"
            ".fts"             = "$documents\Science\Astronomy FITS"
            ".sav"             = "$documents\Science\IDL-SPSS"
            ".spss"            = "$documents\Science\SPSS"
            ".sas7bdat"        = "$documents\Science\SAS"
            ".xpt"             = "$documents\Science\SAS"
            ".dta"             = "$documents\Science\Stata"
            ".rda"             = "$documents\Science\R"
            ".rdata"           = "$documents\Science\R"
            ".rds"             = "$documents\Science\R"
            ".jmp"             = "$documents\Science\JMP"
            ".pzfx"            = "$documents\Science\Prism"
            ".pzf"             = "$documents\Science\Prism"

            # --- MACHINE LEARNING / AI ---
            ".pt"              = "$documents\Machine Learning\PyTorch"
            ".pth"             = "$documents\Machine Learning\PyTorch"
            ".ckpt"            = "$documents\Machine Learning\Checkpoints"
            ".safetensors"     = "$documents\Machine Learning\SafeTensors"
            ".gguf"            = "$documents\Machine Learning\GGUF LLM"
            ".ggml"            = "$documents\Machine Learning\GGML"
            ".onnx"            = "$documents\Machine Learning\ONNX"
            ".tflite"          = "$documents\Machine Learning\TensorFlow Lite"
            ".pb"              = "$documents\Machine Learning\TensorFlow"
            ".h5"              = "$documents\Machine Learning\Keras"
            ".pkl"             = "$documents\Machine Learning\Pickled Models"
            ".pickle"          = "$documents\Machine Learning\Pickled Models"
            ".joblib"          = "$documents\Machine Learning\Joblib Models"
            ".mlmodel"         = "$documents\Machine Learning\CoreML"
            ".engine"          = "$documents\Machine Learning\TensorRT"
            ".trt"             = "$documents\Machine Learning\TensorRT"
            ".caffemodel"      = "$documents\Machine Learning\Caffe"
            ".prototxt"        = "$documents\Machine Learning\Caffe"
            ".params"          = "$documents\Machine Learning\MXNet"

            # --- GAME DEVELOPMENT ---
            ".unity"           = "$documents\Game Dev\Unity"
            ".unitypackage"    = "$documents\Game Dev\Unity"
            ".uasset"          = "$documents\Game Dev\Unreal Engine"
            ".umap"            = "$documents\Game Dev\Unreal Engine"
            ".upk"             = "$documents\Game Dev\Unreal Engine"
            ".pak"             = "$documents\Game Dev\PAK Archives"
            ".udk"             = "$documents\Game Dev\Unreal Engine"
            ".godot"           = "$documents\Game Dev\Godot"
            ".tscn"            = "$documents\Game Dev\Godot"
            ".tres"            = "$documents\Game Dev\Godot"
            ".gd"              = "$documents\Game Dev\Godot"
            ".gsc"             = "$documents\Game Dev\Godot"
            ".sln"             = "$documents\Game Dev\Visual Studio"
            ".csproj"          = "$documents\Game Dev\Visual Studio"
            ".rpgproject"      = "$documents\Game Dev\RPG Maker"
            ".rvdata2"         = "$documents\Game Dev\RPG Maker"
            ".twine"           = "$documents\Game Dev\Twine"
            ".twee"            = "$documents\Game Dev\Twine"
            ".gbx"             = "$documents\Game Dev\ManiaPlanet"
            ".smx"             = "$documents\Game Dev\StepMania"
            ".sm"              = "$documents\Game Dev\StepMania"
            ".ssc"             = "$documents\Game Dev\StepMania"

            # --- EMULATION / ROM ---
            ".nes"             = "$documents\Emulation\NES"
            ".smc"             = "$documents\Emulation\SNES"
            ".sfc"             = "$documents\Emulation\SNES"
            ".gb"              = "$documents\Emulation\Game Boy"
            ".gbc"             = "$documents\Emulation\Game Boy Color"
            ".gba"             = "$documents\Emulation\Game Boy Advance"
            ".nds"             = "$documents\Emulation\Nintendo DS"
            ".xci"             = "$documents\Emulation\Nintendo Switch"
            ".nsp"             = "$documents\Emulation\Nintendo Switch"
            ".z64"             = "$documents\Emulation\Nintendo 64"
            ".n64"             = "$documents\Emulation\Nintendo 64"
            ".v64"             = "$documents\Emulation\Nintendo 64"
            ".gcm"             = "$documents\Emulation\GameCube"
            ".wad"             = "$documents\Emulation\Wii"
            ".rvz"             = "$documents\Emulation\GameCube-Wii"
            ".wbfs"            = "$documents\Emulation\Wii"
            ".gen"             = "$documents\Emulation\Sega Genesis"
            ".smd"             = "$documents\Emulation\Sega Genesis"
            ".32x"             = "$documents\Emulation\Sega 32X"
            ".gg"              = "$documents\Emulation\Game Gear"
            ".sms"             = "$documents\Emulation\Sega Master System"
            ".pce"             = "$documents\Emulation\PC Engine"
            ".cue"             = "$documents\Emulation\Disc Images"
            ".ccd"             = "$documents\Emulation\Disc Images"
            ".mds"             = "$documents\Emulation\Disc Images"
            ".nrg"             = "$documents\Emulation\Disc Images"
            ".chd"             = "$documents\Emulation\CHD Disc Images"
            ".pbp"             = "$documents\Emulation\PSP"
            ".cso"             = "$documents\Emulation\PSP"

            # --- SECURITY / CERTIFICATES / KEYS ---
            ".pem"             = "$documents\Security\Certificates"
            ".crt"             = "$documents\Security\Certificates"
            ".cer"             = "$documents\Security\Certificates"
            ".der"             = "$documents\Security\Certificates"
            ".pfx"             = "$documents\Security\PFX Keystores"
            ".p12"             = "$documents\Security\PFX Keystores"
            ".p7b"             = "$documents\Security\PKCS7"
            ".p7c"             = "$documents\Security\PKCS7"
            ".p7r"             = "$documents\Security\PKCS7"
            ".csr"             = "$documents\Security\CSR"
            ".ppk"             = "$documents\Security\PuTTY Keys"
            ".jks"             = "$documents\Security\Java Keystores"
            ".keystore"        = "$documents\Security\Java Keystores"
            ".asc"             = "$documents\Security\PGP"
            ".gpg"             = "$documents\Security\PGP"
            ".sig"             = "$documents\Security\Signatures"
            ".ovpn"            = "$documents\Security\VPN Configs"
            ".pcap"            = "$documents\Security\Network Captures"
            ".pcapng"          = "$documents\Security\Network Captures"
            ".etl"             = "$documents\Security\Event Traces"

            # --- CRYPTO / BLOCKCHAIN ---
            ".wallet"          = "$documents\Crypto\Wallets"
            ".aes"             = "$documents\Crypto\Encrypted Files"
            ".enc"             = "$documents\Crypto\Encrypted Files"
            ".vault"           = "$documents\Crypto\Vaults"

            # --- FIRMWARE / EMBEDDED ---
            ".hex"             = "$documents\Firmware\Intel HEX"
            ".bin"             = "$documents\Firmware\Binary"
            ".elf"             = "$documents\Firmware\ELF"
            ".axf"             = "$documents\Firmware\ARM"
            ".srec"            = "$documents\Firmware\Motorola SREC"
            ".s19"             = "$documents\Firmware\Motorola SREC"
            ".s28"             = "$documents\Firmware\Motorola SREC"
            ".s37"             = "$documents\Firmware\Motorola SREC"
            ".dfu"             = "$documents\Firmware\DFU"
            ".fw"              = "$documents\Firmware\Generic"
            ".rom"             = "$documents\Firmware\ROM"
            ".bios"            = "$documents\Firmware\BIOS"
            ".efi"             = "$documents\Firmware\UEFI"
            ".fud"             = "$documents\Firmware\Updates"

            # --- DATABASE ---
            ".db"              = "$documents\Database"
            ".sqlite"          = "$documents\Database\SQLite"
            ".sqlite3"         = "$documents\Database\SQLite"
            ".db3"             = "$documents\Database\SQLite"
            ".s3db"            = "$documents\Database\SQLite"
            ".sl3"             = "$documents\Database\SQLite"
            ".mdf"             = "$documents\Database\SQL Server"
            ".ldf"             = "$documents\Database\SQL Server"
            ".ndf"             = "$documents\Database\SQL Server"
            ".dump"            = "$documents\Database\Dumps"
            ".sql"             = "$documents\Database\SQL Scripts"
            ".dmp"             = "$documents\Database\Oracle Dumps"
            ".frm"             = "$documents\Database\MySQL"
            ".ibd"             = "$documents\Database\MySQL"
            ".dbf"             = "$documents\Database\dBASE"
            ".pdb"             = "$documents\Database\PDB"
            ".ntf"             = "$documents\Database\Lotus Notes"
            ".fp7"             = "$documents\Database\FileMaker"
            ".fmp12"           = "$documents\Database\FileMaker"

            # --- VIRTUAL MACHINE / DISK IMAGES ---
            ".vhd"             = "$documents\Virtual Machines\Hyper-V"
            ".vhdx"            = "$documents\Virtual Machines\Hyper-V"
            ".vmdk"            = "$documents\Virtual Machines\VMware"
            ".vmx"             = "$documents\Virtual Machines\VMware"
            ".vmsd"            = "$documents\Virtual Machines\VMware"
            ".nvram"           = "$documents\Virtual Machines\VMware"
            ".ova"             = "$documents\Virtual Machines\OVA"
            ".ovf"             = "$documents\Virtual Machines\OVF"
            ".vdi"             = "$documents\Virtual Machines\VirtualBox"
            ".vbox"            = "$documents\Virtual Machines\VirtualBox"
            ".qcow"            = "$documents\Virtual Machines\QEMU"
            ".qcow2"           = "$documents\Virtual Machines\QEMU"
            ".img"             = "$documents\Virtual Machines\Raw Disk Images"
            ".hdd"             = "$documents\Virtual Machines\Parallels"
            ".pvs"             = "$documents\Virtual Machines\Parallels"
            ".pvm"             = "$documents\Virtual Machines\Parallels"
            ".wim"             = "$documents\Virtual Machines\Windows Images"
            ".esd"             = "$documents\Virtual Machines\Windows Images"

            # --- PACKAGES / CONTAINERS ---
            ".deb"             = "$documents\Packages\Debian"
            ".rpm"             = "$documents\Packages\RPM"
            ".pkg"             = "$documents\Packages\macOS"
            ".flatpak"         = "$documents\Packages\Flatpak"
            ".snap"            = "$documents\Packages\Snap"
            ".appimage"        = "$documents\Packages\AppImage"
            ".nupkg"           = "$documents\Packages\NuGet"
            ".jar"             = "$documents\Packages\Java JAR"
            ".war"             = "$documents\Packages\Java WAR"
            ".ear"             = "$documents\Packages\Java EAR"
            ".whl"             = "$documents\Packages\Python Wheel"
            ".egg"             = "$documents\Packages\Python Egg"
            ".gem"             = "$documents\Packages\Ruby Gem"
            ".crx"             = "$documents\Packages\Chrome Extensions"
            ".xpi"             = "$documents\Packages\Firefox Extensions"
            ".vsix"            = "$documents\Packages\VS Code Extensions"
            ".ipa"             = "$documents\Packages\iOS Apps"
            ".apk"             = "$documents\Packages\Android Apps"
            ".aab"             = "$documents\Packages\Android Bundles"

            # --- MOBILE ---
            ".mobileprovision" = "$documents\Mobile\iOS Provisioning"
            ".p8"              = "$documents\Mobile\iOS Keys"
            ".xcarchive"       = "$documents\Mobile\Xcode Archives"
            ".xcworkspace"     = "$documents\Mobile\Xcode Projects"
            ".xcodeproj"       = "$documents\Mobile\Xcode Projects"
            ".pbxproj"         = "$documents\Mobile\Xcode Config"

            # --- NETWORK / DEVOPS / CONFIG ---
            ".yaml"            = "$documents\Network\YAML Config"
            ".yml"             = "$documents\Network\YAML Config"
            ".toml"            = "$documents\Network\TOML Config"
            ".env"             = "$documents\Network\Environment"
            ".htaccess"        = "$documents\Network\Apache Config"
            ".nginx"           = "$documents\Network\NGINX Config"
            ".dockerignore"    = "$documents\Network\Docker"
            ".tfvars"          = "$documents\Network\Terraform"
            ".tf"              = "$documents\Network\Terraform"
            ".bicep"           = "$documents\Network\Azure Bicep"
            ".hcl"             = "$documents\Network\HCL"

            # --- EBOOKS ---
            ".epub"            = "$documents\eBooks"
            ".mobi"            = "$documents\eBooks"
            ".azw"             = "$documents\eBooks\Kindle"
            ".azw3"            = "$documents\eBooks\Kindle"
            ".kfx"             = "$documents\eBooks\Kindle"
            ".cbz"             = "$documents\eBooks\Comics"
            ".cbr"             = "$documents\eBooks\Comics"
            ".cbt"             = "$documents\eBooks\Comics"
            ".cb7"             = "$documents\eBooks\Comics"
            ".cbw"             = "$documents\eBooks\Comics"
            ".lit"             = "$documents\eBooks"
            ".lrf"             = "$documents\eBooks\Sony Reader"
            ".prc"             = "$documents\eBooks"
            ".fb2"             = "$documents\eBooks\FictionBook"
            ".ibooks"          = "$documents\eBooks\iBooks"
            ".opds"            = "$documents\eBooks"
            ".ncx"             = "$documents\eBooks"

            # --- FONTS ---
            ".ttf"             = "$documents\Fonts"
            ".otf"             = "$documents\Fonts"
            ".woff"            = "$documents\Fonts"
            ".woff2"           = "$documents\Fonts"
            ".eot"             = "$documents\Fonts"
            ".fnt"             = "$documents\Fonts"
            ".fon"             = "$documents\Fonts"
            ".pfm"             = "$documents\Fonts"
            ".pfb"             = "$documents\Fonts"
            ".afm"             = "$documents\Fonts"
            ".bdf"             = "$documents\Fonts"
            ".pcf"             = "$documents\Fonts"
            ".snf"             = "$documents\Fonts"
            ".suit"            = "$documents\Fonts"
            ".dfont"           = "$documents\Fonts"

            # --- ARCHIVES / COMPRESSED ---
            ".zip"             = "$documents\Archives"
            ".rar"             = "$documents\Archives"
            ".7z"              = "$documents\Archives"
            ".tar"             = "$documents\Archives"
            ".gz"              = "$documents\Archives"
            ".bz2"             = "$documents\Archives"
            ".xz"              = "$documents\Archives"
            ".lz"              = "$documents\Archives"
            ".lz4"             = "$documents\Archives"
            ".lzma"            = "$documents\Archives"
            ".zst"             = "$documents\Archives"
            ".zstd"            = "$documents\Archives"
            ".tgz"             = "$documents\Archives"
            ".tbz2"            = "$documents\Archives"
            ".txz"             = "$documents\Archives"
            ".tlz"             = "$documents\Archives"
            ".cab"             = "$documents\Archives\CAB"
            ".z"               = "$documents\Archives\Compress"
            ".arc"             = "$documents\Archives\ARC"
            ".arj"             = "$documents\Archives\ARJ"
            ".lha"             = "$documents\Archives\LHA"
            ".lzh"             = "$documents\Archives\LZH"
            ".ace"             = "$documents\Archives\ACE"
            ".zpaq"            = "$documents\Archives\ZPAQ"

            # --- EXECUTABLES / INSTALLERS ---
            ".exe"             = "$documents\Executables"
            ".msi"             = "$documents\Executables"
            ".dmg"             = "$documents\Executables"
            ".run"             = "$documents\Executables"
            ".com"             = "$documents\Executables\Legacy DOS"
            ".pif"             = "$documents\Executables\Legacy DOS"
            ".scr"             = "$documents\Executables\Screensavers"
            ".cpl"             = "$documents\Executables\Control Panel"
            ".gadget"          = "$documents\Executables\Gadgets"
            ".appref-ms"       = "$documents\Executables\ClickOnce"

            # --- CODE / PROGRAMMING ---
            ".py"              = "$documents\Code\Python"
            ".pyw"             = "$documents\Code\Python"
            ".pyi"             = "$documents\Code\Python"
            ".ipynb"           = "$documents\Code\Jupyter Notebooks"
            ".js"              = "$documents\Code\JavaScript"
            ".mjs"             = "$documents\Code\JavaScript"
            ".cjs"             = "$documents\Code\JavaScript"
            ".tsx"             = "$documents\Code\TypeScript"
            ".jsx"             = "$documents\Code\JavaScript React"
            ".vue"             = "$documents\Code\Vue"
            ".svelte"          = "$documents\Code\Svelte"
            ".astro"           = "$documents\Code\Astro"
            ".cpp"             = "$documents\Code\C-CPP"
            ".cc"              = "$documents\Code\C-CPP"
            ".cxx"             = "$documents\Code\C-CPP"
            ".c"               = "$documents\Code\C-CPP"
            ".h"               = "$documents\Code\C-CPP"
            ".hpp"             = "$documents\Code\C-CPP"
            ".hxx"             = "$documents\Code\C-CPP"
            ".cs"              = "$documents\Code\CSharp"
            ".vb"              = "$documents\Code\VB.NET"
            ".fs"              = "$documents\Code\FSharp"
            ".fsi"             = "$documents\Code\FSharp"
            ".fsx"             = "$documents\Code\FSharp"
            ".java"            = "$documents\Code\Java"
            ".kt"              = "$documents\Code\Kotlin"
            ".kts"             = "$documents\Code\Kotlin"
            ".scala"           = "$documents\Code\Scala"
            ".sc"              = "$documents\Code\Scala"
            ".groovy"          = "$documents\Code\Groovy"
            ".gradle"          = "$documents\Code\Gradle"
            ".clj"             = "$documents\Code\Clojure"
            ".cljs"            = "$documents\Code\ClojureScript"
            ".go"              = "$documents\Code\Go"
            ".rs"              = "$documents\Code\Rust"
            ".rlib"            = "$documents\Code\Rust"
            ".swift"           = "$documents\Code\Swift"
            ".m"               = "$documents\Code\Objective-C"
            ".mm"              = "$documents\Code\Objective-C"
            ".rb"              = "$documents\Code\Ruby"
            ".erb"             = "$documents\Code\Ruby"
            ".gemspec"         = "$documents\Code\Ruby"
            ".php"             = "$documents\Code\PHP"
            ".php3"            = "$documents\Code\PHP"
            ".php4"            = "$documents\Code\PHP"
            ".php5"            = "$documents\Code\PHP"
            ".php7"            = "$documents\Code\PHP"
            ".phtml"           = "$documents\Code\PHP"
            ".pl"              = "$documents\Code\Perl"
            ".pm"              = "$documents\Code\Perl"
            ".pod"             = "$documents\Code\Perl"
            ".lua"             = "$documents\Code\Lua"
            ".r"               = "$documents\Code\R"
            ".rmd"             = "$documents\Code\R Markdown"
            ".jl"              = "$documents\Code\Julia"
            ".hs"              = "$documents\Code\Haskell"
            ".lhs"             = "$documents\Code\Haskell"
            ".elm"             = "$documents\Code\Elm"
            ".ex"              = "$documents\Code\Elixir"
            ".exs"             = "$documents\Code\Elixir"
            ".erl"             = "$documents\Code\Erlang"
            ".hrl"             = "$documents\Code\Erlang"
            ".lisp"            = "$documents\Code\Lisp"
            ".lsp"             = "$documents\Code\Lisp"
            ".cl"              = "$documents\Code\Lisp"
            ".scm"             = "$documents\Code\Scheme"
            ".rkt"             = "$documents\Code\Racket"
            ".ml"              = "$documents\Code\OCaml"
            ".mli"             = "$documents\Code\OCaml"
            ".d"               = "$documents\Code\D"
            ".nim"             = "$documents\Code\Nim"
            ".nims"            = "$documents\Code\Nim"
            ".zig"             = "$documents\Code\Zig"
            ".v"               = "$documents\Code\Verilog"
            ".sv"              = "$documents\Code\SystemVerilog"
            ".vhdl"            = "$documents\Code\VHDL"
            ".asm"             = "$documents\Code\Assembly"
            ".s"               = "$documents\Code\Assembly"
            ".nasm"            = "$documents\Code\Assembly"
            ".a51"             = "$documents\Code\Assembly"
            ".ps1"             = "$documents\Code\PowerShell"
            ".psm1"            = "$documents\Code\PowerShell"
            ".psd1"            = "$documents\Code\PowerShell"
            ".ps1xml"          = "$documents\Code\PowerShell"
            ".bat"             = "$documents\Code\Batch"
            ".cmd"             = "$documents\Code\Batch"
            ".bash"            = "$documents\Code\Bash"
            ".sh"              = "$documents\Code\Shell"
            ".zsh"             = "$documents\Code\Shell"
            ".fish"            = "$documents\Code\Shell"
            ".ksh"             = "$documents\Code\Shell"
            ".csh"             = "$documents\Code\Shell"
            ".tcsh"            = "$documents\Code\Shell"
            ".awk"             = "$documents\Code\AWK"
            ".sed"             = "$documents\Code\SED"
            ".html"            = "$documents\Code\Web"
            ".htm"             = "$documents\Code\Web"
            ".xhtml"           = "$documents\Code\Web"
            ".css"             = "$documents\Code\Web"
            ".scss"            = "$documents\Code\Web"
            ".sass"            = "$documents\Code\Web"
            ".less"            = "$documents\Code\Web"
            ".styl"            = "$documents\Code\Web"
            ".wasm"            = "$documents\Code\WebAssembly"
            ".wat"             = "$documents\Code\WebAssembly"
            ".sol"             = "$documents\Code\Solidity"
            ".vy"              = "$documents\Code\Vyper"
            ".cairo"           = "$documents\Code\Cairo"
            ".move"            = "$documents\Code\Move"
            ".aleo"            = "$documents\Code\Aleo"

            # --- WEB / API / DATA ---
            ".json"            = "$documents\Data\JSON"
            ".jsonld"          = "$documents\Data\JSON-LD"
            ".xml"             = "$documents\Data\XML"
            ".xsd"             = "$documents\Data\XML Schema"
            ".xsl"             = "$documents\Data\XSLT"
            ".xslt"            = "$documents\Data\XSLT"
            ".dtd"             = "$documents\Data\DTD"
            ".rss"             = "$documents\Data\RSS"
            ".atom"            = "$documents\Data\Atom"
            ".graphql"         = "$documents\Data\GraphQL"
            ".gql"             = "$documents\Data\GraphQL"
            ".proto"           = "$documents\Data\Protobuf"
            ".avro"            = "$documents\Data\Avro"
            ".parquet"         = "$documents\Data\Parquet"
            ".orc"             = "$documents\Data\ORC"
            ".feather"         = "$documents\Data\Feather"
            ".arrow"           = "$documents\Data\Arrow"
            ".msgpack"         = "$documents\Data\MessagePack"
            ".cbor"            = "$documents\Data\CBOR"
            ".bson"            = "$documents\Data\BSON"
            ".ndjson"          = "$documents\Data\NDJSON"
            ".jsonl"           = "$documents\Data\JSONL"
            ".tsv"             = "$documents\Data\TSV"
            ".psv"             = "$documents\Data\PSV"

            # --- TEXT / MARKDOWN / DOCS ---
            ".txt"             = "$documents\Text"
            ".text"            = "$documents\Text"
            ".nfo"             = "$documents\Text\NFO Info"
            ".diz"             = "$documents\Text\DIZ"
            ".md"              = "$documents\Text\Markdown"
            ".markdown"        = "$documents\Text\Markdown"
            ".mdown"           = "$documents\Text\Markdown"
            ".mkdn"            = "$documents\Text\Markdown"
            ".rst"             = "$documents\Text\reStructuredText"
            ".adoc"            = "$documents\Text\AsciiDoc"
            ".asciidoc"        = "$documents\Text\AsciiDoc"
            ".org"             = "$documents\Text\Org Mode"
            ".wiki"            = "$documents\Text\Wiki"
            ".tex"             = "$documents\Text\LaTeX"
            ".ltx"             = "$documents\Text\LaTeX"
            ".bib"             = "$documents\Text\BibTeX"
            ".sty"             = "$documents\Text\LaTeX"
            ".cls"             = "$documents\Text\LaTeX"
            ".man"             = "$documents\Text\Man Pages"

            # --- SYSTEM / CONFIG / LOGS ---
            ".ini"             = "$documents\System\Config"
            ".cfg"             = "$documents\System\Config"
            ".conf"            = "$documents\System\Config"
            ".inf"             = "$documents\System\INF"
            ".reg"             = "$documents\System\Registry"
            ".log"             = "$documents\System\Logs"
            ".log1"            = "$documents\System\Logs"
            ".log2"            = "$documents\System\Logs"
            ".err"             = "$documents\System\Logs"
            ".out"             = "$documents\System\Logs"
            ".trace"           = "$documents\System\Logs"
            ".tmp"             = "$documents\System\Temp"
            ".temp"            = "$documents\System\Temp"
            ".bak"             = "$documents\System\Backups"
            ".backup"          = "$documents\System\Backups"
            ".old"             = "$documents\System\Backups"
            ".orig"            = "$documents\System\Backups"
            ".swap"            = "$documents\System\Temp"
            ".swp"             = "$documents\System\Temp"
            ".lock"            = "$documents\System\Temp"
            ".pid"             = "$documents\System\Temp"
            ".cache"           = "$documents\System\Cache"
            ".lnk"             = "$documents\Shortcuts"
            ".url"             = "$documents\Shortcuts\URLs"
            ".webloc"          = "$documents\Shortcuts\URLs"
            ".desktop"         = "$documents\Shortcuts\Linux Desktop"
            ".themepack"       = "$documents\System\Themes"
            ".msstyles"        = "$documents\System\Themes"
            ".deskthemepack"   = "$documents\System\Themes"

            # --- TORRENTS / P2P ---
            ".torrent"         = "$documents\Torrents"
            ".magnet"          = "$documents\Torrents"

            # --- LEGACY OFFICE ---
            ".wks"             = "$documents\Legacy\Lotus Works"
            ".123"             = "$documents\Legacy\Lotus 1-2-3"
            ".wk1"             = "$documents\Legacy\Lotus 1-2-3"
            ".wk4"             = "$documents\Legacy\Lotus 1-2-3"
            ".wq1"             = "$documents\Legacy\Quattro Pro"
            ".wq2"             = "$documents\Legacy\Quattro Pro"
            ".wb1"             = "$documents\Legacy\Quattro Pro"
            ".wb2"             = "$documents\Legacy\Quattro Pro"
            ".wb3"             = "$documents\Legacy\Quattro Pro"
            ".mcw"             = "$documents\Legacy\Mac Word"
            ".mw"              = "$documents\Legacy\Mac Word"
            ".cwk"             = "$documents\Legacy\ClarisWorks"
            ".sdw"             = "$documents\Legacy\StarOffice Writer"
            ".sdc"             = "$documents\Legacy\StarOffice Calc"
            ".sdd"             = "$documents\Legacy\StarOffice Impress"
            ".sdp"             = "$documents\Legacy\StarOffice Impress"
            ".abw"             = "$documents\Legacy\AbiWord"
            ".zabw"            = "$documents\Legacy\AbiWord"
            ".gnumeric"        = "$documents\Legacy\Gnumeric"
        }

        # ===============================================================
        # IN-PROGRESS EXTENSION FILTER
        # ===============================================================
        $inProgressExtensions = @(
            "tmp", "crdownload", "part", "opdownload", "partial",
            "!ut", "bc!", "download", "filepart", "dlm", "dtapart",
            "downloading", "incomplete", "td", "unfinished",
            "idm", "aria2"
        )
        $inProgressPattern = ($inProgressExtensions -join "|")

        Write-Log "Extension map loaded: $($fileTypes.Count) unique extensions." "INFO"

        # ===============================================================
        # MAIN PROCESSING LOOP
        # ===============================================================
        $allFiles = Get-ChildItem -Path $downloads -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -notmatch $inProgressPattern }

        Write-Log "Files found to evaluate: $($allFiles.Count)" "INFO"

        $allFiles | ForEach-Object {
            try {
                if (ShouldExclude $_.FullName) {
                    Write-Log "EXCLUDED: $($_.Name)" "SKIP"
                    $skippedCount++
                    return
                }
                if (IsFileInUse $_.FullName) {
                    Write-Log "IN-USE (skipped): $($_.Name)" "SKIP"
                    $skippedCount++
                    return
                }

                $ext = $_.Extension.ToLower()
                $destFolder = $null

                if ($fileTypes.ContainsKey($ext)) {
                    $destFolder = $fileTypes[$ext]
                }
                elseif ($ext -eq "" -or $ext -eq ".") {
                    $destFolder = "$documents\Other Files\Uncategorized\NO EXTENSION"
                }
                else {
                    $extName = $ext.TrimStart(".").ToUpper()
                    $destFolder = "$documents\Other Files\Uncategorized\$extName"
                }

                if (!(Test-Path $destFolder)) {
                    New-Item -ItemType Directory -Path $destFolder -Force | Out-Null
                    Write-Log "Created folder: $destFolder" "INFO"
                }

                $destPath = Join-Path $destFolder $_.Name
                $counter = 1

                while (Test-Path $destPath) {
                    $existingHash = Get-FileHash-Custom $destPath
                    $incomingHash = Get-FileHash-Custom $_.FullName
                    if ($existingHash -and $incomingHash -and ($existingHash -eq $incomingHash)) {
                        Write-Log "DEDUP -- deleted duplicate: $($_.Name)" "DEDUP"
                        Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
                        $dedupCount++
                        return
                    }
                    $newName = "$([System.IO.Path]::GetFileNameWithoutExtension($_.Name)) ($counter)$ext"
                    $destPath = Join-Path $destFolder $newName
                    $counter++
                }

                Move-Item -LiteralPath $_.FullName -Destination $destPath -Force -ErrorAction SilentlyContinue
                Write-Log "MOVED: $($_.Name)  ->  $destFolder" "MOVE"
                $movedCount++

            }
            catch {
                Write-Log "ERROR processing $($_.Name): $_" "ERROR"
                $errorCount++
            }
        }

        # ===============================================================
        # MEDIA DATE SORTING
        # ===============================================================
        Write-Log "Starting media date sorting..." "INFO"

        $mediaExts = @{
            $pictures = @(".jpg", ".jpeg", ".jpe", ".png", ".gif", ".bmp", ".tiff", ".tif", ".webp",
                ".heic", ".heif", ".avif", ".jxl", ".hdr", ".exr", ".raw", ".cr2", ".cr3",
                ".nef", ".nrw", ".arw", ".dng", ".orf", ".raf", ".rw2", ".pef", ".srw",
                ".x3f", ".3fr", ".kdc", ".dcr", ".erf", ".mrw", ".mef", ".mos", ".bay",
                ".cap", ".iiq", ".rwz", ".rwl", ".nex")
            $music    = @(".mp3", ".wav", ".flac", ".aac", ".ogg", ".wma", ".m4a", ".aiff", ".aif",
                ".alac", ".opus", ".mid", ".midi", ".amr", ".ape", ".au", ".wv", ".tta",
                ".mpc", ".mp2", ".ac3", ".dts")
            $videos   = @(".mp4", ".avi", ".mkv", ".mov", ".wmv", ".flv", ".webm", ".m4v", ".mpeg",
                ".mpg", ".mpe", ".3gp", ".3g2", ".vob", ".ogv", ".ts", ".mts", ".m2ts",
                ".divx", ".xvid", ".asf", ".rmvb", ".dv", ".qt")
        }

        foreach ($folder in $mediaExts.Keys) {
            $extList = $mediaExts[$folder]
            Get-ChildItem -Path $folder -File -ErrorAction SilentlyContinue |
            Where-Object { $extList -contains $_.Extension.ToLower() } |
            ForEach-Object {
                if ($_.DirectoryName -eq $folder) {
                    $fDate = if ($_.CreationTime) { $_.CreationTime } else { $_.LastWriteTime }
                    $invYear = 9999 - $fDate.Year
                    $folderName = "[{0:D4}] $($fDate.ToString('MMM-dd-yy'))" -f $invYear
                    $target = Join-Path $folder $folderName
                    if (!(Test-Path $target)) {
                        New-Item -ItemType Directory -Path $target -Force | Out-Null
                    }
                    Move-Item -LiteralPath $_.FullName -Destination $target -Force -ErrorAction SilentlyContinue
                    Write-Log "DATE-SORTED: $($_.Name)  ->  $target" "MOVE"
                }
            }
        }

        # ===============================================================
        # CLEANUP -- 5-PASS EMPTY FOLDER REMOVAL
        # ===============================================================
        Write-Log "Running empty-folder cleanup (5 passes)..." "CLEAN"
        for ($i = 0; $i -lt 5; $i++) {
            $removed = @(Get-ChildItem -Path $downloads -Directory -Recurse -ErrorAction SilentlyContinue |
                Where-Object { (Get-ChildItem $_.FullName -Recurse -File -ErrorAction SilentlyContinue).Count -eq 0 })
            foreach ($dir in $removed) {
                Remove-Item -LiteralPath $dir.FullName -Recurse -Force -ErrorAction SilentlyContinue
                Write-Log "Removed empty folder: $($dir.FullName)" "CLEAN"
            }
        }

        # ===============================================================
        # CYCLE SUMMARY
        # ===============================================================
        $elapsed = [Math]::Round(((Get-Date) - $CycleStart).TotalSeconds, 1)
        Write-Log "===== CYCLE $CycleCount COMPLETE | Moved: $movedCount | Skipped: $skippedCount | Deduped: $dedupCount | Errors: $errorCount | Elapsed: ${elapsed}s =====" "CYCLE"

    }
    catch {
        Write-Log "FATAL CYCLE ERROR: $_" "ERROR"
    }

    Write-Log "Sleeping 300s until next cycle..." "INFO"
    Start-Sleep -Seconds 300
}
