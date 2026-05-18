#!/usr/bin/env tarantool

box.cfg{ listen = 3301 }

box.once('v1', function()
    local users = box.schema.space.create('users', {
        format = {
            {name = 'id', type = 'unsigned'},
            {name = 'balance', type = 'number'},
            {name = 'status', type = 'string'},
        },
        if_not_exists = true,
    })
    users:create_index('primary', { parts = {'id'}, if_not_exists = true })

    local transactions = box.schema.space.create('transactions', {
        format = {
            {name = 'id', type = 'unsigned'},
            {name = 'user_id', type = 'unsigned'},
            {name = 'amount', type = 'number'},
            {name = 'ip', type = 'string'},
            {name = 'timestamp', type = 'unsigned'},
        },
        if_not_exists = true,
    })
    transactions:create_index('primary', { parts = {'id'}, sequence = true, if_not_exists = true })
    transactions:create_index('time', { parts = {'timestamp'}, unique = false, if_not_exists = true })
    transactions:create_index('user_time', { parts = {'user_id', 'timestamp'}, unique = false, if_not_exists = true })
    transactions:create_index('ip_time', { parts = {'ip', 'timestamp'}, unique = false, if_not_exists = true })

    users:replace{1, 10000.0, 'active'}
    users:replace{2, 5000.0, 'active'}
end)

local c_utils = nil
local ok_c, err_c = pcall(require, 'fraud_utils')
if ok_c then
    c_utils = err_c
else
    print("Warning: fraud_utils not loaded: " .. tostring(err_c))
end

local VELOCITY_WINDOW = 10
local MAX_TX_PER_WINDOW = 5
local DAILY_LIMIT = 5000

local metrics = {
    accepted = 0,
    rejected = 0,
    by_reason = {}
}

local function observe_transaction(res)
    if res.status == 'accepted' then
        metrics.accepted = metrics.accepted + 1
    else
        metrics.rejected = metrics.rejected + 1
        metrics.by_reason[res.reason] = (metrics.by_reason[res.reason] or 0) + 1
    end
end

local http = pcall(require, 'http.server')
if http then
    local server = require('http.server').new('0.0.0.0', 8080)
    server:route({path = '/metrics', method = 'GET'}, function()
        local out = {
            '# HELP antifraud_transactions_total Total number of transactions',
            '# TYPE antifraud_transactions_total counter',
            string.format('antifraud_transactions_total{status="accepted"} %d', metrics.accepted),
            string.format('antifraud_transactions_total{status="rejected"} %d', metrics.rejected)
        }
        for reason, count in pairs(metrics.by_reason) do
            table.insert(out, string.format('antifraud_transactions_rejected_reason_total{reason="%s"} %d', reason, count))
        end
        return {
            status = 200,
            headers = {['content-type'] = 'text/plain; version=0.0.4'},
            body = table.concat(out, '\n') .. '\n'
        }
    end)
    server:start()
    print("Metrics exporter started on http://0.0.0.0:8080/metrics")
end

local function check_blacklist(ip)
    if c_utils and c_utils.check(ip) then return false, 'ip_blacklisted' end
    return true
end

local function check_velocity(user_id, ip, timestamp)
    local start_time = timestamp - VELOCITY_WINDOW
    
    local user_count = 0
    for _, tr in box.space.transactions.index.user_time:pairs({user_id, start_time}, {iterator = 'GE'}) do
        if tr.user_id ~= user_id then break end
        user_count = user_count + 1
        if user_count >= MAX_TX_PER_WINDOW then return false, 'user_velocity_limit' end
    end

    local ip_count = 0
    for _, tr in box.space.transactions.index.ip_time:pairs({ip, start_time}, {iterator = 'GE'}) do
        if tr.ip ~= ip then break end
        ip_count = ip_count + 1
        if ip_count >= MAX_TX_PER_WINDOW then return false, 'ip_velocity_limit' end
    end

    return true
end

local function check_limits(user_id, amount, timestamp)
    local start_time = timestamp - 86400
    local total_spent = 0
    for _, tr in box.space.transactions.index.user_time:pairs({user_id, start_time}, {iterator = 'GE'}) do
        if tr.user_id ~= user_id then break end
        total_spent = total_spent + tr.amount
    end

    if total_spent + amount > DAILY_LIMIT then return false, 'daily_limit_exceeded' end
    return true
end

function process_transaction(user_id, amount, ip, timestamp)
    local res = _process_transaction(user_id, amount, ip, timestamp)
    observe_transaction(res)
    return res
end

function _process_transaction(user_id, amount, ip, timestamp)
    local user = box.space.users:get(user_id)
    if not user then return {status = 'rejected', reason = 'user_not_found'} end
    if user.status ~= 'active' then return {status = 'rejected', reason = 'user_inactive'} end
    if user.balance < amount then return {status = 'rejected', reason = 'insufficient_funds'} end

    local ok, reason = check_blacklist(ip)
    if not ok then return {status = 'rejected', reason = reason} end

    ok, reason = check_velocity(user_id, ip, timestamp)
    if not ok then return {status = 'rejected', reason = reason} end

    ok, reason = check_limits(user_id, amount, timestamp)
    if not ok then return {status = 'rejected', reason = reason} end

    box.begin()
    box.space.users:update(user_id, {{'-', 2, amount}})
    box.space.transactions:insert{nil, user_id, amount, ip, timestamp}
    box.commit()

    return {status = 'accepted'}
end

print("Anti-Fraud Engine started.")
