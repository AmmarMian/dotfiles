-- Récupère une entrée BibTeX depuis un DOI (ou un identifiant arXiv) et
-- l'ajoute au fichier .bib du projet.
--
-- La source est la négociation de contenu de doi.org : elle renvoie du BibTeX
-- brut, sur une seule ligne, avec parfois une clé de citation inutilisable
-- (DataCite renvoie l'URL complète). On reformate et on régénère la clé.

local M = {}

local WIDTH = 79

---Découpe le corps d'une entrée sur les virgules de premier niveau.
local function split_fields(body)
  local parts, depth, start = {}, 0, 1
  for i = 1, #body do
    local c = body:sub(i, i)
    if c == "{" then
      depth = depth + 1
    elseif c == "}" then
      depth = depth - 1
    elseif c == "," and depth == 0 then
      parts[#parts + 1] = body:sub(start, i - 1)
      start = i + 1
    end
  end
  parts[#parts + 1] = body:sub(start)
  return parts
end

---Enveloppe `nom = {valeur},` en alignant les continuations sous l'accolade.
local function wrap(name, value)
  local head = ("  %s = %s"):format(name, value)
  if #head + 1 <= WIDTH or not value:match("^{") then
    return head .. ","
  end
  local indent = (" "):rep(#("  " .. name .. " = {"))
  local lines, current = {}, nil
  for word in value:sub(2, -2):gmatch("%S+") do
    if not current then
      current = ("  %s = {%s"):format(name, word)
    elseif #current + 1 + #word <= WIDTH then
      current = current .. " " .. word
    else
      lines[#lines + 1] = current
      current = indent .. word
    end
  end
  lines[#lines + 1] = current .. "},"
  return table.concat(lines, "\n")
end

---Clé de citation : Nom_Année, à l'image des entrées existantes.
local function make_key(fields)
  local author = fields.author or fields.editor or ""
  local last = author:match("^{?([^,{}]+),") -- « Nom, Prénom and ... »
    or author:match("^{?%S+%s+([^%s{}]+)") -- « Prénom Nom and ... »
    or "Anon"
  last = last:gsub("[^%a]", "")
  local year = (fields.year or fields.date or ""):match("%d%d%d%d") or "0000"
  return ("%s_%s"):format(last:sub(1, 1):upper() .. last:sub(2), year)
end

---@param raw string  entrée BibTeX brute
---@return string?, string?  entrée reformatée, clé
local function reformat(raw)
  local etype, body = raw:match("^%s*@(%w+)%s*{(.*)}%s*$")
  if not etype then
    return nil, nil
  end

  local parts = split_fields(body)
  local key = vim.trim(table.remove(parts, 1))

  local fields, order = {}, {}
  for _, part in ipairs(parts) do
    local name, value = vim.trim(part):match("^([%w_-]+)%s*=%s*(.+)$")
    if name then
      name = name:lower()
      fields[name] = value
      order[#order + 1] = name
    end
  end

  -- Une clé absente, vide ou contenant une URL n'est pas utilisable telle quelle
  if key == "" or key:match("[^%w_:%-%.]") then
    key = make_key(fields)
  end

  local lines = { ("@%s{%s,"):format(etype:lower(), key) }
  for _, name in ipairs(order) do
    lines[#lines + 1] = wrap(name, vim.trim(fields[name]))
  end
  lines[#lines + 1] = "}"
  return table.concat(lines, "\n"), key
end

---Fichiers .bib à la racine du projet.
local function bib_files()
  local root = vim.fs.root(0, { ".git", "*.bib" }) or vim.fn.getcwd()
  return vim.fn.glob(root .. "/*.bib", false, true)
end

local function append(file, entry, key)
  if vim.fn.filereadable(file) == 1 then
    local existing = table.concat(vim.fn.readfile(file), "\n")
    if existing:find("{" .. key .. "%s*,") then
      vim.notify(("%s est déjà dans %s"):format(key, vim.fn.fnamemodify(file, ":t")), vim.log.levels.WARN)
      return false
    end
  end
  vim.fn.writefile(vim.split("\n" .. entry .. "\n", "\n"), file, "a")
  vim.fn.setreg("+", key)
  vim.notify(("%s ajouté à %s (clé dans le presse-papier)"):format(key, vim.fn.fnamemodify(file, ":t")))
  return true
end

---Depuis un tampon .tex : propose d'insérer la citation là où on était.
---@param origin table? { buf = bufnr, pos = { ligne, colonne } }
local function offer_cite(origin, key)
  if not (origin and vim.api.nvim_buf_is_valid(origin.buf)) then
    return
  end
  if vim.bo[origin.buf].filetype ~= "tex" then
    return
  end
  local prompt = ("Insérer \\cite{%s} à la position du curseur ?"):format(key)
  if vim.fn.confirm(prompt, "&Oui\n&Non", 1) ~= 1 then
    return
  end

  local row, col = origin.pos[1], origin.pos[2]
  local line = vim.api.nvim_buf_get_lines(origin.buf, row - 1, row, false)[1]
  if not line then
    return
  end
  -- Comme `p` : après le caractère sous le curseur, jamais au-delà de la ligne
  local at = math.min(col + 1, #line)
  local text = ("\\cite{%s}"):format(key)
  vim.api.nvim_buf_set_text(origin.buf, row - 1, at, row - 1, at, { text })

  local win = vim.fn.bufwinid(origin.buf)
  if win ~= -1 then
    vim.api.nvim_win_set_cursor(win, { row, at + #text - 1 })
  end
end

---@param input string  DOI, URL doi.org, arXiv:1234.5678 ou 1234.5678
---@param origin table?  tampon et curseur d'origine (défaut : position courante)
function M.fetch(input, origin)
  origin = origin or { buf = vim.api.nvim_get_current_buf(), pos = vim.api.nvim_win_get_cursor(0) }
  local id = vim.trim(input)
    :gsub("^https?://d[xo]i%.org/", "")
    :gsub("^doi:%s*", "")
  -- arXiv passe par le DOI DataCite que arXiv dépose pour chaque prépublication
  local arxiv = id:match("^ar[Xx]iv:%s*(.+)$") or (id:match("^%d%d%d%d%.%d+v?%d*$") and id)
  if arxiv then
    id = "10.48550/arXiv." .. arxiv
  end
  if id == "" then
    return
  end

  local targets = bib_files()
  if #targets == 0 then
    vim.notify("Aucun fichier .bib trouvé à la racine du projet", vim.log.levels.ERROR)
    return
  end

  vim.system(
    { "curl", "-sLf", "-H", "Accept: application/x-bibtex", "https://doi.org/" .. id },
    { text = true },
    vim.schedule_wrap(function(res)
      if res.code ~= 0 or not res.stdout:match("^%s*@") then
        vim.notify(("DOI introuvable : %s"):format(id), vim.log.levels.ERROR)
        return
      end
      local entry, key = reformat(res.stdout)
      if not entry then
        vim.notify("Réponse BibTeX illisible :\n" .. res.stdout, vim.log.levels.ERROR)
        return
      end
      if #targets == 1 then
        if append(targets[1], entry, key) then
          offer_cite(origin, key)
        end
      else
        vim.ui.select(targets, {
          prompt = "Ajouter " .. key .. " à :",
          format_item = function(f)
            return vim.fn.fnamemodify(f, ":t")
          end,
        }, function(choice)
          if choice and append(choice, entry, key) then
            offer_cite(origin, key)
          end
        end)
      end
    end)
  )
end

---Sans argument : demande, en pré-remplissant avec le presse-papier s'il
---ressemble à un DOI.
function M.prompt()
  -- Capturé avant l'invite : elle ouvre une fenêtre flottante, donc le tampon
  -- et le curseur « courants » ne sont plus les bons dans le rappel.
  local origin = { buf = vim.api.nvim_get_current_buf(), pos = vim.api.nvim_win_get_cursor(0) }
  local clip = vim.trim(vim.fn.getreg("+") or "")
  local default = (clip:match("10%.%d+/") or clip:match("^ar[Xx]iv:")) and clip or ""
  vim.ui.input({ prompt = "DOI / arXiv : ", default = default }, function(input)
    if input and input ~= "" then
      M.fetch(input, origin)
    end
  end)
end

return M
