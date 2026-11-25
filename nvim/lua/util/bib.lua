-- Sélecteur flou sur les entrées BibTeX du projet : on cherche par auteur,
-- titre, année ou clé, et on insère la citation.
--
-- Les entrées sont lues par le parseur de vimtex (b:vimtex connaît les
-- fichiers réellement chargés par le document, y compris \addbibresource).

local M = {}

---@return string[]
local function bib_files()
  local ok, files = pcall(vim.fn["vimtex#bib#files"])
  if ok and type(files) == "table" and #files > 0 then
    return files
  end
  local root = vim.fs.root(0, { ".git", "*.bib" }) or vim.fn.getcwd()
  return vim.fn.glob(root .. "/*.bib", false, true)
end

---Les valeurs repliées sur plusieurs lignes gardent leur indentation, et les
---accolades de protection ({{T}itre}) n'ont pas à être affichées.
local function squeeze(s)
  return vim.trim((tostring(s or ""):gsub("[{}]", ""):gsub("%s+", " ")))
end

---« Dupont, Jean and Martin, Paul » → « Dupont et al. »
local function short_author(author)
  author = squeeze(author)
  if author == "" then
    return ""
  end
  local first = vim.split(author, " and ", { plain = true })[1]
  local last = first:match("^([^,]+),") or first:match("(%S+)$") or first
  return #vim.split(author, " and ", { plain = true }) > 1 and (last .. " et al.") or last
end

---@return snacks.picker.finder.Item[]
function M.entries()
  local items = {}
  for _, file in ipairs(bib_files()) do
    local ok, parsed = pcall(vim.fn["vimtex#parser#bib#parse"], file, vim.empty_dict())
    if ok then
      for _, e in ipairs(parsed) do
        local title, author = squeeze(e.title), squeeze(e.author)
        local venue = squeeze(e.journal ~= "" and e.journal or e.booktitle)
        items[#items + 1] = {
          text = table.concat({ e.key, author, title, e.year or "", venue }, " "),
          key = e.key,
          title = title,
          author = short_author(author),
          year = squeeze(e.year),
          venue = venue,
          file = e.source_file,
          pos = { tonumber(e.source_lnum) or 1, 0 },
        }
      end
    end
  end
  table.sort(items, function(a, b)
    return (a.year or "") > (b.year or "")
  end)
  return items
end

---Insère la clé, en tenant compte d'un \cite{...} déjà ouvert.
---@param key string
---@param insert_mode boolean
function M.insert_key(key, insert_mode)
  local win = vim.api.nvim_get_current_win()
  local row, col = unpack(vim.api.nvim_win_get_cursor(win))
  local line = vim.api.nvim_get_current_line()
  -- En mode normal le curseur est *sur* un caractère : on insère après, comme `p`
  local at = insert_mode and col or math.min(col + 1, #line)

  local before = line:sub(1, at)
  local text
  if before:match("\\%a*cite%a*%*?%s*{[^}]*$") then
    -- déjà dans les accolades : seulement la clé, séparée si besoin
    local tail = before:match("([^{,%s])%s*$")
    text = tail and (", " .. key) or key
  else
    text = ("\\cite{%s}"):format(key)
  end

  vim.api.nvim_buf_set_text(0, row - 1, at, row - 1, at, { text })
  -- Dernier caractère inséré : position valable en mode normal, et point de
  -- départ correct pour le `a` que pick() envoie en mode insertion.
  vim.api.nvim_win_set_cursor(win, { row, math.max(at + #text - 1, 0) })
end

function M.pick()
  local insert_mode = vim.fn.mode():match("^i") ~= nil
  local items = M.entries()
  if #items == 0 then
    vim.notify("Aucune entrée BibTeX trouvée", vim.log.levels.WARN)
    return
  end

  require("snacks").picker.pick({
    source = "bibtex",
    items = items,
    prompt = " ",
    title = "Citations",
    format = function(item)
      local a = {}
      a[#a + 1] = { ("%-20s"):format(item.author:sub(1, 20)), "Function" }
      a[#a + 1] = { " " }
      a[#a + 1] = { ("%-4s"):format(item.year), "Number" }
      a[#a + 1] = { " " }
      a[#a + 1] = { item.title, "Normal" }
      if item.venue ~= "" then
        a[#a + 1] = { "  " .. item.venue, "Comment" }
      end
      return a
    end,
    confirm = function(picker, item)
      picker:close()
      if not item then
        return
      end
      vim.schedule(function()
        M.insert_key(item.key, insert_mode)
        if insert_mode then
          -- `a` replace le curseur juste après le texte inséré ; startinsert
          -- le poserait un caractère trop tôt (ou en fin de ligne avec !).
          vim.api.nvim_feedkeys("a", "n", false)
        end
      end)
    end,
  })
end

return M
