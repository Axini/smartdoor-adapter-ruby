// Copyright 2023 Axini B.V. https://www.axini.com, see: LICENSE.txt.

# Description

This project defines a Ruby implementation of a plugin adapter (PA) for Axini's standalone SmartDoor application. It connects the Axini Modeling Platform (AMP) to the standalone SmartDoor application. 

Like the plugin adapters in other programming languages, this Ruby implementation of the SmartDoor adapter follows Axini's preferred plugin adapter architecture. We removed any in-house dependencies and tried to limit the dependencies on other external gems (e.g., google-protobuf, websocket-driver, etc.). Moreover, we tried to keep the organization and architecture of the adapter as close as possible to existing SmartDoor adapters that we developed in other programming languages (i.e., Java and C++).

This is an initial version of the implementation; it is still work in progress.


# External libraries

The adapter uses some libraries (Ruby gems) from external parties, which are all available from https://rubygems.org. We use `bundler` to install and update these gems (and their dependencies).

## Protocol Buffers (protobuf)
https://developers.google.com/protocol-buffers

Google Protocol Buffers is a free and open-source cross-platform data format used to serialize structured data. 

The directory `./lib/smartdoor-ruby/proto` contains the Protobuf .proto files defining the Protobuf messages of Axini's 'Plugin Adapter Protocol'. The directory `./lib/smartdoor-ruby/pa_protobuf` contains the `*_pb.rb` files, which have been generated from theses `.proto` files using Protobuf's `protoc` compiler. The `./lib/smartdoor-ruby/proto` directory contains a makefile to (re)generate the Ruby `*_pb.rb` files. 

## Faye Websocket Driver
https://github.com/faye/websocket-driver-ruby

The Faye Websocket Driver provides a complete implementation of the WebSocket protocols that can be hooked up to any TCP library. 

## Logging
https://rubygems.org/gems/logging

Logging is a flexible logging library for use in Ruby programs based on the design of Java's log4j library.


# Adapter

The dependencies of the adapter can be installed using bundler:
$ bundle install

The adapter itself can then be executed with:
$ bundle exec ruby ./bin/run_adapter.rb
Be sure to update the name, url and token variables, though.

# Current limitations

- Documentation is lacking. Minor comments for the classes and methods.
- The BrokerConnection and SmartDoorConnection share similar code; they could be defined as subclasses of the same (abstract) Connection class which defines the overlapping methods. Note that this is only possible for this adapter for the SmartDoor application as both the connection to AMP and to the SmartDoor application is over WebSockets.
- The logging of the adapter is rather verbose. Several of the logger.info calls could be replaced by logger.debug calls.
- Error handling should be improved upon.
- Virtual stimuli to inject bad weather behavior could be added.
- (Unit) tests are missing.


# License

The source code of the adapter is distributed under the BSD License. See LICENSE.txt.
