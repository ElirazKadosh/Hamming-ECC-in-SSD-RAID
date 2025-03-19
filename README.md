# Hamming ECC in SSD RAID 5
Simulation and RTL implementation of data protection using Hamming (12,8) ECC in RAID 5 SSD storage systems.

---

## 📦 Project Structure

```
docs/          # Project report, graphs, and analysis
python_sim/    # Python code for simulation and visualization
rtl/           # RTL implementation in SystemVerilog
testbench/     # Testbenches for verifying the RTL
synth/         # Synthesis and layout results
```

---

## 🚀 How to Run Python Simulations
1. Navigate to `python_sim/`:
   ```bash
   cd python_sim
   python raid5_simulator.py
   ```
2. Results and graphs will be saved in `docs/graphs/`.

---

## 🧩 RTL Design
- Modules include:
  - Hamming Encoder/Decoder
  - Parity Calculator
  - RAID Controller
- Synthesized using Synopsys Design Vision.
- Layout via Cadence Innovus (Tower CMOS 0.18μm).

---

## 📊 Results
- 40% improvement in Wear Leveling (Round Robin vs Fixed Parity).
- ECC reduced memory reads by 33% in SBE cases.

---

## 👥 Authors
- Eliraz Kadosh
- Eliram Amrusi

Project supervised by Amit Berman, VLSI Lab, Technion.
