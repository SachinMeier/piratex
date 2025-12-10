defmodule PiratexWeb.Live.StylePreview do
  use PiratexWeb, :live_view

  import PiratexWeb.Components.PiratexComponents

  def render(assigns) do
    ~H"""
    <div class="max-w-6xl mx-auto px-6 py-12 space-y-10">
      <div class="theme-card rounded-2xl p-8 text-brand-ink shadow-xl">
        <div class="flex flex-wrap items-center gap-3">
          <span class="badge-pill bg-brand-jade/25 text-brand-navy">Design Preview</span>
          <span class="badge-pill bg-brand-gold/25 text-brand-navy">Tropical Pirate</span>
        </div>
        <h1 class="mt-4 font-sahitya text-4xl text-brand-navy">
          A brighter Pirate Scrabble experience
        </h1>
        <p class="mt-3 text-brand-ink/80 leading-relaxed max-w-3xl">
          Rich navy seas, sandy tiles, and lively coral highlights bring warmth and clarity
          to the board. Buttons shimmer, tiles feel tangible, and inputs are calm glassy
          panels ready for your crew's next voyage.
        </p>
      </div>

      <div class="grid gap-6 md:grid-cols-2">
        <div class="theme-card rounded-2xl p-8 text-brand-ink space-y-6">
          <div class="space-y-2">
            <p class="badge-pill bg-brand-coral/20 text-brand-navy w-fit">Call to Action</p>
            <h2 class="font-sahitya text-2xl text-brand-navy">Buttons & Inputs</h2>
            <p class="text-brand-ink/80">
              Primary actions glow with a coral → gold → jade gradient. Inputs sit on
              misted glass with jade focus rings for steady navigation.
            </p>
          </div>

          <div class="flex flex-wrap gap-3">
            <.ps_button class="shadow-[0_14px_32px_rgba(255,107,107,0.28)]">
              Start Voyage
            </.ps_button>
            <.ps_button class="bg-brand-mist text-brand-ink border border-brand-jade/60 shadow-none">
              Secondary
            </.ps_button>
            <.ps_button disabled={true}>
              Disabled
            </.ps_button>
          </div>

          <div class="space-y-3">
            <.ps_text_input
              id="preview-codename"
              name="codename"
              field={:codename}
              label="Codename"
              placeholder="Enter your pirate name..."
            />
            <p class="text-sm text-brand-ink/70">
              Jade glints show focus and success states; coral highlights errors.
            </p>
          </div>
        </div>

        <div class="theme-card-dark rounded-2xl p-8 text-brand-sand space-y-6">
          <div class="flex items-center gap-3">
            <p class="badge-pill bg-brand-gold/25 text-brand-navy">Tiles</p>
            <p class="badge-pill bg-brand-jade/25 text-brand-navy">Glow</p>
          </div>
          <h2 class="font-sahitya text-2xl text-brand-gold">Tiles & States</h2>
          <p class="text-brand-sand/80">
            Sand faces edged in gold with embossed navy backs. They lift gently on hover
            and flip crisply when revealed.
          </p>
          <div class="flex items-center gap-4">
            <.tile_word word="Ahoy" size="lg" />
            <.tile_word word="Matey" size="md" />
          </div>
          <div class="flex items-center gap-4">
            <.flipping_tile_word word="Flip" />
            <div class="text-brand-sand/70 text-sm">
              Hover to glimpse the navy backs with jade stitching.
            </div>
          </div>
        </div>
      </div>

      <div class="theme-card rounded-2xl p-8 text-brand-ink space-y-4">
        <div class="flex flex-wrap items-center gap-3">
          <span class="badge-pill bg-brand-jade/20 text-brand-navy">Body Copy</span>
          <span class="badge-pill bg-brand-coral/20 text-brand-navy">Legibility</span>
        </div>
        <h2 class="font-sahitya text-2xl text-brand-navy">Readable, warm, and lively</h2>
        <p class="text-brand-ink/85 leading-relaxed">
          This palette keeps contrast high while staying playful. Navy anchors the scene;
          sand panels soften it; gold and coral guide attention; jade signals safety and
          action. Rounded corners, soft shadows, and glassy fills add depth without clutter.
        </p>
      </div>
    </div>
    """
  end
end
