#pragma once

// Minimal test framework shared by the engine test translation units.
#include <cstdio>
#include <functional>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>

using TestFn = std::function<void()>;
using Registry = std::vector<std::pair<std::string, TestFn>>;

Registry& GetRegistry();

int RunAllTests();

#define QFIL_TEST(name)                                                       \
  struct name##_Registration {                                                \
    static void Run();                                                        \
    name##_Registration() {                                                   \
      GetRegistry().emplace_back(#name, &name##_Registration::Run);           \
    }                                                                         \
  };                                                                          \
  static name##_Registration name##_instance;                                 \
  void name##_Registration::Run()

#define QFIL_ASSERT(condition)                                                \
  do {                                                                        \
    if (!(condition)) {                                                       \
      throw std::runtime_error(std::string("assert failed: ") + #condition +  \
                               " at line " + std::to_string(__LINE__));       \
    }                                                                         \
  } while (0)
