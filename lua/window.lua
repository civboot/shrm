local civ  = require'civ':grequire()
grequire'types'
local term = require'term'

local M = {}

local VSEP = ' |'
local HSEP = '-'

local BufFillerDash = {
  [6] = '------', [3] = '---',  [1] = '-',
}

---------------------
-- Helper Functions for windows
-- Technically these work on Edit or Window, but they often create a Window.

local function isSplitKind(w, kind)
  return ty(w) == Window and w.splitkind == kind
end

-- split the edit horizontally, return the new copied edit
-- (which will be on the top/left)
M.splitEdit = function(edit, kind)
  assert(kind); assert(Edit == ty(edit))
  local container = edit.container
  if not isSplitKind(edit, kind) then
    container = M.wrapWindow(edit)
    container.splitkind = kind
  end
  local new = edit:copy()
  table.insert(container, indexOf(container, edit), new)
  return new
end

-- wrap an edit/window in a new window
M.wrapWindow = function(w)
  local container = w.container
  local wrapped = Window.new(container); wrapped[1] = w
  if ty(container) == Model then container.view = wrapped
  else container[indexOf(container, w)] = wrapped end
  w.container = wrapped
  return wrapped
end

---------------------
-- Window core methods

Window.__index = listIndex
method(Window, 'new', function(container)
  return Window{
    id=nextViewId(),
    container=container,
    tl=-1, tc=-1,
    th=-1, tw=-1,
  }
end)

----------------------------------
-- Draw Window

M.calcPeriod = function(size, sep, num)
  assert(num >= 1)
  sep = sep * (num - 1)
  return math.floor((size - sep) / num)
end

local function drawChild(isLast, point, remain, period, sep)
  local size = (isLast and remain) or period
  point = point + size + ((isLast and 0) or sep)
  remain = remain - size
  return point, remain, size - (isLast and sep or 0)
end

method(Window, 'draw', function(w, term)
  assert(#w > 0, "Drawing empty window")
  if not w.splitkind then
    assert(#w == 1)
    updateFields(w[1], w, {'tl', 'tc', 'th', 'tw'})
    child:draw(term)
    w.canvas = child.canvas
  elseif 'v' == w.splitkind then -- verticle split
    assert(#w > 1)
    local tc, twRemain, period = w.tc, w.tw, M.calcPeriod(w.tw, #VSEP, #w)
    for ci, child in ipairs(w) do
      updateFields(w[ci], w, {'tl', 'th'})
      tc, twRemain, w[ci].tw = drawChild(ci == #w, tc, twRemain, period, #VSEP)
      child:draw(term)
    end
  elseif 'h' == w.splitkind then -- horizontal split
    assert(#w > 1)
    w.canvas = List{}
    local tl, thRemain, period = w.tl, w.th, M.calcPeriod(w.th, #HSEP, #w)
    local li = 1
    for ci, child in ipairs(w) do
      updateFields(w[ci], w, {'tc', 'tw'})
      tl, thRemain, w[ci].th = drawChild(ci == #w, tl, thRemain, period, #HSEP)
      child:draw(term)
      for _, line in ipairs(child.canvas) do
        w.canvas[li] = line; li = li + 1
      end
      if ci < #w then -- separator
        w.canvas[li] = table.concat(fillBuf({}, w.tw, BufFillerDash))
        li = li + 1
      end
    end
  end

end)

return M