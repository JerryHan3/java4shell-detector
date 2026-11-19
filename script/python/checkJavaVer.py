import os, sys, glob, shutil, subprocess, re
_VERSION_RE = re.compile(r'version\s+"?([^\s"]+)"?')


class JavaNotFound(Exception):
    """No usable `java` executable could be located on this machine."""


class JavaInvalid(Exception):
    """A `java` candidate exists but is not a runnable program (bad link, wrong file type, no permission)."""


class JavaBroken(Exception):
    """The `java` process started but failed to report a parsable version."""


class JavaTimeout(Exception):
    """The `java -version` process did not finish in time."""


## Install locations probed when Java is not on `PATH` or under `JAVA_HOME`, grouped by
## platform. Only the current platform's group is ever globbed: a pattern such as
## `/usr/lib/jvm/*/bin/java` must not be expanded on Windows, where it would silently turn
## into `C:\usr\lib\jvm\...` (and under Wine it matches a real Linux JVM via the Z: drive).
## A pattern pointing at a missing directory simply yields an empty list, so extra entries
## cost nothing.
_LINUX_FALLBACK_PATTERNS = [
    '/usr/lib/jvm/*/bin/java',          # Debian / Ubuntu / RHEL
    '/usr/java/*/bin/java',             # Oracle JDK
    '/opt/*/bin/java',                  # manually untarred JDKs
]
_WINDOWS_FALLBACK_PATTERNS = [
    'C:/Program Files/Java/*/bin/java.exe',              # Oracle JDK
    'C:/Program Files/Eclipse Adoptium/*/bin/java.exe',  # Temurin
    'C:/Program Files/Microsoft/jdk-*/bin/java.exe',     # Microsoft Build of OpenJDK
    'C:/Program Files/zulu/*/bin/java.exe',              # Azul Zulu
    'C:/Program Files/BellSoft/*/bin/java.exe',          # BellSoft Liberica
    'C:/Program Files (x86)/Java/*/bin/java.exe',        # 32-bit JDK
]
_MACOS_FALLBACK_PATTERNS = [
    '/Library/Java/JavaVirtualMachines/*/Contents/Home/bin/java',
    '/System/Library/Java/JavaVirtualMachines/*/Contents/Home/bin/java',
    '/opt/homebrew/opt/openjdk*/bin/java',   # Homebrew on Apple Silicon
    '/usr/local/opt/openjdk*/bin/java',      # Homebrew on Intel
]

## Extensions that count as a launchable program on Windows.
_WINDOWS_EXEC_EXTENSIONS = ('.exe', '.bat', '.cmd', '.com')


def _fallback_patterns() -> list[str]:
    """Return the install-location patterns that make sense on this platform."""
    if sys.platform == 'win32': return _WINDOWS_FALLBACK_PATTERNS
    if sys.platform == 'darwin': return _MACOS_FALLBACK_PATTERNS
    return _LINUX_FALLBACK_PATTERNS


def _is_runnable_java(path: str) -> bool:
    """A candidate is runnable when it is an existing, executable file."""
    if not os.path.isfile(path): return False
    if os.name == 'nt':
        # `os.access(path, os.X_OK)` is meaningless on Windows: it reports True for any
        # existing file, so an arbitrary file would be accepted as the Java launcher.
        # The extension is checked instead, which still admits real launchers.
        return os.path.splitext(path)[1].lower() in _WINDOWS_EXEC_EXTENSIONS
    return os.access(path, os.X_OK)


def findJava(allow_fallback: bool = True) -> str:
    """
    Locate a `java` executable on this machine.

    Search order: `PATH` (via ``shutil.which``) -> `JAVA_HOME` -> common install
    directories. Returns the absolute path of the first runnable candidate.

    `allow_fallback`: when `False`, the "common install directories" step is
    skipped so only officially registered installations (`PATH` / `JAVA_HOME`)
    are considered. The host disables it when the user explicitly picked a Java
    binary, because silently checking a different JVM would be misleading.

    Raises `JavaNotFound` when no candidate exists, and `JavaInvalid` when a
    candidate was found through `PATH`/`JAVA_HOME` but is not runnable (a stale
    symlink left behind by an uninstalled JVM is the usual culprit), so the
    caller can tell "never installed" apart from "broken installation".
    """
    exe = 'java.exe' if os.name == 'nt' else 'java'

    on_path = shutil.which('java')
    if on_path:
        if _is_runnable_java(on_path):
            return on_path
        raise JavaInvalid(f"`java` on PATH points to a non-runnable file: {on_path}")

    java_home = os.environ.get('JAVA_HOME')
    if java_home:
        candidate = os.path.join(java_home, 'bin', exe)
        if _is_runnable_java(candidate):
            return candidate
        raise JavaInvalid(f"JAVA_HOME does not contain a runnable java: {candidate}")

    if allow_fallback:
        for pattern in _fallback_patterns():
            for candidate in sorted(glob.glob(pattern), reverse=True):
                if _is_runnable_java(candidate):
                    return candidate

    scope = "PATH, JAVA_HOME or common install locations" if allow_fallback else "PATH or JAVA_HOME"
    raise JavaNotFound(f"No java executable found in {scope}")


