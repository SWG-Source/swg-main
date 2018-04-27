# dependencies
sudo apt-get install libboost-dev libboost-program-options-dev sqlite3 libsqlite3-dev

# copy udp library
cp -a udplibrary externals/udplibrary

# make
rm -rf build; mkdir build; cd build
cmake ..
cmake --build .
