<#
.SYNOPSIS
  Creates a minimal Phaser 4.2.1 + Vite + TypeScript project in C:\dev.
.DESCRIPTION
  Uses Phaser's official Vite + TypeScript template and reduces it to one scene.
.EXAMPLE
  .\create-phaser-project.ps1
.EXAMPLE
  .\create-phaser-project.ps1 -ProjectName lunar-runner
.EXAMPLE
  .\create-phaser-project.ps1 -DevFolder 'D:\work\dev' -ProjectName lunar-runner
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$ProjectName,

    [string]$DevFolder = 'C:\dev'
)

$ErrorActionPreference = 'Stop'

function Invoke-Npm {
    param([Parameter(Mandatory)][string[]]$Arguments)
    & npm @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "npm $($Arguments -join ' ') failed with exit code $LASTEXITCODE."
    }
}

function Invoke-Npx {
    param([Parameter(Mandatory)][string[]]$Arguments)
    & npx @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "npx $($Arguments -join ' ') failed with exit code $LASTEXITCODE."
    }
}

if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
    throw 'npm was not found. Install Node.js (which includes npm), reopen PowerShell, and try again.'
}

if ([string]::IsNullOrWhiteSpace($ProjectName)) {
    $ProjectName = Read-Host 'What do you want to create? (project name)'
}
$ProjectName = $ProjectName.Trim()
if ([string]::IsNullOrWhiteSpace($ProjectName) -or $ProjectName -match '[<>:"/\\|?*]') {
    throw 'Enter a valid project folder name (without path separators or Windows-invalid characters).'
}

$DevFolder = [System.IO.Path]::GetFullPath($DevFolder)
$ProjectPath = Join-Path $DevFolder $ProjectName
if (Test-Path -LiteralPath $ProjectPath) {
    throw "The destination already exists: $ProjectPath`nChoose another project name or move the existing folder first."
}

New-Item -ItemType Directory -Path $DevFolder -Force | Out-Null
Push-Location $DevFolder
try {
    Write-Host "Creating a minimal Vite + TypeScript Phaser project named '$ProjectName' under '$DevFolder'."
    # The official @phaserjs/game CLI currently has no flags for selecting its
    # template, skeleton, or language. Use Phaser's official Vite + TypeScript
    # template directly to keep project creation non-interactive.
    Invoke-Npx -Arguments @('--yes', 'degit', 'phaserjs/template-vite-ts', $ProjectName)

    if (-not (Test-Path -LiteralPath (Join-Path $ProjectPath 'package.json'))) {
        throw "The Phaser scaffolder did not create the expected project at $ProjectPath."
    }

    Push-Location $ProjectPath
    try {
        $SceneFolder = Join-Path $ProjectPath 'src\game\scenes'
        if (Test-Path -LiteralPath $SceneFolder) {
            $ResolvedSceneFolder = [System.IO.Path]::GetFullPath($SceneFolder)
            if (-not $ResolvedSceneFolder.StartsWith($ProjectPath, [System.StringComparison]::OrdinalIgnoreCase)) {
                throw "Refusing to modify a scene folder outside the new project: $ResolvedSceneFolder"
            }
            Remove-Item -LiteralPath $ResolvedSceneFolder -Recurse -Force
        }

        $SingleSceneEntry = @'
import { AUTO, Game, Scene } from 'phaser';

class MainScene extends Scene
{
    constructor ()
    {
        super('main');
    }

    create ()
    {
        this.add.text(512, 384, 'Phaser project ready', {
            fontFamily: 'Arial',
            fontSize: '32px',
            color: '#ffffff'
        }).setOrigin(0.5);
    }
}

const config: Phaser.Types.Core.GameConfig = {
    type: AUTO,
    width: 1024,
    height: 768,
    parent: 'game-container',
    backgroundColor: '#1d1d1d',
    scene: [MainScene]
};

const StartGame = (parent: string) => new Game({ ...config, parent });

export default StartGame;
'@
        Set-Content -LiteralPath (Join-Path $ProjectPath 'src\game\main.ts') -Value $SingleSceneEntry -Encoding utf8

        Invoke-Npm -Arguments @('install', 'phaser@4.2.1', '--save-exact')
        Invoke-Npm -Arguments @('install', '--save-exact', 'zod')
        Invoke-Npm -Arguments @('install', '--save-dev', '--save-exact', 'vitest', '@playwright/test', 'eslint', '@eslint/js', 'typescript-eslint', '@types/node')
        & npx playwright install chromium
        if ($LASTEXITCODE -ne 0) {
            throw "npx playwright install chromium failed with exit code $LASTEXITCODE."
        }
    }
    finally {
        Pop-Location
    }

    Write-Host "`nPhaser project created successfully: $ProjectPath" -ForegroundColor Green
    Write-Host "To start it: cd `"$ProjectPath`"; npm run dev"
}
finally {
    Pop-Location
}
