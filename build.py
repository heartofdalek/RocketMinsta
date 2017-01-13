#!/usr/bin/env python3

import sys

try:
    import rmbuild.main
except ImportError:
    sys.stderr.write("Error: rmbuild is not installed.\nSee https://github.com/nexAkari/rmbuild for instructions.\n")
    exit(1)
else:
    import os
    repo = os.path.dirname(__file__)

    rmbuild.main.main(sys.argv, defaults_overrides={
        'path': repo,
        'config': os.path.join(repo, 'config.py')
    })
