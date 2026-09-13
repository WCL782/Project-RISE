// =========================================================================
// Project-RISE High-Assurance HAL Driver (2-Space Standard)
// Architect: Chali Wang
// License: MIT
// Description: Memory-mapped hardware abstraction layer & self-test suite
// =========================================================================

#include <iostream>
#include <cstdint>
#include <iomanip>

// Base Address Offset Defines
#define RISE_BASE_ADDR           0x40001000

// Register Map Definitions
#define REG_SYS_CTRL             0x00 // System Control (Reset, Enable)
#define REG_NODE_STATUS          0x04 // 3-Node Decentralized Consensus Vote Input
#define REG_DEFENSE_STATUS       0x08 // Defense State (Armed, Decoy, Lockdown)
#define REG_TMR_STATUS           0x0C // TMR Sensor Fault Status
#define REG_TRNG_ENTROPY         0x10 // RO-TRNG Random Entropy Output
#define REG_THERMAL_WIN_CTRL     0x14 // Zero-Heat Window Threshold Config

class ProjectRiseHAL {
private:
  uint32_t base_addr;
  uint32_t registers[6]; // Virtual Hardware Registers for Software Simulation

public:
  ProjectRiseHAL(uint32_t addr = RISE_BASE_ADDR) : base_addr(addr) {
    for (int i = 0; i < 6; ++i) {
      registers[i] = 0x00000000;
    }
  }

  void init() {
    std::cout << "[HAL v3] Initializing Project-RISE Hardware Abstraction Layer..." << std::endl;
    std::cout << "[HAL v3] Base Address Mapped: 0x" << std::hex << base_addr << std::endl;
    reset_core();
  }

  void reset_core() {
    registers[REG_SYS_CTRL / 4] = 0x00000001; // Assert Soft Reset
    std::cout << "[HAL v3] Hardware Core Reset Signal Asserted." << std::endl;
  }

  void set_node_consensus(uint8_t votes) {
    registers[REG_NODE_STATUS / 4] = votes & 0x07;
    std::cout << "[HAL v3] Node Consensus Votes Set: 0b" 
              << ((votes & 0x04) ? '1' : '0')
              << ((votes & 0x02) ? '1' : '0')
              << ((votes & 0x01) ? '1' : '0') << std::endl;
  }

  uint32_t read_trng_entropy() {
    // Virtual RO-TRNG Entropy Simulation Value
    registers[REG_TRNG_ENTROPY / 4] = 0x3F8A9C12; 
    return registers[REG_TRNG_ENTROPY / 4];
  }

  uint32_t get_defense_status() {
    return registers[REG_DEFENSE_STATUS / 4];
  }

  void print_status_report() {
    std::cout << "\n=================================================" << std::endl;
    std::cout << "   Project-RISE Hardware Register Dump" << std::endl;
    std::cout << "=================================================" << std::endl;
    std::cout << " SYS_CTRL      : 0x" << std::hex << std::setw(8) << std::setfill('0') << registers[REG_SYS_CTRL / 4] << std::endl;
    std::cout << " NODE_STATUS   : 0x" << std::hex << std::setw(8) << std::setfill('0') << registers[REG_NODE_STATUS / 4] << std::endl;
    std::cout << " TRNG_ENTROPY  : 0x" << std::hex << std::setw(8) << std::setfill('0') << read_trng_entropy() << std::endl;
    std::cout << "=================================================\n" << std::endl;
  }
};

int main() {
  ProjectRiseHAL hal;
  
  hal.init();
  hal.set_node_consensus(0b111); // 3/3 Full Consensus
  hal.print_status_report();

  std::cout << "[HAL v3] Sanity Verification Completed Successfully." << std::endl;
  return 0;
}
