from cpuinfo import get_cpu_info

def checkVulnerableSet() -> list[bool]:
    flags = get_cpu_info()["flags"]
    return ["avx512f" in flags, "avx512bw" in flags, "avx512vbmi" in flags, "bmi2" in flags]

if __name__ == "__main__":
    result = checkVulnerableSet()
    print(f"{result[0]} {result[1]} {result[2]} {result[3]}")