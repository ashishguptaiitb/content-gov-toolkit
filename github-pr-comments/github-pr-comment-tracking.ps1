<#
Run "gh pr-comments" for every PR number listed in a text file and consolidates the output into a single TSV report.

.INPUT required: Full path of the .txt file with one PR number per line.
To generate the list of PRs, run:
gh pr list --state closed --label "PendingFixes" --json number --jq ".[].number"

.OUTPUT is the file named PR_Comments_Report_<timestamp>.tsv
#>

# Prompt the user for the input file and accept paths with or without quotes.
$inputFile = Read-Host "Enter the path to the PR number text file"
$inputFile = $inputFile.Trim('"')

# Verify that the specified file exists before continuing.
if (-not (Test-Path $inputFile)) {
    Write-Host "File not found: $inputFile" -ForegroundColor Red
    exit 1
}

# Create a timestamped TSV report in the same folder as the input file.
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$outputFile = Join-Path (Split-Path $inputFile -Parent) "PR_Comments_Report_$timestamp.tsv"

# Add the header row to the output file.
"File_Path`tLine`tAuthor`tStatus`tComment`tURL" |
    Out-File -FilePath $outputFile -Encoding UTF8


# Read the PR numbers, ignoring blank lines.
$prNumbers = Get-Content $inputFile |
    ForEach-Object { $_.Trim() } |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

$total = $prNumbers.Count
$count = 0

# Process each PR by running the GitHub CLI command and capturing its output.
foreach ($pr in $prNumbers) {

    $count++
    Write-Host "[$count/$total] Processing PR $pr..."

    try {

        # Execute the GitHub CLI command and capture standard output and errors.
        $result = & gh pr-comments $pr 2>&1

        # Record any command failures and continue with the next PR.
        if ($LASTEXITCODE -ne 0) {
            ("ERROR processing PR {0}: {1}" -f $pr, ($result -join ' ')) |
                Out-File -FilePath $outputFile -Append -Encoding UTF8
            continue
        }

        # Append the command output exactly as returned by gh pr-comments.
        if ($result) {
            $result | ForEach-Object { $_.ToString() } |
                Out-File -FilePath $outputFile -Append -Encoding UTF8

        }

    }
    catch {
        # Capture unexpected errors without stopping the script.
        ("ERROR processing PR {0}: {1}" -f $pr, $_.Exception.Message) |
            Out-File -FilePath $outputFile -Append -Encoding UTF8
    }
}

# Display the location of the generated report.
Write-Host ""
Write-Host "Done." -ForegroundColor Green
Write-Host "Output saved to:"
Write-Host $outputFile