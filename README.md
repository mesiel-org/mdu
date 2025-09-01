<p align="center">
  <img src="doc/assets/logo.jpg" alt="MDU Logo" width="180"/>
</p>

<h1 align="center">MDU</h1>

<p align="center">
  <strong>MDU</strong> is a fast, multithreaded, cross-platform alternative to GNU <code>du</code> command.<br>
  Part of the <a href="https://github.com/mesiel-org">Mesiel Project</a>.
</p>

<p align="center">
  <a href="https://github.com/mesiel-org/mdu/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/mesiel-org/mdu/release.yml?branch=main&label=build" alt="Build"/></a>
  <a href="https://github.com/mesiel-org/mdu/releases"><img src="https://img.shields.io/github/v/release/mesiel-org/mdu" alt="Latest Release"/></a>
  <a href="https://www.gnu.org/licenses/gpl-3.0.html"><img src="https://img.shields.io/badge/license-GPLv3-blue" alt="License"/></a>
</p>



## Performance

Using [hyperfine](https://github.com/sharkdp/hyperfine) benchmarking tool for better benchmarking results. Used command:
```bash
hyperfine --runs 1 'mdu . -v' 'du . -h'
```

The following results were obtained (data taken from MDU reports):

| Metric       | Value |
|-------------|------:|
| Directories  | 6,725 |
| Files        | 86,853 |
| Size         | 2,753,484,187 (2.56 GB) |

### System Specs

- CPU: 4 cores
- RAM: 4 GB
- OS: Arch Linux 6.2.1-aarch64 GNU/Linux

### Benchmark Results

| Command     | Mean [s] | Ratio |
|:------------|----------:|---------:|
| `mdu . -v`  | 33.356    | `2.25×` faster than du     |
| `du . -h`   | 74.920    | `2.25×` slower than MDU    |



## Installation

**Installation Script (Recommended)**
```bash
curl -sSL https://raw.githubusercontent.com/mesiel-org/mdu/main/scripts/install.sh | bash
```

### Build from source

Requirements:
- [Unix-based](https://en.wikipedia.org/wiki/Unix) Operating System.
- [Zig](https://ziglang.org/) version `0.15.1` or later.
- GNU [Make](https://www.gnu.org/software/make/).

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
