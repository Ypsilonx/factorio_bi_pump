--- Čistá matematika vyrovnávání sítě busu. Kapalina se přelévá přes zásobník sítě (buffer):
--- přebytek segmentu se do něj odebere, nedostatek se z něj doplní – množství se tak přesně zachovává.
--- Bez herního API, testy: tests/unit/test_balance_math.lua.
local M = {}

--- Odchylka od cíle (podíl kapacity segmentu), pod kterou se nepřelévá – šetří UPS. Laditelné.
M.TOLERANCE = 0.005

--- Cílové naplnění sítě (0–1): veškerá kapalina včetně zásobníku rozdělená na celkovou kapacitu.
--- @param total_amount number součet kapaliny v segmentech
--- @param buffer_amount number kapalina v zásobníku sítě
--- @param total_capacity number součet kapacit segmentů
--- @return number
function M.target_fraction(total_amount, buffer_amount, total_capacity)
  if total_capacity <= 0 then return 0 end
  return math.min(1, (total_amount + buffer_amount) / total_capacity)
end

--- Kolik kapaliny přelít u segmentu.
--- @param amount number kapalina v segmentu
--- @param capacity number kapacita segmentu
--- @param fraction number cílové naplnění
--- @param buffer_amount number kolik má zásobník
--- @return number >0 doplnit ze zásobníku, <0 odebrat do zásobníku, 0 nic
function M.plan(amount, capacity, fraction, buffer_amount)
  local delta = fraction * capacity - amount
  if math.abs(delta) < M.TOLERANCE * capacity then return 0 end
  if delta > 0 then return math.min(delta, buffer_amount) end
  return delta
end

--- Přidá kapalinu do zásobníku; teplota = vážený průměr.
--- @param buffer table { amount, temperature? }
--- @param amount number
--- @param temperature number|nil teplota přidávané kapaliny (nil = převezme teplotu zásobníku)
--- @return table nový zásobník
function M.mix(buffer, amount, temperature)
  if amount <= 0 then return buffer end
  temperature = temperature or buffer.temperature
  local total = buffer.amount + amount
  local mixed = temperature
  if buffer.temperature and temperature then
    mixed = (buffer.temperature * buffer.amount + temperature * amount) / total
  end
  return { amount = total, temperature = mixed }
end

--- Odebere kapalinu ze zásobníku.
--- @param buffer table
--- @param amount number
--- @return table nový zásobník (prázdný = bez teploty)
function M.take(buffer, amount)
  local left = buffer.amount - amount
  if left <= 1e-9 then return { amount = 0 } end
  return { amount = left, temperature = buffer.temperature }
end

return M
