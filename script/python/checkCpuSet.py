import os


def _get_info() -> dict:
    """
    Read the CPU feature flags through `py-cpuinfo`'s public API.

    Only the public `get_cpu_info()` is used so the check keeps working across every
    platform (Linux / Windows / macOS) without relying on private, platform-specific
    helpers that may change between releases.

    `get_cpu_info()` shells out to tools such as `dmesg` and reads `os.environ['PATH']`
    while probing. A process started with an empty environment (some launchers, services
    and sandboxes do this) therefore makes it raise `KeyError: 'PATH'` before it ever
    reaches the CPUID probe, so a missing `PATH` is supplied temporarily.
    """
    from cpuinfo import get_cpu_info
    if 'PATH' in os.environ:
        return get_cpu_info()
    # An empty environment: give py-cpuinfo a PATH for the duration of the probe and put the
    # environment back exactly as it was, so this cannot leak into later code.
    os.environ['PATH'] = os.defpath
    try:
        return get_cpu_info()
    finally:
        del os.environ['PATH']


def checkVulnerableSet() -> list:
    info_raw = _get_info()
    flags = info_raw["flags"]
    return ["avx512f" in flags, "avx512bw" in flags, "avx512vbmi" in flags, "bmi2" in flags, info_raw["arch"].lower()]

def main():
    """
    Entry point invoked by PyRunner, which imports this module and calls ``main()``.  
    
    Prints a single line with the four instruction-set flags for Godot to consume.
    Errors are reported as ``"ERROR <message>"`` so the host can surface them
    instead of hanging.
    """
    try:
        result = checkVulnerableSet()
        print(f"{result[0]} {result[1]} {result[2]} {result[3]} {result[4]}", flush=True)
    except Exception as exc:
        print(f"ERROR {exc}", flush=True)

if __name__ == "__main__":
    main()
