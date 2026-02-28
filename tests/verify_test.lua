
local testMod = require("./unit/LightInteraction.spec")
local p, f = testMod()
print("
=== FINAL LIGHT INTERACTION TEST RESULT ===")
print(string.format("Passed: %d, Failed: %d", p, f))
if f == 0 then
    print("STATUS: ALL TESTS PASSED")
else
    print("STATUS: SOME TESTS FAILED")
    os.exit(1)
end

