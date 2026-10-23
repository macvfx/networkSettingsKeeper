# Changelog

## 0.2.0 (build 4)
- Export a saved profile to a `.nskprofile` file and import it on another Mac, with adapter
  choice, a same-network address check, an in-use check and a suggested free address.
- Double-clicking a `.nskprofile` file opens it for import.
- Unit tests for the address checks and the file format.

## 0.1.0 (build 3)
- Help and the main window link to code.matx.ca.

## 0.1.0 (build 2)
- Fix: the first line of the Help window was cut off. Cause: the intro text had no room to wrap
  in a fixed-width window; it now grows to fit.

## 0.1.0 (build 1)
- First version: save an Ethernet adapter's IPv4, DNS, MTU and media settings, detect changes
  by hardware address, notify, and restore with administrator approval.
