from cpuinfo import get_cpu_info

def checkVulnerableSet() -> list[bool]:
    flags = get_cpu_info()["flags"]
    return ["avx512f" in flags, "avx512bw" in flags, "avx512vbmi" in flags, "bmi2" in flags]

def main():
    """
    Entry point invoked by PyRunner, which imports this module and calls ``main()``.  
    
    Prints a single line with the four instruction-set flags for Godot to consume.
    Errors are reported as ``"ERROR <message>"`` so the host can surface them
    instead of hanging.
    """
    try:
        result = checkVulnerableSet()
        print(f"{result[0]} {result[1]} {result[2]} {result[3]}", flush=True)
    except Exception as exc:
        print(f"ERROR {exc}", flush=True)

if __name__ == "__main__":
    main()