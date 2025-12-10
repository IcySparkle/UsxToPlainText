# =====================================================================
#  UsxToPlainText.ps1
#  Converts USX, USFM, and SFM files into clean plain-text suitable
#  for flowing into InDesign.
#
#  - USX: XML walker with verse extraction + poetry handling
#  - USFM/SFM: Marker parser with identical verse + poetry output
#
#  Usage:
#     .\UsxToPlainText.ps1 "file.usx"
#     .\UsxToPlainText.ps1 "file.usfm"
#     .\UsxToPlainText.ps1 "file.sfm"
#     .\UsxToPlainText.ps1 "folder_path"
#     .\UsxToPlainText.ps1 "folder_path" "output_folder"
#
# =====================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ------------------------- ARGUMENT HANDLING -------------------------

if ($args.Count -lt 1) {
    throw "Usage: .\UsxToPlainText.ps1 <InputPath> [OutputFolder]"
}

$InputPath    = $args[0]
$OutputFolder = if ($args.Count -ge 2) { $args[1] } else { $null }

# ------------------------------ HELPERS ------------------------------

function Normalize-Whitespace {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return '' }
    $t = [regex]::Replace($Text, '\s+', ' ')
    return $t.Trim()
}

function Get-AttrValue {
    param(
        [System.Xml.XmlNode]$Node,
        [string]$Name
    )
    if ($Node -and $Node.Attributes[$Name]) { return $Node.Attributes[$Name].Value }
    return $null
}

# -------------------- USX INLINE + VERSE WALKER ---------------------

function Build-ParaRawTextWithVerseMarkers {
    <#
        Returns text with embedded verse markers:
            <<v:N>>
        - Skips <note>
        - Skips <char style="sup">
        - Removes inline tags (char, etc.)
    #>
    param([System.Xml.XmlElement]$Para)

    $sb = New-Object System.Text.StringBuilder

    $walker = {
        param([System.Xml.XmlNode]$Node)

        if (-not $Node) { return }

        if ($Node.NodeType -eq 'Text') {
            [void]$sb.Append($Node.Value)
            return
        }

        if ($Node.NodeType -ne 'Element') { return }

        switch ($Node.LocalName) {

            'note' {
                # skip entire note
                return
            }

            'verse' {
                $n = Get-AttrValue $Node 'number'
                if ($n) { [void]$sb.Append(" <<v:$n>> ") }
                return
            }

            'char' {
                # skip superscripts completely
                $style = Get-AttrValue $Node 'style'
                if ($style -eq 'sup') {
                    return
                }
                # all other char styles: flatten, keep inner text
                foreach ($c in $Node.ChildNodes) { & $walker $c }
                return
            }

            default {
                foreach ($c in $Node.ChildNodes) { & $walker $c }
            }
        }
    }

    foreach ($c in $Para.ChildNodes) { & $walker $c }

    return Normalize-Whitespace $sb.ToString()
}

function Get-HeadingText {
    param([System.Xml.XmlElement]$Para)
    $raw = Build-ParaRawTextWithVerseMarkers $Para
    if (-not $raw) { return '' }
    $clean = [regex]::Replace($raw, '<<v:\d+>>', '')
    return Normalize-Whitespace $clean
}

function Get-ParaSegments {
    param(
        [System.Xml.XmlElement]$Para,
        [ref]$HasVerseStarts
    )

    $segments = @()
    $HasVerseStarts.Value = $false

    $raw = Build-ParaRawTextWithVerseMarkers $Para
    if (-not $raw) { return @() }

    $matches = [regex]::Matches($raw, '<<v:(\d+)>>')
    if ($matches.Count -eq 0) { return @() }

    $HasVerseStarts.Value = $true

    for ($i = 0; $i -lt $matches.Count; $i++) {

        $v = $matches[$i].Groups[1].Value
        $start = $matches[$i].Index + $matches[$i].Length

        if ($i -lt $matches.Count - 1) {
            $end = $matches[$i+1].Index
        } else {
            $end = $raw.Length
        }

        $chunk = ''
        if ($end -gt $start) { $chunk = $raw.Substring($start, $end - $start) }
        $chunk = Normalize-Whitespace $chunk

        if ($chunk) {
            $segments += [pscustomobject]@{
                Verse = $v
                Text  = $chunk
            }
        }
    }

    return $segments
}

# --------------------------- USX PROCESSOR ---------------------------

