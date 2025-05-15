.PHONY: run
run: 
	iex -S mix phx.server

.PHONY: digest
digest:
	rm -f priv/static/dictionary-*.txt*
	rm -f priv/static/robots-*
	rm -f priv/static/test-*.txt*
	mix phx.digest
