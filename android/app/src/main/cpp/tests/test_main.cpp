#include "test_main.h"

Registry& GetRegistry() {
  static Registry registry;
  return registry;
}

int RunAllTests() {
  int failures = 0;
  int passed = 0;
  for (const auto& entry : GetRegistry()) {
    try {
      entry.second();
      ++passed;
      std::printf("[PASS] %s\n", entry.first.c_str());
    } catch (const std::exception& e) {
      ++failures;
      std::printf("[FAIL] %s: %s\n", entry.first.c_str(), e.what());
    } catch (...) {
      ++failures;
      std::printf("[FAIL] %s: unknown exception\n", entry.first.c_str());
    }
  }
  std::printf("\n%d passed, %d failed\n", passed, failures);
  return failures == 0 ? 0 : 1;
}

int main() { return RunAllTests(); }
