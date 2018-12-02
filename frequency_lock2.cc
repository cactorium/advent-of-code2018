#include <iostream>
#include <string>
#include <unordered_map>
#include <vector>

int main() {
  auto drift = 0LL;
  std::unordered_map<long long, int> reached;
  reached[0] = 1;

  std::vector<long long> shifts;
  while (!std::cin.eof()) {
    std::string line;
    std::getline(std::cin, line);
    if (line.size() == 0) {
      break;
    }
    //std::cout << "line: " << line << " ";
    const auto value = std::stoll(line);
    shifts.push_back(value);
  }

  while (true) {
    for (const auto& value : shifts) {
      drift += value;
      std::cout << drift << std::endl;
      if (reached.find(drift) != reached.end()) {
        std::cout << "repeated " << drift << std::endl;
        return 0;
      } else {
        reached[drift] = 1;
      }
    }
  }
}
