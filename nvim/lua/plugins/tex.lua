-- LaTeX : vimtex (mouvements, objets texte, synctex) + texlab (complétion, refs)
-- Aucune compilation automatique : ni à la sauvegarde, ni en continu.
-- localleader = "\" (LazyVim). Sur un clavier français, ajouter dans
-- lua/config/options.lua : vim.g.maplocalleader = "," (avant le chargement de lazy).

return {
  -- Coloration : vimtex fournit sa propre syntaxe (meilleure que treesitter en
  -- LaTeX, et c'est elle qui gère le conceal des symboles maths).
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      if type(opts.ensure_installed) == "table" then
        vim.list_extend(opts.ensure_installed, { "bibtex", "latex" })
      end
      opts.highlight = opts.highlight or {}
      opts.highlight.disable = opts.highlight.disable or {}
      vim.list_extend(opts.highlight.disable, { "latex" })
    end,
  },

  {
    "lervag/vimtex",
    lazy = false, -- le lazy-loading casse la recherche inverse depuis le PDF
    -- vimtex HEAD exige nvim >= 0.12.4 ; tu es en 0.12.3. v2.18 (juillet 2026)
    -- est la dernière version compatible. Retirer ce tag après mise à jour.
    tag = "v2.18",
    init = function()
      -- ── Compilation : à la demande uniquement ────────────────────────────
      vim.g.vimtex_compiler_method = "latexmk"
      vim.g.vimtex_compiler_latexmk = {
        continuous = 0, -- pas de recompilation en tâche de fond
        options = {
          "-verbose",
          "-file-line-error",
          "-synctex=1",
          "-interaction=nonstopmode",
        },
      }
      -- 2 : la quickfix s'ouvre sur erreur mais ne prend pas le curseur.
      -- Les avertissements courants sont filtrés plus bas, donc elle reste
      -- fermée tant que la compilation aboutit.
      vim.g.vimtex_quickfix_mode = 2
      vim.g.vimtex_quickfix_open_on_warning = 0
      vim.g.vimtex_quickfix_method = vim.fn.executable("pplatex") == 1 and "pplatex" or "latexlog"
      vim.g.vimtex_quickfix_ignore_filters = {
        "Underfull \\\\hbox",
        "Overfull \\\\hbox",
        "Package hyperref Warning",
        "Token not allowed in a PDF string",
      }

      -- ── Visionneuse : Skim, avec synctex aller/retour ────────────────────
      vim.g.vimtex_view_method = "skim"
      vim.g.vimtex_view_skim_sync = 1 -- suivre le curseur dans le PDF
      vim.g.vimtex_view_skim_activate = 0 -- ne pas voler le focus
      vim.g.vimtex_view_skim_reading_bar = 1

      -- ── Confort d'édition ────────────────────────────────────────────────
      vim.g.vimtex_mappings_disable = { n = { "K" } } -- K reste le hover LSP
      vim.g.vimtex_indent_on_ampersands = 0 -- pas de réindentation des tableaux d'alignement
      vim.g.vimtex_matchparen_enabled = 1
      vim.g.vimtex_toc_config = {
        mode = 1,
        fold_enable = 1,
        show_help = 0,
        split_pos = "vert botright",
        split_width = 50,
        hotkeys_enabled = 1,
      }
      -- Le conceal masque \alpha → α, ^1 → ¹ … mais jamais sur la ligne du
      -- curseur (concealcursor vide), donc l'édition reste franche.
      vim.g.vimtex_syntax_conceal = {
        accents = 1,
        ligatures = 1,
        cites = 0, -- garder \cite{...} lisible tel quel
        fancy = 1,
        spacing = 0,
        greek = 1,
        math_bounds = 0, -- garder les $ visibles
        math_delimiters = 1,
        math_fracs = 1,
        math_super_sub = 1,
        math_symbols = 1,
        sections = 0,
        styles = 1,
      }
    end,
    config = function()
      -- :Doi 10.1109/… ou :Doi arXiv:2404.02572 — sans argument, demande
      vim.api.nvim_create_user_command("Doi", function(opts)
        local doi = require("util.doi")
        if opts.args == "" then
          doi.prompt()
        else
          doi.fetch(opts.args)
        end
      end, { nargs = "?", desc = "Ajouter une entrée BibTeX depuis un DOI" })

      -- Un projet peut demander des macros définies avant \documentclass pour
      -- les compilations d'écriture (brouillon rapide) : poser à sa racine un
      -- fichier `.vimtex-pretex` contenant par exemple \def\NOPAPERS{1}.
      -- Lu à l'initialisation de chaque tampon, donc indépendant de l'ordre de
      -- démarrage — contrairement à un .nvim.lua, chargé seulement à VimEnter.
      vim.api.nvim_create_autocmd("User", {
        pattern = "VimtexEventInitPost",
        group = vim.api.nvim_create_augroup("am_vimtex_pretex", { clear = true }),
        callback = function()
          local state = vim.b.vimtex
          if not (state and state.root and state.compiler) then
            return
          end
          local file = state.root .. "/.vimtex-pretex"
          if vim.fn.filereadable(file) == 0 then
            return
          end
          local pretex = vim.trim(table.concat(vim.fn.readfile(file), ""))
          if pretex == "" then
            return
          end
          local option = "-usepretex='" .. pretex .. "'"
          if vim.tbl_contains(state.compiler.options or {}, option) then
            return
          end
          -- b:vimtex est une copie côté Lua : il faut muter depuis Vimscript.
          -- vimtex n'échappe pas les options, d'où les quotes autour du pretex.
          vim.cmd(("call add(b:vimtex.compiler.options, %s)"):format(vim.fn.string(option)))
        end,
      })
    end,
    keys = {
      { "<localleader>l", "", desc = "+vimtex", ft = "tex" },
    },
  },

  -- texlab : complétion des \cref/\cite, renommage de labels, diagnostics
  {
    "neovim/nvim-lspconfig",
    opts = {
      -- Les inlay hints de texlab (« Équation (1.13) » collé après \label{})
      -- étaient la principale source de bruit dans le tampon.
      inlay_hints = { exclude = { "vue", "tex", "plaintex", "bib" } },
      servers = {
        texlab = {
          keys = {
            { "<leader>K", "<plug>(vimtex-doc-package)", desc = "Doc du paquet", silent = true },
          },
          settings = {
            texlab = {
              build = { onSave = false, forwardSearchAfter = false },
              chktex = { onOpenAndSave = true, onEdit = false },
              -- « Unused label » sonne faux dans une thèse (labels posés à
              -- l'avance). Vider cette liste pour les revoir.
              diagnostics = { ignoredPatterns = { "^Unused label" } },
              latexFormatter = "latexindent",
              latexindent = { modifyLineBreaks = false },
            },
          },
        },
      },
    },
  },

  -- Réglages de tampon pour la prose
  {
    "LazyVim/LazyVim",
    opts = function()
      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "tex", "plaintex", "bib" },
        group = vim.api.nvim_create_augroup("am_tex", { clear = true }),
        callback = function(ev)
          local o, b = vim.opt_local, ev.buf
          o.spell = true
          o.spelllang = { "fr", "en" } -- zg enrichit ~/.config/nvim/spell/fr.utf-8.add
          o.wrap = true
          o.linebreak = true -- couper entre les mots
          o.breakindent = true
          o.showbreak = "↪ "
          o.textwidth = 0 -- une phrase par ligne : c'est le diff git qui décide
          o.conceallevel = 2
          o.concealcursor = "" -- ligne du curseur toujours en clair
          vim.b[b].autoformat = false -- pas de latexindent à la sauvegarde

          -- Se déplacer par ligne écran quand ça enroule
          local function map(lhs, rhs)
            vim.keymap.set({ "n", "x" }, lhs, rhs, { buffer = b, expr = true })
          end
          map("j", function()
            return vim.v.count == 0 and "gj" or "j"
          end)
          map("k", function()
            return vim.v.count == 0 and "gk" or "k"
          end)

          -- Compilation complète du projet, seulement là où il y a un justfile
          local just_root = vim.fs.root(b, "justfile")
          if just_root and vim.fn.executable("just") == 1 then
            vim.keymap.set("n", "<localleader>lj", function()
              require("snacks").terminal({ "just", "build" }, { cwd = just_root })
            end, { buffer = b, desc = "just build (projet complet)" })
          end
          -- Ajouter une référence depuis un DOI ou un identifiant arXiv
          vim.keymap.set("n", "<localleader>ld", function()
            require("util.doi").prompt()
          end, { buffer = b, desc = "BibTeX depuis un DOI" })

          -- Chercher une référence par auteur / titre / année et la citer
          -- (jamais en mode insertion : « , » y est une virgule ordinaire)
          vim.keymap.set("n", "<localleader>lb", function()
            require("util.bib").pick()
          end, { buffer = b, desc = "Citer (recherche floue)" })
          vim.keymap.set("i", "<C-x><C-b>", function()
            require("util.bib").pick()
          end, { buffer = b, desc = "Citer (recherche floue)" })

          -- (Pour voir la source brute : <leader>uc, le bascule de LazyVim.)
        end,
      })
    end,
  },
}
