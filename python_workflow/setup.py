"""
Install helper for the SPARKLE climate–malaria Python workflow.

This is the optional Python reference implementation (malaria_workflow.ipynb) for
students who want to see the analysis in Python.

The recommended way to install the dependencies is:

    cd python_workflow
    python -m venv .venv && source .venv/bin/activate     # optional but recommended
    pip install -r requirements.txt
    jupyter lab malaria_workflow.ipynb

As a convenience, running this file directly does the same pip install for you:

    python setup.py

(It also still works as a normal setuptools file, e.g. ``pip install -e .``.)

Data location: the notebook reads the (separately shared) climate data from
``../data`` — i.e. the ``data/`` folder at the repository root — so no extra setup
is needed as long as that folder is present.
"""
import os
import sys
import subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
REQUIREMENTS = os.path.join(HERE, "requirements.txt")


def _read_requirements():
    with open(REQUIREMENTS, encoding="utf-8") as fh:
        return [
            line.strip() for line in fh
            if line.strip() and not line.lstrip().startswith("#")
        ]


# setuptools may be absent in a bare virtual environment.
try:
    from setuptools import setup
except ImportError:
    setup = None

# If run directly (`python setup.py`), or if setuptools is missing, just install
# the dependencies with pip — which is almost certainly what was intended.
if __name__ == "__main__" and (setup is None or len(sys.argv) == 1):
    print("Installing dependencies from requirements.txt ...\n")
    subprocess.check_call(
        [sys.executable, "-m", "pip", "install", "-r", REQUIREMENTS]
    )
    print("\nDone. The notebook reads data from ../data (the repo-root data/ folder).")
    print("Next:  jupyter lab malaria_workflow.ipynb")
    sys.exit(0)

# Normal setuptools entry point (used by `pip install .` / `pip install -e .`).
setup(
    name="malaria-climate-workflow",
    version="0.1.0",
    description="Python workflow linking climate data to malaria (SPARKLE course)",
    python_requires=">=3.9",
    install_requires=_read_requirements(),
    py_modules=[],
)
