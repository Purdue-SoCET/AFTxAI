# flow.mk: `make <block>` turns a block's spec into verified RTL with nex (see flow.sh
# and README.md in this folder).
#
# Run from the AFTxAI root:
#   make -f tools/flow/flow.mk i2c
#
# Targets:
#   make <block>          RTL + testbench in parallel, lint, regression, then fix and rerun
#                         until clean. Stops only for the spec: questions, spec gaps, or
#                         changes to shared files outside the block.
#   make <block>-status   current triage table
#   make flow-list        blocks that have a spec (e.g. peripherals/i2c/I2C.md → i2c)
#
# Settings (make i2c MAX_ROUNDS=5): MAX_ROUNDS (3), STAGE_TIMEOUT (4h), AUTO_APPROVE (1).
# AUTO_APPROVE=0 stops for your approval before each fix, as NEX.md describes.

FLOW_DIR := $(dir $(lastword $(MAKEFILE_LIST)))
FLOW     := $(FLOW_DIR)flow.sh

MAX_ROUNDS    ?= 3
STAGE_TIMEOUT ?= 4h
AUTO_APPROVE  ?= 1

FLOW_BLOCKS := $(shell bash $(FLOW) list 2>/dev/null | cut -f1)

.PHONY: flow-list $(FLOW_BLOCKS) $(addsuffix -status,$(FLOW_BLOCKS))

flow-list:
	@bash $(FLOW) list

$(FLOW_BLOCKS):
	@AUTO_APPROVE=$(AUTO_APPROVE) MAX_ROUNDS=$(MAX_ROUNDS) STAGE_TIMEOUT=$(STAGE_TIMEOUT) \
	  bash $(FLOW) run $@

$(addsuffix -status,$(FLOW_BLOCKS)):
	@bash $(FLOW) status $(@:-status=)
