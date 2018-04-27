# stationapi [![Build Status](https://travis-ci.org/apathyboy/stationapi.svg?branch=master)](https://travis-ci.com/apathyboy/stationapi) #

A base library at the core of applications that implement chat and login functionality across galaxies.

# stationchat

An open implementation of the chat gateway that SOE based games used to provide various social communication features such as mail, custom chat rooms, friend management, etc.

Like my work and want to support my free and open-source contributions? 

[![Donate](https://img.shields.io/badge/Donate-PayPal-green.svg)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=8KCAU8HB9J7YU)

## Implementation ##

Uses the SOE libraries to implement chat features in a standalone utility. Ideally, the completed implementation would allow for multiple galaxies to connect and allow players to communicate across them.

## External Dependencies ##

* c++14 compatible compiler
* boost::program_options
* sqlite3
* udplibrary - bundled in the Star Wars Galaxies official source

## Building ##

    chmod 777 build.sh
    ./build.sh

## Database Initialization ##

By default, a clean database instance is provided and placed with the default configuration files in the **build/bin** directory; therefore, nothing needs to be done for new installations, the db is already created and placed in the appropriate location.

To create a new, clean database instance, use the following commands:

    sqlite3 chat.db
    sqlite> .read /path/to/extras/init_database.sql

Then update the **database_path** config option with the full path to the database.

## Running ##

A default configuration and database is created when building the project. Configure the listen address/ports in **build/bin/stationchat.cfg**. Then run the following commands from the project root:

### Linux ###

    cd build/bin
    ./stationchat

## Final Notes ##

It is recommended to copy the **build/bin** directory to another location after building to ensure the configuration files are not overwritten by future changes to the default versions of these files.
