local process = require("procman.process")

local NAME = "svc"

local function add_service(cmd)
  process.services[NAME] = {
    name = NAME,
    cmd = cmd,
    cwd = vim.loop.cwd(),
    status = "stopped",
    rss_kb = 0,
    manual_stop = false,
    pending_restart = false,
  }
end

local function wait_until(predicate, timeout)
  return vim.wait(timeout or 3000, predicate, 20)
end

describe("process lifecycle", function()
  after_each(function()
    pcall(process.stop, NAME)
    wait_until(function()
      local svc = process.get(NAME)
      return not svc or svc.status ~= "running"
    end, 1000)
    process.services = {}
  end)

  it("exit 0 ends in 'stopped' and captures stdout in the log", function()
    add_service({ "sh", "-c", "printf 'hello\\n'; exit 0" })
    process.start(NAME)

    assert.is_true(wait_until(function()
      local svc = process.get(NAME)
      return svc.status == "stopped" or svc.status == "failed"
    end))

    local svc = process.get(NAME)
    assert.equals("stopped", svc.status)
    assert.equals(0, svc.exit_code)

    local lines = vim.api.nvim_buf_get_lines(svc.bufnr, 0, -1, false)
    local found = false
    for _, line in ipairs(lines) do
      if line == "hello" then
        found = true
      end
    end
    assert.is_true(found)
  end)

  it("a nonzero exit code ends in 'failed'", function()
    add_service({ "sh", "-c", "exit 3" })
    process.start(NAME)

    assert.is_true(wait_until(function()
      return process.get(NAME).status ~= "running" and process.get(NAME).status ~= "starting"
    end))

    local svc = process.get(NAME)
    assert.equals("failed", svc.status)
    assert.equals(3, svc.exit_code)
  end)

  it("stop() kills the process and ends in 'stopped', not 'failed'", function()
    add_service({ "sh", "-c", "sleep 5" })
    process.start(NAME)

    assert.is_true(wait_until(function()
      return process.get(NAME).status == "running"
    end))

    process.stop(NAME)

    assert.is_true(wait_until(function()
      return process.get(NAME).status ~= "running"
    end))
    assert.equals("stopped", process.get(NAME).status)
  end)

  it("restart() waits for the current process to exit before starting again", function()
    add_service({ "sh", "-c", "sleep 0.3" })
    process.start(NAME)

    assert.is_true(wait_until(function()
      return process.get(NAME).status == "running"
    end))
    local old_pid = process.get(NAME).pid

    process.restart(NAME)

    assert.is_true(wait_until(function()
      local svc = process.get(NAME)
      return svc.status == "running" and svc.pid ~= old_pid
    end, 4000))
  end)
end)
