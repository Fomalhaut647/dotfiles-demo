---
name: pixi
description: Use when working with Pixi package manager for Python projects - environment setup, conda/PyPI dependency management, task definition, or pixi.toml/pyproject.toml configuration
---

You are an expert on Pixi, the cross-platform package manager and workflow tool built on the conda ecosystem. Use this reference to manage Python projects with Pixi.

## Pixi Overview

Pixi (v0.66.0) is a developer workflow and environment management tool for multi-platform, language-agnostic workspaces. It integrates the Conda and PyPI ecosystems.

## Key Concepts

- **Workspace**: A project directory managed by Pixi, configured via `pixi.toml` or `pyproject.toml`
- **Environment**: An isolated set of dependencies. A workspace can have multiple environments (e.g., different Python versions, test vs prod)
- **Feature**: A named group of dependencies/tasks that can be composed into environments
- **Task**: Named shell commands defined in the manifest, runnable via `pixi run`

## Critical: Python Project Setup Order

When setting up a Python project, always install Python itself from conda BEFORE adding PyPI dependencies. PyPI packages need a Python interpreter to resolve.

```bash
# Correct order:
pixi init my-project
cd my-project
pixi add python           # Step 1: Install Python from conda
pixi add --pypi requests  # Step 2: Now you can add PyPI packages

# Wrong — will fail:
pixi init my-project
pixi add --pypi requests  # No Python interpreter available!
```

## Common Workflows

### Initialize a Project

```bash
pixi init [path]                    # Create new workspace with pixi.toml
pixi init --format pyproject [path] # Use pyproject.toml format
pixi init -c conda-forge [path]     # Specify channel
```

### Add Dependencies

```bash
# Conda dependencies (default)
pixi add python numpy pandas
pixi add "python>=3.11,<3.13"       # Version constraints

# PyPI dependencies (requires Python already added)
pixi add --pypi requests
pixi add --pypi "Django==5.1"
pixi add --pypi requests[security]  # With extras
pixi add --pypi "pkg @ git+https://github.com/org/repo.git"  # From git
pixi add --pypi "pkg @ file:///path/to/pkg" --editable       # Local editable

# Add to a specific feature
pixi add --feature test pytest
pixi add --pypi --feature test black
```

### Remove Dependencies

```bash
pixi remove numpy
pixi remove --pypi requests
```

### Run Commands and Tasks

```bash
pixi run python script.py    # Run any command in the environment
pixi run test                # Run a named task
pixi run -e py311 test       # Run task in a specific environment
```

### Manage Tasks

```bash
pixi task add test "pytest -s"
pixi task add lint "ruff check ."
pixi task add start "python main.py"
pixi task add test "pytest" --depends-on lint  # Task dependencies
pixi task add build "make" --cwd subdir        # Working directory
pixi task list
pixi task remove test
```

### Shell and Environment

```bash
pixi shell            # Enter interactive shell with environment activated
pixi shell -e myenv   # Enter specific environment
pixi install          # Install/update environment from lockfile
pixi list             # List installed packages
pixi tree             # Show dependency tree
```

### Update and Upgrade

```bash
pixi update           # Update lockfile to latest compatible versions
pixi upgrade numpy    # Upgrade specific package (also updates manifest)
pixi upgrade --all    # Upgrade all dependencies
```

## pixi.toml Configuration

```toml
[workspace]
name = "my-project"
channels = ["conda-forge"]
platforms = ["linux-64", "osx-arm64", "win-64"]

[dependencies]
python = ">=3.11"
numpy = "*"

[pypi-dependencies]
requests = ">=2.28"

[tasks]
start = "python main.py"
test = "pytest -s"
lint = "ruff check ."

# Features for optional dependency groups
[feature.test.dependencies]
pytest = "*"

[feature.test.tasks]
test = "pytest"

# Multiple Python version environments
[feature.py311.dependencies]
python = "3.11.*"
[feature.py312.dependencies]
python = "3.12.*"

[environments]
test = ["test"]
py311 = ["py311"]
py312 = ["py312"]
```

## pyproject.toml Integration

Pixi can use `pyproject.toml` directly. The `[project].dependencies` list is treated as PyPI dependencies, and Python version comes from `requires-python`.

```toml
[project]
name = "my_project"
requires-python = ">=3.11"
dependencies = ["numpy", "pandas"]

[tool.pixi.workspace]
channels = ["conda-forge"]
platforms = ["linux-64", "osx-arm64", "win-64"]

[tool.pixi.dependencies]
compilers = "*"

[tool.pixi.tasks]
start = "python main.py"

[tool.pixi.feature.test.dependencies]
pytest = "*"

[tool.pixi.feature.test.tasks]
test = "pytest"

[tool.pixi.environments]
test = ["test"]
```

## Global Tools

Install CLI tools globally (accessible outside any project):

```bash
pixi global install ruff
pixi global install "python>=3.12"
pixi global list
pixi global uninstall ruff
```

## Useful Commands

```bash
pixi info              # Show system and workspace info
pixi search numpy      # Search for packages
pixi clean             # Clean environment caches
pixi self-update       # Update pixi itself
```

## Conda vs PyPI Dependencies

- Prefer **conda** dependencies when available — they include compiled binaries and system libraries, and resolve faster
- Use **PyPI** (`--pypi`) for packages only available on PyPI or when you need a specific PyPI-only version
- Pixi resolves conda and PyPI dependencies together to avoid conflicts
- Always add `python` as a conda dependency before any `--pypi` packages
