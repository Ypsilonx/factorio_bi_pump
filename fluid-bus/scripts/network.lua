--- Čistá logika sítí busu: segmenty (uzly) spojené aktivními spojkami (hrany) → komponenty.
--- Bez herního API, testy: tests/unit/test_network.lua.
local M = {}

--- Kořen prvku v union-find (s kompresí cesty).
--- @param parent table<integer, integer>
--- @param x integer
--- @return integer
local function find(parent, x)
  while parent[x] ~= x do
    parent[x] = parent[parent[x]]
    x = parent[x]
  end
  return x
end

--- Složí sítě z hran. Sítě jsou seřazené podle nejmenšího segmentu; pořadí segmentů a spojek uvnitř sítě
--- se netřídí (u velkého busu by třídění stálo milisekundy) – je deterministické, ale nespecifikované.
--- Hrana se použije jen když je aktivní, má obě strany a strany jsou různé segmenty.
--- @param edges table[] { id = unit_number, a = segment|nil, b = segment|nil, active = boolean }
--- @return table[] { segments = integer[], couplers = integer[] }
function M.build(edges)
  local parent, used = {}, {}
  for _, edge in ipairs(edges) do
    if edge.active and edge.a and edge.b and edge.a ~= edge.b then
      parent[edge.a] = parent[edge.a] or edge.a
      parent[edge.b] = parent[edge.b] or edge.b
      local ra, rb = find(parent, edge.a), find(parent, edge.b)
      if ra ~= rb then
        if ra < rb then parent[rb] = ra else parent[ra] = rb end
      end
      used[#used + 1] = edge
    end
  end
  local by_root, roots = {}, {}
  for segment in pairs(parent) do
    local root = find(parent, segment)
    if not by_root[root] then
      by_root[root] = { segments = {}, couplers = {} }
      roots[#roots + 1] = root
    end
    table.insert(by_root[root].segments, segment)
  end
  for _, edge in ipairs(used) do table.insert(by_root[find(parent, edge.a)].couplers, edge.id) end
  table.sort(roots)
  local result = {}
  for _, root in ipairs(roots) do result[#result + 1] = by_root[root] end
  return result
end

return M
