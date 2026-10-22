# Ubumatic

A Bash script that configured a fresh Ubuntu installation: it set the recommended
repositories, installed updates, codecs, Java, Flash, archivers and fonts, and
offered a handful of maintenance commands. Written in 2012 for Ubuntu 10.04 LTS
(Lucid) and 12.04 LTS (Precise), with a Zenity GUI and a command line mode,
in Polish and English.

This repository contains two things:

| File | What it is |
| --- | --- |
| [`ubumatic.sh`](ubumatic.sh) | The original script, refactored for readability. Same features, same Ubuntu 10.04–12.10 target. Kept as a historical project. |
| [`ubumatic-lite.sh`](ubumatic-lite.sh) | A small modern rewrite for current Ubuntu releases (`--dry-run`, no stored password, no third-party downloads). |

## Why a refactor

The version that survived on disk had been size-minified: variables called `ac`,
`ce`, `u1`, `u2`, one huge function, messages stored as one numbered list
(`$l1`…`$l54`). The refactor keeps the behaviour and changes the structure:

- descriptive names and one function per command-line option,
- message tables (`T[key]`) for Polish and English instead of numbered strings,
- checklist rows and package lists built as arrays instead of string tricks,
- quoting everywhere, `set -u`, a temporary directory from `mktemp`,
- the script can be sourced without running (`BASH_SOURCE` guard), which makes it testable,
- ShellCheck clean.

Output files (`sources.list`, `mpd.conf`, ...) are generated from heredocs, and the
generated `sources.list` is checked against the original text in the tests.

## Tests

```bash
bash test/run-tests.sh
```

The tests run the real scripts with stubbed `sudo`, `apt-get`, `zenity`, `xterm`,
`wget` and friends, so nothing is installed and no old Ubuntu is needed. They cover
the GUI flow (selection → packages, repositories, cancel, no internet, wrong
password, Lucid/Precise/Quantal, Polish/English), the CLI options and
`ubumatic-lite.sh`. ShellCheck: `shellcheck -x ubumatic.sh ubumatic-lite.sh test/run-tests.sh`.

The scripts were **not** run on a real Ubuntu 10.04/12.04 system. Their repositories
and some of the packages (Flash, `w32codecs`, Gadu-Gadu plugin) no longer exist.

## Known limitations of the original design

Kept on purpose to stay faithful to the original, fixed in `ubumatic-lite.sh`:

- The sudo password is stored in a variable and passed to `sudo -S` and to the xterm window.
- Option "screen blanking" downloads an archive over plain HTTP and runs its script as root
  (the download server no longer exists).
- `sources.list` is replaced with third-party repositories (deb-multimedia, GetDeb)
  and `apt-get --force-yes` is used.
- `--kernelnew` installs a kernel only when the version test matches the installed
  one, which looks inverted (marked with a `NOTE` in the code).

## Ubumatic Lite

```bash
./ubumatic-lite.sh --dry-run --all     # show what would be done
./ubumatic-lite.sh --codecs --fonts    # run selected actions
./ubumatic-lite.sh                     # ask about every action
```

## License

GPLv3, © 2012 Piotr Miros. See [LICENSE](LICENSE).
