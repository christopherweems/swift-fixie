# swift-fixie

`fixie` is a small CLI tool for running named shell workflows.

Workflows are defined in a script file at `~/.fixie/main` using a Swift-shaped function syntax (with Bash commands inside):

```.fixie/main
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
`~/.fixie/main`

If this file does not exist, fixie creates it on first run.


```.fixie/main
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

```.fixie/main
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
(1) buildDemo()
(2) serveDemoHTTPServer()
(3) cleanProjectBuildDirectory()
```


## Working Directory Rules

Workflows should normally cd into the directory they act on:

```.fixie/main
func serveDemoHTTPServer() {
    cd ~/Sources/demo
    python3 -m http.server 8080
}
```

If a workflow does not include a cd as its first meaningful line, use: 

```.fixie/main
fixie --here workflowName
```

This prevents accidental operations in the wrong directory.


## Execution Model

- Workflows run sequentially in a persistent shell across all named function calls. (Side effects are allowed.)
- Output streams live to console.
- If a command exits non-zero, execution stops immeiately with `-e` (fail fast).

### Example call: `fixie buildDemo`

```bash
────────────────────────────────────────
 buildDemo()
────────────────────────────────────────
• cd ~/project
• swift build
Done.
```


## Project philosophy

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

- `--here` enforcement for non-cd workflows
- `--define` to show full source for any workflow
- `.fixie/macros` for named sequences of workflows


## License

Copyright (c) 2025 Christopher Weems

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
