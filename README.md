# swift-fixie

`fixie` is a small CLI tool for running named shell workflows.

Workflows are defined in a script file at `~/.fixie/list` using a Swift-shaped function syntax (with Bash commands inside):

```.fixie/list
func build() {
    cd ~/project
    swift build
}
```

Run it:

```bash
fixie build
```

`fixie` aims to make repeatable command sequences easy to name, easy to read, and easy to trust.


## Installation

### macOS / Linux (user-local install)

```bash
git clone https://github.com/christopherweems/swift-fixie.git
cd swift-fixie
swift build -c release

mkdir -p ~/.local/bin
cp ./.build/release/fixie ~/.local/bin/
```

### Ensure ~/.local/bin is in your PATH:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
```

or for zsh:

```zsh
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
```


## Workflow Script

Your workflows live in:
`~/.fixie/list`

If this file does not exist, fixie creates it on first run.


```.fixie/list
func buildDemo() {
    cd ~/Sources/demo
    swift build
    echo "Done."
}
```

Run it:
```bash
fixie buildDemo
```

Multiple workflows can be defined in the same file:

```.fixie/list
func serveDemoHTTPServer() {
    cd ~/Sources/demo
    python3 -m http.server 8080
}

func cleanProjectBuildDirectory() {
    cd ~/Sources/demo
    rm -rf .build
}
```


## Listing Workflows

```bash
fixie --list
```

Outputs something like:
```bash
- buildDemo()
- serveDemoHTTPServer()
- cleanProjectBuildDirectory()
```


## Working Directory Rules

Workflows should normally cd into the directory they act on:

```.fixie/list
func serveDemoHTTPServer() {
    cd ~/Sources/demo
    python3 -m http.server 8080
}
```

If a workflow does not include a `cd` as its first _non-var-setting_ line, use: 

```.fixie/list
fixie --here workflowName
```

This prevents accidental operations in the wrong directory. Functions that don't specify a working directory will not run without `--here`.


## Execution Model

- Workflows run sequentially in a persistent shell across all named function calls. (Side effects are allowed.)
- Output streams live to console.
- If a command exits non-zero, execution stops immediately with `-e` (fail fast).

### Example call: `fixie buildDemo`

```bash
────────────────────────────────────────
 buildDemo()
────────────────────────────────────────
• cd ~/project
• swift build
Done.
```


## Project Philosophy

fixie is not:
```
a template system
a build system
a replacement for Bash
```

fixie is:
```
a way to name your repeatable moves
a way to keep them readable
a way to avoid re-typing the same steps every day
```

## Roadmap

- `@WorkingDirectory("/var/www/")` function attribute to specify working directory safely, deprecating `cd` in script bodies after introduction.
- `--here` enforcement for non-`cd` workflows, start with "no `cd` no run" policy with guidance to put cd as first line, or first immediately after a list of variable declarations. A workflow using more than one cd requires `--unsafe` specifier. Consider replacing/skipping all of this for `@WorkingDirectory()` attribute on the workflow, which would put the safety burden on the author of the workflow and not on the operator. But for now `--here` and `--unsafe` are your escape hatches.

- `.fixie/macros` for named sequences of workflows automations created by operators of `fixie` (not hand-authored).
- `fixie workflowName --source` to see full source for any workflow, and `fixie workflowName --copy` to copy it to your pasteboard.
- Allow arbitrary names for items in `.fixie/` (default `list` also renamable without penalty)
- Function calling. Recursion is disallowed, but small helper functions are needed to prevent brittle reuse in copy/pasta.


## License

Copyright (c) 2025 Christopher Weems

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
