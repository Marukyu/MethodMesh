#include <SFML/Audio/Music.hpp>
#include <SFML/System/Sleep.hpp>
#include <SFML/System/Time.hpp>
#include <iostream>
#include <fstream>
#include <memory>
#include <string>
#include <vector>

std::vector<char> readFile(std::string fileName)
{
        std::ifstream f(fileName);
        std::vector<char> data;
        f.seekg(0, std::ios::end);
        data.resize(f.tellg());
        f.seekg(0, std::ios::beg);
        f.read(data.data(), data.size());
        return data;
}

std::unique_ptr<sf::Music> play(const std::vector<char> & buffer, sf::Time offset)
{
        std::unique_ptr<sf::Music> music = std::make_unique<sf::Music>();
        music->openFromMemory(buffer.data(), buffer.size());

        music->setLoop(true);
        music->setVolume(20);
        music->setPitch(1);
        music->play();

        if (offset != sf::Time::Zero)
        {
                music->setPlayingOffset(offset);
                std::cout << "Playing at " << offset.asMicroseconds() << " us" << std::endl;
        }
        else
        {
                std::cout << "Playing from start" << std::endl;
        }

        return std::move(music);
}

int main()
{
        auto buffer = readFile("testsound.ogg");

        std::unique_ptr<sf::Music> music;

        music = play(buffer, sf::Time::Zero);       // Playing from the start: sound loops correctly
        sf::sleep(sf::seconds(5));
        music = play(buffer, sf::microseconds(20)); // Issue occurs here: sound does not loop
        sf::sleep(sf::seconds(5));
        music = play(buffer, sf::microseconds(25)); // No issue here, sound loops properly
        sf::sleep(sf::seconds(5));

        return 0;
}
 
