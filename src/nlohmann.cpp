// https://github.com/nlohmann/json/blob/develop/docs/mkdocs/docs/examples/accept__string.cpp

#include <iostream>
#include <iomanip>
#include <nlohmann/json.hpp>

using json = nlohmann::json;

int main()
{
    // a valid JSON text
    auto valid_text = R"(
    {
        "numbers": [1, 2, 3, 18446744073709551616]
    }
    )";

    // an invalid JSON text
    auto invalid_text = R"(
    {
        "strings": ["extra", "comma", ]
    }
    )";

    std::cout << std::boolalpha
              << json::accept(valid_text) << ' '
              << json::accept(invalid_text) << '\n';

    auto parsed = json::parse(valid_text);
    parsed["foo"] = "bar";
    std::cout << "Number: "
              << parsed["numbers"][3] << ' '
              << "is float: " << std::boolalpha << parsed["numbers"][3].is_number_float() << '\n';
    std::cout << parsed << '\n';
}
