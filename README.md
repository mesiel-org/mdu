<p align="center">
  <img src="doc/assets/logo.jpg" alt="MDU Logo" width="180"/>
</p>

<h1 align="center">MDU</h1>

<p align="center">
  <strong>MDU</strong> is a fast, multithreaded, cross-platform alternative to <code>du</code>.<br>
  Part of the <a href="https://github.com/mesiel-org">Mesiel Project</a>.
</p>

<p align="center">
  <a href="https://github.com/mesiel-org/mdu/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/mesiel-org/mdu/release.yml?branch=main&label=build" alt="Build"/></a>
  <a href="https://github.com/mesiel-org/mdu/releases"><img src="https://img.shields.io/github/v/release/mesiel-org/mdu" alt="Latest Release"/></a>
  <a href="https://www.gnu.org/licenses/gpl-3.0.html"><img src="https://img.shields.io/badge/license-GPLv3-blue" alt="License"/></a>
</p>



## Performance

- **Speed:** ~3× faster than GNU du on large directories.  
- **Info:** Reports files, directories, and sizes natively.  
- **Report:** Clean, formatted output for auditing.

**Benchmark (Linux 6.2.1-aarch64, 4 cores, 4 GB RAM):**

| Metric           | **MDU**      | **GNU du**     |
|-----------------|--------------|----------------|
| Total Size      | 1.21 GB      | 1.2 GB         |
| Directories     | 8,337        | N/A            |
| Files           | 43,590       | N/A            |
| Real Time       | 15.1 s       | 50.48 s        |
| CPU Time        | 7.77 s       | 11.3 s         |
| Ease of Report  | High         | Low            |

> **MDU** for full reports; GNU du for simple size checks.



## Installation

**Scripted**
```bash
curl -sSL https://raw.githubusercontent.com/mesiel-org/mdu/main/install.sh | bash
```

**Manual**
```bash
git clone https://github.com/mesiel-org/mdu.git
cd mdu
make
sudo make install
```



## Usage
```bash
mdu [path] [options]

Options:
  -ex=<dir>      Exclude directory (repeatable)
  -v, --verbose  Verbose output
  -q, --quiet    Quiet mode (default)
  -h, --help     Show help
  --version      Show version
```


## License

MDU is licensed under the [GNU GPL v3 or later](https://www.gnu.org/licenses/gpl-3.0.html).