function Convert-UsxFileToPlainText {
    param([string]$FilePath,[string]$OutputFolder)

    Write-Host "Processing (USX) $FilePath"

    $xmlTxt = Get-Content -LiteralPath $FilePath -Raw -Encoding UTF8
    [xml]$xml = $xmlTxt

    $usx = $xml.usx
    if (-not $usx) { throw "Invalid USX file (no <usx> root): $FilePath" }

    $inMain = $false
    $lines  = @()

    $heading = @('s','s1','s2','s3','sp','ms','mr')
    $poetry  = @('q','q1','q2','q3','q4')          # USX poetry styles
    $prose   = @('m','p','pi')
    $textAll = $prose + $poetry

    $nodes = $usx.SelectNodes('.//chapter | .//para')

    foreach ($node in $nodes) {
        switch ($node.LocalName) {

            'chapter' {
                $inMain = $true
                $n = Get-AttrValue $node 'number'
                if ($n) { $lines += $n }
            }

            'para' {
                if (-not $inMain) { break }

                $style = Get-AttrValue $node 'style'
                if (-not $style) { break }

                if ($heading -contains $style) {
                    $t = Get-HeadingText $node
                    if ($t) { $lines += $t }
                }
                elseif ($textAll -contains $style) {

                    $has = $false
                    $segs = @(Get-ParaSegments $node ([ref]$has))

                    if ($has -and $segs.Count -gt 0) {

                        if ($poetry -contains $style) {
                            # Poetry: one line per verse
                            foreach ($s in $segs) {
                                $line = "$($s.Verse) $($s.Text)"
                                if ($line) { $lines += $line }
                            }
                        }
                        else {
                            # Prose: all verses of para on one line
                            $parts = $segs | ForEach-Object { "$($_.Verse) $($_.Text)" }
                            $line  = ($parts -join ' ')
                            if ($line) { $lines += $line }
                        }

                    }
                    else {
                        # Continuation paragraph (no verse start)
                        $raw = Build-ParaRawTextWithVerseMarkers $node
                        $clean = Normalize-Whitespace([regex]::Replace($raw,'<<v:\d+>>',''))
                        if ($clean) { $lines += $clean }
                    }
                }
            }
        }
    }

    # output folder
    if ($OutputFolder) {
        if (-not (Test-Path $OutputFolder)) {
            New-Item -ItemType Directory -Path $OutputFolder | Out-Null
        }
        $outDir = (Resolve-Path $OutputFolder).Path
    } else {
        $outDir = Split-Path (Resolve-Path $FilePath).Path -Parent
    }

    $base = [IO.Path]::GetFileNameWithoutExtension($FilePath)
    $outPath = Join-Path $outDir "$base.txt"

    $enc = New-Object System.Text.UTF8Encoding($true)
    [IO.File]::WriteAllLines($outPath, $lines, $enc)

    Write-Host "  -> Wrote $outPath"
}

# ---------------------- USFM / SFM PROCESSOR -------------------------

function Clean-UsfmText {
    param([string]$Text)
    if (-not $Text) { return '' }

    $t = $Text

    # remove footnotes \f ... \f* and crossrefs \x ... \x*
    $t = [regex]::Replace($t, '\\f\b.*?\\f\*', ' ','Singleline')
    $t = [regex]::Replace($t, '\\x\b.*?\\x\*', ' ','Singleline')

    # remove inline char markers including +qt / +qt*, wj, add, nd, etc.
    # matches: \qt, \qt*, \+qt, \+qt*, \wj, \wj*, etc.
    $t = [regex]::Replace($t, '\\\+?[a-z0-9]+\*?', ' ')

    return Normalize-Whitespace $t
}

