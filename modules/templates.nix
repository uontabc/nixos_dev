{ inputs, ... }: {
  # Reusable flake templates.
  #
  # All templates from the-nix-way/dev-templates (bun, go, rust, python, ...)
  # are re-exported, e.g. `nix flake init -t .#rust`.
  flake.templates = inputs.dev-templates.templates;
}
