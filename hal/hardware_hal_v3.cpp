#include <iostream>
#include <cstdint>

/**
 * Project-RISE: Bunker Core HAL (Hardware Abstraction Layer) v3
 * 映射 bunker_core.v 之暫存器與底層狀態控制
 */

#define BUNKER_BASE_ADDR       0x40001000
#define REG_SYS_CTRL           *(volatile uint32_t*)(BUNKER_BASE_ADDR + 0x00)
#define REG_NODE_STATUS        *(volatile uint32_t*)(BUNKER_BASE_ADDR + 0x04)
#define REG_DEFENSE_STATUS     *(volatile uint32_t*)(BUNKER_BASE_ADDR + 0x08)

class BunkerHAL {
public:
    static void init() {
        std::cout << "[HAL v3] Bunker Hardware Abstraction Layer initialized." << std::endl;
        std::cout << "[HAL v3] Base Address mapped to: 0x" << std::hex << BUNKER_BASE_ADDR << std::endl;
    }

    static void reset_hardware() {
        REG_SYS_CTRL &= ~(1 << 0);
        REG_SYS_CTRL |= (1 << 0);
        std::cout << "[HAL v3] Hardware reset toggle executed." << std::endl;
    }

    static void get_defense_status(bool &door_dropped, bool &honeypot_on, bool &alarm_on) {
        uint32_t val = REG_DEFENSE_STATUS;
        door_dropped = (val & (1 << 0)) != 0;
        honeypot_on  = (val & (1 << 1)) != 0;
        alarm_on     = (val & (1 << 2)) != 0;
    }

    static uint8_t get_consensus_node_mask() {
        return static_cast<uint8_t>(REG_NODE_STATUS & 0x07);
    }
};

int main() {
    BunkerHAL::init();
    BunkerHAL::reset_hardware();
    std::cout << "[HAL v3] Driver successfully bound to bunker_core register map." << std::endl;
    return 0;
}