def getJavaVer(path: str | None = None, timeout: float = 15.0, allow_fallback: bool = True) -> str:
    """
    Execute `java -version` and parse the versioning string from the output.

    **Parameters**
    `path`: Java binary path. If `None`, the binary is located by `findJava()`.
    `timeout`: Seconds to wait before giving up.
    `allow_fallback`: See `findJava`. Only used when `path` is `None`.

    Raises `JavaNotFound`, `JavaInvalid`, `JavaBroken` or `JavaTimeout`.
    """
    if path is None: path = findJava(allow_fallback)
    try:
        # `stdin=DEVNULL` keeps a bogus executable that waits for input from blocking.
        result = subprocess.run(
            [path, '-version'], capture_output=True, text=True,
            timeout=timeout, stdin=subprocess.DEVNULL,
        )
    except FileNotFoundError as exc:
        raise JavaInvalid(f"`{path}` does not exist: {exc}") from exc
    except PermissionError as exc:
        raise JavaInvalid(f"`{path}` is not executable: {exc}") from exc
    except OSError as exc:
        # ENOEXEC / "Exec format error": the selected file is not a program.
        raise JavaInvalid(f"`{path}` cannot be executed: {exc}") from exc
    except subprocess.TimeoutExpired as exc:
        raise JavaTimeout(f"`{path} -version` did not finish within {timeout:g}s") from exc

    if result.returncode != 0:
        detail = (result.stderr or result.stdout or '').strip()
        raise JavaBroken(f"`{path} -version` exited with {result.returncode}: {detail}")
    output = (result.stderr or "") + (result.stdout or "")
    m = _VERSION_RE.search(output)
    if not m:
        raise JavaBroken(f"Failed to parse Java version from output: \n{output}")
    return m.group(1)


def checkJavaVer(verstr: str):
    """
    Check if the Java installed is affected by [Java4Shell vulnerability](https://calif.io/java4shell).

    **Parameters**
    `verstr`: Java versioning string. Required.

    Return a boolean that represent if java is affected. `True` for affected, `False` for safe.
    """
    match = re.match(r'^(\d+(?:\.\d+)*)', verstr.split('+')[0].split('-')[0])
    if not match:
        raise ValueError(f"Failed to parse versioning string: {verstr}")

    ver_nums = [int(num) for num in match.group(1).split('.')]

    # Deal with legacy versioning
    if ver_nums[0] == 1:
        major = ver_nums[1] if len(ver_nums) > 1 else 0
        if major < 17:
            return False
    else:
        major = ver_nums[0]

    if major < 17 or major > 27: return False
    # Non-LTS version not declared in advisory, flagged as affected for better range
    if major not in [17, 21, 25, 27]: return True
    # Add tuple up to 3 digits
    ver_tail = ver_nums[1:4]
    ver_tup = tuple(ver_tail + [0] * max(0, (3 - len(ver_tail))))
    if major == 17:
        # 17.0.6 ~ 17.0.21, patched in 17.0.21.1
        return (0, 6) <= ver_tup < (0, 21, 1)
    if major == 21:
        # ~ 21.0.13, patched in 21.0.13.1
        return (0, 0) <= ver_tup < (0, 13, 1)
    if major == 25:
        # ~ 25.0.5, patched in 25.0.5.1
        return (0, 0) <= ver_tup < (0, 5, 1)
    # ~ 27.0.1, patched in 27.0.1.1
    return (0, 0) <= ver_tup < (0, 1, 1)

def godot_bridge(path = "java"):
    verstr = getJavaVer(path)
    check_result = checkJavaVer(verstr)
    return verstr, check_result

def main():
    """
    Entry point invoked by PyRunner, which imports this module and calls ``main()``.

    Reads the optional Java binary path from stdin and prints exactly one line for
    Godot to consume. Every failure mode is mapped to a status token so the host
    never hangs waiting for output:

    - ``OK <version> <true|false>``: version parsed and checked.
    - ``NOT_FOUND``: nothing installed at all — not on `PATH`, no `JAVA_HOME`, no
      common install directory, and no custom path given. This is a valid
      *conclusion* ("no Java detected"), not an error.
    - ``INVALID <reason>``: java was given (or registered via `PATH`/`JAVA_HOME`)
      but is not runnable, e.g. a stale symlink or a wrong file.
    - ``BROKEN <reason>``: java started but crashed or printed no version.
    - ``TIMEOUT``: ``java -version`` did not finish in time.
    - ``ERROR <reason>``: anything else unexpected.

    A user-supplied path is authoritative: if it is unusable the host is told
    `INVALID` instead of silently checking a different JVM found elsewhere.
    """
    try:
        path = input().strip()
        verstr = getJavaVer(path or None, allow_fallback=not path)
        check_result = checkJavaVer(verstr)
        print(f"OK {verstr} {check_result}", flush=True)
    except EOFError:
        print("ERROR No input received from host", flush=True)
    except JavaNotFound as exc:
        print("NOT_FOUND", flush=True)
    except JavaInvalid as exc:
        print(f"INVALID {exc}", flush=True)
    except JavaBroken as exc:
        print(f"BROKEN {exc}", flush=True)
    except JavaTimeout as exc:
        print("TIMEOUT", flush=True)
    except Exception as exc:
        print(f"ERROR {exc}", flush=True)

if __name__ == "__main__":
    main()
