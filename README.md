# Java4Shell Detector

A detector to detect a critical vulnerability found in Java. See [the security advisory](https://calif.io/java4shell) to learn more about it.

If java flagged as "AFFECTED" and all 4 CPU instruction sets are supported, you are vulnerable to RCE attack via Java4Shell. **UPDATE YOUR JAVA INSTALLATION IMMEDIATELY.**  
Even though your CPU doesn't support all 4 instruction sets, Using a vulnerable java installation is still not recommended.

Currently supports Windows and Linux.

## Install

Go to [release page](https://github.com/JerryHan3/java4shell-detector/releases/latest) and download the software suite for your operating system.

Check [COPYING.md](https://github.com/JerryHan3/java4shell-detector/blob/main/COPYING.md) for terms of usage.

## Build

Clone the repository and open the project with [Godot](https://godotengine.org/) 4.7.2. Build it in the export window.

If you add external pip packages into any python script used in project, please rebuild PyBundle interpreter. Check [PyBundleGodot](https://github.com/phosxd/PyBundleGodot) for more information.
