#!/usr/bin/env tarantool

local tap = require('tap')
local test = tap.test('anti-fraud-tests')

package.cpath = './src/tarantool/?.so;' .. package.cpath
dofile('src/tarantool/init.lua')

test:plan(7)

local now = os.time()

local res = process_transaction(1, 100, '192.168.1.1', now)
test:is(res.status, 'accepted', 'Normal transaction accepted')

res = process_transaction(1, 1000000, '192.168.1.1', now + 1)
test:is(res.status, 'rejected', 'Insufficient funds rejected')
test:is(res.reason, 'insufficient_funds', 'Reason is insufficient_funds')

for i = 1, 5 do
    process_transaction(1, 1, '192.168.1.1', now + 10 + i)
end
res = process_transaction(1, 1, '192.168.1.1', now + 16)
test:is(res.status, 'rejected', 'Velocity limit (user) rejected')
test:is(res.reason, 'user_velocity_limit', 'Reason is user_velocity_limit')

box.space.users:update(2, {{'=', 2, 10000.0}})
process_transaction(2, 4990, '192.168.2.1', now)
res = process_transaction(2, 20, '192.168.2.1', now + 1)
test:is(res.status, 'rejected', 'Daily limit exceeded')
test:is(res.reason, 'daily_limit_exceeded', 'Reason is daily_limit_exceeded')

os.exit(test:check() and 0 or 1)
