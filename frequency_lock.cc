#include <iostream>
#include <string>

int main() {
  auto drift = 0LL;
  while (!std::cin.eof()) {
    std::string line;
    std::getline(std::cin, line);
    if (line.size() == 0) {
      break;
    }
    std::cout << "line: " << line << " ";
    const auto value = std::stoll(line);
    std::cout << value << std::endl;
    drift += value;
  }
  std::cout << "drift: " << drift << std::endl;
}
