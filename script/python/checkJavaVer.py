import subprocess, re
_VERSION_RE = re.compile(r'version\s+"?([^\s"]+)"?')

def getJavaVer(path = "java") -> str:
    """
    Execute `java -version` command and parse versioning string from the output.  
    
    **Parameters**  
    `path`: Custom java binary path. If not specified, it will invoke system configured `java` instead.
    """
    result = subprocess.run([path, "-version"], capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"`{path} -version` execution failed: {result.stderr.strip()}")
    output = (result.stderr or "") + (result.stdout or "")
    m = _VERSION_RE.search(output)
    if not m:
        raise RuntimeError(f"Failed to parse Java version from output: \n{output}")
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
    
    Reads the optional Java binary path from stdin and prints a single line
    ``"<version> <check_result>"`` for Godot to consume. Errors are reported as
    ``"ERROR <message>"`` so the host can surface them instead of hanging.
    """
    try:
        path = input()
        if path == "": path = "java"
        verstr = getJavaVer(path)
        check_result = checkJavaVer(verstr)
        print(f"{verstr} {check_result}", flush=True)
    except Exception as exc:
        print(f"ERROR {exc}", flush=True)

if __name__ == "__main__":
    main()