function Convert-UsfmFileToPlainText {
    param([string]$FilePath,[string]$OutputFolder)

    Write-Host "Processing (USFM/SFM) $FilePath"

    $rawLines = Get-Content -LiteralPath $FilePath -Encoding UTF8

    # Include qt-family as poetry styles
    $poetry = @('q','q1','q2','q3','q4','qt','qt1','qt2','qt3','qt4')
    $para   = @('m','p','pi') + $poetry
    $heading= @('s','s1','s2','s3','sp','ms','mr')

    $linesOut = @()

    $currStyle = $null
    $currSegs  = @()
    $currPlain = @()

    function Flush {
        param($Style,$Segs,$Plain,[ref]$Out,$Poetry)

        $S = @($Segs)

        if ($S.Count -gt 0) {
            if ($Poetry -contains $Style) {
                # Poetry: one line per verse
                foreach ($s in $S) {
                    $line = "$($s.Verse) $($s.Text)"
                    if ($line) { $Out.Value += $line }
                }
            }
            else {
                # Paragraph: all verses on one line
                $parts = $S | ForEach-Object { "$($_.Verse) $($_.Text)" }
                $line  = ($parts -join ' ')
                if ($line) { $Out.Value += $line }
            }
        }
        elseif ($Plain -and $Plain.Count -gt 0) {
            $t = Normalize-Whitespace ($Plain -join ' ')
            if ($t) { $Out.Value += $t }
        }
    }

    foreach ($line in $rawLines) {

        $l = $line.Trim()
        if (-not $l) { continue }

        # chapter \c N
        if ($l -match '^[\\]c\s+(\d+)\b') {
            Flush $currStyle $currSegs $currPlain ([ref]$linesOut) $poetry
            $currStyle = $null
            $currSegs  = @()
            $currPlain = @()

            $linesOut += $matches[1]
            continue
        }

        # headings
        if ($l -match '^[\\](s[0-3]?|sp|ms|mr)\s*(.*)$') {
            Flush $currStyle $currSegs $currPlain ([ref]$linesOut) $poetry
            $currStyle = $null
            $currSegs  = @()
            $currPlain = @()

            $t = Clean-UsfmText $matches[2]
            if ($t) { $linesOut += $t }
            continue
        }

        # paragraph / poetry markers, including qt / qt1-qt4
        if ($l -match '^[\\](m|p|pi|q[0-4]?|qt[0-4]?)\s*(.*)$') {
            Flush $currStyle $currSegs $currPlain ([ref]$linesOut) $poetry
            $currStyle = $matches[1]
            $currSegs  = @()
            $currPlain = @()

            $rest = $matches[2]
            if ($rest -match '^[\\]v\s+\d+') {
                # turn the rest into a verse line in the stream
                $rawLines = @("\v $rest") + $rawLines
            }
            else {
                $t = Clean-UsfmText $rest
                if ($t) { $currPlain += $t }
            }
            continue
        }

        # verse \v N text
        if ($l -match '^[\\]v\s+(\d+)\s*(.*)$') {

            if (-not $currStyle) { $currStyle = 'p' }

            $v = $matches[1]
            $t = Clean-UsfmText $matches[2]

            if ($t) {
                $currSegs += [pscustomobject]@{
                    Verse = $v
                    Text  = $t
                }
            }
            continue
        }

        # continuation line
        $c = Clean-UsfmText $l
        if ($c) {
            if ($currSegs.Count -gt 0) {
                $currSegs[-1].Text = Normalize-Whitespace ($currSegs[-1].Text + " " + $c)
            }
            else {
                $currPlain += $c
            }
        }
    }

    Flush $currStyle $currSegs $currPlain ([ref]$linesOut) $poetry

    # output folder
    if ($OutputFolder) {
        if (-not (Test-Path $OutputFolder)) {
            New-Item -ItemType Directory -Path $OutputFolder | Out-Null
        }
        $outDir = (Resolve-Path $OutputFolder).Path
    } else {
        $outDir = Split-Path (Resolve-Path $FilePath).Path -Parent
    }

    $base = [IO.Path]::GetFileNameWithoutExtension($FilePath)
    $outPath = Join-Path $outDir "$base.txt"

    $enc = New-Object System.Text.UTF8Encoding($true)
    [IO.File]::WriteAllLines($outPath, $linesOut, $enc)

    Write-Host "  -> Wrote $outPath"
}

# ------------------------------ ENTRY POINT --------------------------

if (Test-Path $InputPath -PathType Leaf) {

    $ext = [IO.Path]::GetExtension($InputPath).ToLowerInvariant()

    switch ($ext) {
        '.usx'  { Convert-UsxFileToPlainText  $InputPath $OutputFolder }
        '.usfm' { Convert-UsfmFileToPlainText $InputPath $OutputFolder }
        '.sfm'  { Convert-UsfmFileToPlainText $InputPath $OutputFolder }
        default { Write-Host "Skipping unsupported extension: $ext" }
    }
}
elseif (Test-Path $InputPath -PathType Container) {

    $files = Get-ChildItem $InputPath -File |
             Where-Object { $_.Extension.ToLowerInvariant() -in @('.usx','.usfm','.sfm') }

    foreach ($f in $files) {
        $ext = $f.Extension.ToLowerInvariant()
        switch ($ext) {
            '.usx'  { Convert-UsxFileToPlainText  $f.FullName $OutputFolder }
            '.usfm' { Convert-UsfmFileToPlainText $f.FullName $OutputFolder }
            '.sfm'  { Convert-UsfmFileToPlainText $f.FullName $OutputFolder }
        }
    }
}
else {
    throw "InputPath '$InputPath' does not exist."
}
