--!strict
-- Direct test file for running tests

local typesTest = require("./tests/unit/Types.spec")
local passed, failed = typesTest()

print(string.format("Final: %d passed, %d failed", passed, failed))

if failed > 0 then
    error(string.format("Tests failed: %d", failed))
end
