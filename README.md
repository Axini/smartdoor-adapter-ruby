# Description

This project defines a *Ruby* implementation of a plugin adapter (PA) for Axini's standalone SmartDoor application. It connects the Axini Modeling Platform (AMP) to the standalone SmartDoor application. 

See https://github/axini and the plugin-adapter-protocol repository for some general information on Axini's plugin adapter protocol. Axini's training on "plugin adapters" provides additional and more detailed information.

Like the plugin adapters in other programming languages, this Ruby implementation of the SmartDoor adapter follows Axini's preferred plugin adapter architecture. We removed any in-house dependencies and tried to limit the dependencies on other external gems (e.g., google-protobuf, websocket-driver, etc.). Moreover, we tried to keep the organization and architecture of the adapter as close as possible to existing plugin adapters for SmartDoor that we developed in other programming languages (i.e., Java, C++ and Python).

The software is distributed under the MIT license, see LICENSE.txt.


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
`$ bundle install`

The adapter itself can then be executed with:
`$ bundle exec ruby ./bin/run_adapter.rb`
Be sure to update the name, url and token variables, though.


# Some notes on the implementation

The AMP related code is stored in lib/smartdoor-ruby/generic and can be used as-is for **any** Ruby plugin adapter. All SUT specific code (in this case for the SmartDoor SUT) is stored in lib/smartdoor-ruby/smartdoor and should be modified for any new SUT.

## Threads
The main thread of the adapter ensures that messages from AMP are received and handled. The SmartdoorConnection class (in lib/smartdoor-ruby/smartdoor) starts a separate thread which is used for the messages from the SmartDoor SUT over the WebSocket connection between the SUT and the adapter. 

The class QThread (in lib/smartdoor-ruby/generic) manages a Queue of items and a Thread. Items can be added to the Queue and the Thread processes items from the queue in a FIFO manner. The Queue can also be emptied. The plugin adapter (class AdapterCore in lib/smartdoor-ruby/generic) uses two QThreads for (i) handling messages from AMP and (ii) sending messages to AMP. This ensures that messages from AMP (stimuli) and the SUT (responses) are serviced immediately: any resulting message is added to a queue of pending messages which is processed by either one of the two QThreads.

Using a separate QThread for sending the responses to AMP ensures that only a single WebSocket message can be in transit to AMP. 

The QThread for the messages from AMP (Configuration, Ready, stimuli) is needed for a different reason. The processing of actual ProtoBuf messages from AMP may take some (considerable) time. For instance, after a Configuration message, the SUT has to be started and after a Reset message the SUT has to be reset to its initial state. And even the handling of a stimulus at the SUT may take some time. The WebSocket library is single threaded which means that as long as the BrokerConnection's on_message method is being executed, the websocket library cannot handle any new WebSocket message from AMP, including heartbeat (ping) messages. Therefore, the AdapterCore uses a separate QThread to handle ProtoBuf messages from AMP. When a ProtoBuf message is received from AMP, the on_message method calls the AdapterCore's handle_message method which only adds this message to the queue of pending messages. This ensures that the WebSocket thread is always ready to react on new WebSocket messages from AMP.

The plugin adapter and all its threads are set to run forever. No code is added to gracefully terminate the adapter and its threads. Consequently, when terminating the adapter with Ctrl-C, you will observe several Exceptions on the stderr. This is harmless, though.


# Current limitations

- Documentation is lacking. Minor comments for the classes and methods.
- The BrokerConnection and SmartDoorConnection share similar code; they could be defined as subclasses of the same (abstract) Connection class which defines the overlapping methods. Note that this is only possible for this adapter for the SmartDoor application as both the connection to AMP and to the SmartDoor application is over WebSockets.
- The logging of the adapter is rather verbose. Several of the logger.info calls could be replaced by logger.debug calls.
- Error handling should be improved upon.
- Virtual stimuli to inject bad weather behavior could be added.
- (Unit) tests are missing.
