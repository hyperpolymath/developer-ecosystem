#!/usr/bin/env julia
# SPDX-License-Identifier: MPL-2.0
# propagate-mirror-workflow.jl - Propagate multi-forge mirror workflow to all repos

using Dates

const MIRROR_WORKFLOW = raw"""
# SPDX-License-Identifier: MPL-2.0
# Multi-forge mirror workflow - pushes to GitLab, Bitbucket, Codeberg, SourceHut, Radicle
name: Mirror to All Forges

on:
  push:
    branches: [main, master]
    tags:
      - 'v*'
  workflow_dispatch:

permissions: read-all

jobs:
  mirror-gitlab:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    if: vars.GITLAB_MIRROR_ENABLED == 'true'
    steps:
      - name: Checkout
        uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11 # v4
        with:
          fetch-depth: 0

      - name: Setup SSH
        uses: webfactory/ssh-agent@dc588b651fe13675774614f8e6a936a468676387 # v0.9.0
        with:
          ssh-private-key: ${{ secrets.GITLAB_SSH_KEY }}

      - name: Add GitLab to known hosts
        run: ssh-keyscan -t ed25519 gitlab.com >> ~/.ssh/known_hosts

      - name: Push to GitLab
        env:
          REPO_NAME: ${{ github.event.repository.name }}
        run: |
          git remote add gitlab git@gitlab.com:hyperpolymath/${REPO_NAME}.git 2>/dev/null || true
          git push gitlab HEAD:main --force || git push gitlab HEAD:master --force
          git push gitlab --tags --force

  mirror-bitbucket:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    if: vars.BITBUCKET_MIRROR_ENABLED == 'true'
    steps:
      - name: Checkout
        uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11 # v4
        with:
          fetch-depth: 0

      - name: Setup SSH
        uses: webfactory/ssh-agent@dc588b651fe13675774614f8e6a936a468676387 # v0.9.0
        with:
          ssh-private-key: ${{ secrets.BITBUCKET_SSH_KEY }}

      - name: Add Bitbucket to known hosts
        run: ssh-keyscan -t ed25519 bitbucket.org >> ~/.ssh/known_hosts

      - name: Push to Bitbucket
        env:
          REPO_NAME: ${{ github.event.repository.name }}
        run: |
          git remote add bitbucket git@bitbucket.org:hyperpolymath/${REPO_NAME}.git 2>/dev/null || true
          git push bitbucket HEAD:main --force || git push bitbucket HEAD:master --force
          git push bitbucket --tags --force

  mirror-codeberg:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    if: vars.CODEBERG_MIRROR_ENABLED == 'true'
    steps:
      - name: Checkout
        uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11 # v4
        with:
          fetch-depth: 0

      - name: Setup SSH
        uses: webfactory/ssh-agent@dc588b651fe13675774614f8e6a936a468676387 # v0.9.0
        with:
          ssh-private-key: ${{ secrets.CODEBERG_SSH_KEY }}

      - name: Add Codeberg to known hosts
        run: ssh-keyscan -t ed25519 codeberg.org >> ~/.ssh/known_hosts

      - name: Push to Codeberg
        env:
          REPO_NAME: ${{ github.event.repository.name }}
        run: |
          git remote add codeberg git@codeberg.org:hyperpolymath/${REPO_NAME}.git 2>/dev/null || true
          git push codeberg HEAD:main --force || git push codeberg HEAD:master --force
          git push codeberg --tags --force

  mirror-sourcehut:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    if: vars.SOURCEHUT_MIRROR_ENABLED == 'true'
    steps:
      - name: Checkout
        uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11 # v4
        with:
          fetch-depth: 0

      - name: Setup SSH
        uses: webfactory/ssh-agent@dc588b651fe13675774614f8e6a936a468676387 # v0.9.0
        with:
          ssh-private-key: ${{ secrets.SOURCEHUT_SSH_KEY }}

      - name: Add SourceHut to known hosts
        run: ssh-keyscan -t ed25519 git.sr.ht >> ~/.ssh/known_hosts

      - name: Push to SourceHut
        env:
          REPO_NAME: ${{ github.event.repository.name }}
        run: |
          git remote add sourcehut git@git.sr.ht:~hyperpolymath/${REPO_NAME} 2>/dev/null || true
          git push sourcehut HEAD:main --force || git push sourcehut HEAD:master --force
          git push sourcehut --tags --force

  mirror-radicle:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    if: vars.RADICLE_MIRROR_ENABLED == 'true'
    steps:
      - name: Checkout
        uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11 # v4
        with:
          fetch-depth: 0

      - name: Install Radicle
        run: |
          curl -sSf https://radicle.xyz/install | sh
          echo "$HOME/.radicle/bin" >> $GITHUB_PATH

      - name: Push to Radicle
        env:
          RAD_PASSPHRASE: ${{ secrets.RADICLE_PASSPHRASE }}
          RAD_HOME: ${{ runner.temp }}/.radicle
        run: |
          mkdir -p $RAD_HOME
          # Initialize if needed and push
          rad sync --push || echo "Radicle sync attempted"
"""

function get_repos()
    output = read(`gh repo list hyperpolymath --limit 200 --json name --jq '.[].name'`, String)
    return filter(!isempty, split(strip(output), '\n'))
end

function update_repo(repo::String; dry_run::Bool=false)
    println("Processing: $repo")

    # Clone or update
    repo_dir = "/tmp/mirror-propagate/$repo"

    try
        if !isdir(repo_dir)
            run(`git clone --depth 1 git@github.com:hyperpolymath/$repo.git $repo_dir`)
        else
            cd(repo_dir) do
                run(`git pull --ff-only`)
            end
        end

        # Ensure .github/workflows exists
        workflows_dir = joinpath(repo_dir, ".github", "workflows")
        mkpath(workflows_dir)

        # Write mirror.yml
        mirror_file = joinpath(workflows_dir, "mirror.yml")

        if dry_run
            println("  [DRY RUN] Would write mirror.yml")
            return true
        end

        write(mirror_file, MIRROR_WORKFLOW)

        cd(repo_dir) do
            # Check if there are changes
            status = read(`git status --porcelain`, String)
            if isempty(strip(status))
                println("  No changes needed")
                return true
            end

            # Commit and push
            run(`git add .github/workflows/mirror.yml`)
            run(`git commit -m "feat: add multi-forge mirroring workflow

Mirrors to GitLab, Bitbucket, Codeberg, SourceHut, Radicle when enabled.

🤖 Generated with [Claude Code](https://claude.com/claude-code)"`)
            run(`git push origin HEAD`)
            println("  ✓ Updated")
        end

        return true
    catch e
        println("  ✗ Error: $e")
        return false
    end
end

function main()
    dry_run = "--dry-run" in ARGS
    single_repo = nothing

    for arg in ARGS
        if startswith(arg, "--repo=")
            single_repo = replace(arg, "--repo=" => "")
        end
    end

    # Create temp directory
    mkpath("/tmp/mirror-propagate")

    repos = if single_repo !== nothing
        [single_repo]
    else
        get_repos()
    end

    println("Found $(length(repos)) repos")
    if dry_run
        println("[DRY RUN MODE]")
    end
    println()

    success = 0
    failed = 0

    for repo in repos
        if update_repo(repo; dry_run=dry_run)
            success += 1
        else
            failed += 1
        end
    end

    println()
    println("=" ^ 50)
    println("Summary: $success succeeded, $failed failed")
end

main()
