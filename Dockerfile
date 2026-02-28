# Stage 1: Builder
FROM elixir:1.17-otp-27-slim AS builder

RUN apt-get update -y && apt-get install -y build-essential git \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force

ENV MIX_ENV="prod"

# Layer 1: Mix deps (changes rarely)
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

# Layer 2: Assets & source (changes frequently)
COPY priv priv
COPY lib lib
COPY assets assets

# Install tailwind + esbuild binaries, then compile & digest assets
RUN mix assets.setup && mix assets.deploy

# Layer 3: Compile & release
RUN mix compile
COPY config/runtime.exs config/
RUN mix release

# Stage 2: Production runner
FROM debian:bookworm-slim

RUN apt-get update -y && \
    apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

WORKDIR /app
RUN chown nobody /app

ENV MIX_ENV="prod"
ENV PHX_SERVER="true"
ENV PORT="4000"

COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/piratex ./

USER nobody

EXPOSE 4000

CMD ["bin/piratex", "start"]
