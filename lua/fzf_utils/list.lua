-- linked list: h (head), n (next), p (prev)
local M = {}

function M.list_create()
  local n = { n = nil, p = nil, v = nil }
  n.n = n
  n.p = n
  return { h = n }
end

function M.node_create(v)
  return { n = nil, p = nil, v = v }
end

function M.insert(l, n)
  local temp = l.h
  l.h = n
end

function M.append(l, n)
  
end

return M
