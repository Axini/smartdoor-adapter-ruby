# makefile to generate Ruby versions from the .proto files

default:
	@echo "makefile does not have a default target"

PROTO_DIR      = ./lib/smartdoor-ruby/generic/proto
RUBY_DEST_DIR  = ./lib/smartdoor-ruby/generic/pa_protobuf

pa_protobuf:
	mkdir -p $(RUBY_DEST_DIR)
	protoc -I ${PROTO_DIR} --ruby_out=${RUBY_DEST_DIR} ${PROTO_DIR}/*.proto

very_clean:
	rm -r -f $(RUBY_DEST_DIR)
