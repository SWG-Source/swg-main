
#include "StreamUtils.hpp"
#include "UdpLibrary.hpp"

#include "easylogging++.h"

#include <iomanip>

std::ostream& operator<<(std::ostream& os, const BinaryData& bd) {
    auto length = bd.length();
    auto data = bd.data();

    if (length == 0)
        return os;

    // Calculate the number of lines and extra bits.
    auto lines = static_cast<int16_t>(length / 16);
    auto extra = static_cast<int16_t>(length % 16);

    // Save the formatting state of the stream.
    auto flags = os.flags(os.hex);
    auto fill = os.fill('0');
    auto width = os.width(2);

    // The byte buffer should be printed out in lines of 16 characters and display
    // both hex and ascii values for each character, see most hex editors for
    // reference.
    char ascii[17] = {0};
    unsigned char c;
    for (int16_t i = 0; i <= lines; i++) {
        // Print out a line number.
        os << std::setw(4) << (i * 16) << ":   ";

        for (int16_t j = 0; j < 16; ++j) { // Loop through the characters of this line (max 16)
            // For the last line there may not be 16 characters. In this case filler
            // whitespace should be added to keep column widths consistent.
            if (i == lines && j >= extra) {
                os << "   ";
                ascii[j] = ' ';
            } else {
                c = data[(i * 16) + j];

                os << std::setw(2) << static_cast<unsigned>(c) << " ";

                // If an ascii char print it, otherwise print a . instead of gibberish
                ascii[j] = (c < ' ' || c > '~') ? '.' : c;
            }
        }

        os << "  " << ascii << "\n";
    }

    // Return formatting of stream to its previous state.
    os.flags(flags);
    os.fill(fill);
    os.width(width);

    return os;
}

void logNetworkMessage(
    UdpConnection* connection, std::string message, const unsigned char* data, int length) {
    char hold[256];

    VLOG(1) << "\n"
            << message << " " << connection->GetDestinationIp().GetAddress(hold) << ":"
            << connection->GetDestinationPort() << " length: " << length << "\n"
            << BinaryData{data, length};
}

std::ostream& operator<<(std::ostream& os, const std::u16string& data) {
    os << std::string{std::begin(data), std::end(data)};

    return os;
}
