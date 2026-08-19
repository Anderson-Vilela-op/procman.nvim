local memory = require("procman.memory")

describe("memory", function()
  it("children_by_ppid groups pids by parent", function()
    local tree = {
      [1] = { ppid = 0, rss = 100 },
      [2] = { ppid = 1, rss = 50 },
      [3] = { ppid = 1, rss = 30 },
      [4] = { ppid = 2, rss = 10 },
    }
    local children = memory.children_by_ppid(tree)
    table.sort(children[1])
    assert.same({ 2, 3 }, children[1])
    assert.same({ 4 }, children[2])
  end)

  it("total_rss_kb sums the root process and all its descendants", function()
    local tree = {
      [1] = { ppid = 0, rss = 100 },
      [2] = { ppid = 1, rss = 50 },
      [3] = { ppid = 1, rss = 30 },
      [4] = { ppid = 2, rss = 10 },
      [99] = { ppid = 0, rss = 999 },
    }
    local children = memory.children_by_ppid(tree)
    assert.equals(190, memory.total_rss_kb(tree, 1, children))
  end)

  it("total_rss_kb returns 0 for a pid that's no longer in the tree (dead process)", function()
    local tree = { [1] = { ppid = 0, rss = 100 } }
    local children = memory.children_by_ppid(tree)
    assert.equals(0, memory.total_rss_kb(tree, 12345, children))
  end)

  it("format_kb uses KB/MB/GB depending on magnitude", function()
    assert.equals("512KB", memory.format_kb(512))
    assert.equals("2.0MB", memory.format_kb(2048))
    assert.equals("1.50GB", memory.format_kb(1024 * 1024 * 1.5))
    assert.equals("-", memory.format_kb(0))
  end)
end)
