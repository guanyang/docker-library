--
-- Licensed to the Apache Software Foundation (ASF) under one or more
-- contributor license agreements.  See the NOTICE file distributed with
-- this work for additional information regarding copyright ownership.
-- The ASF licenses this file to You under the Apache License, Version 2.0
-- (the "License"); you may not use this file except in compliance with
-- the License.  You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
local ngx        = ngx
local type       = type
local abs        = math.abs
local ngx_time   = ngx.time
local pairs      = pairs
local ipairs     = ipairs
local escape_uri = ngx.escape_uri
local hmac       = require("resty.hmac")
local core       = require("apisix.core")
local consumer   = require("apisix.consumer")
local ngx_decode_base64 = ngx.decode_base64
local ngx_encode_base64 = ngx.encode_base64

local APP_ID_KEY = "k"
local NONCE_KEY = "r"
local FROM_KEY = "f"
local FROM_VALUE = "fs"
local TIMESTAMP_KEY    = "t"
local TOKEN_KEY = "Authorization"
local plugin_name   = "fs-sign"

local lrucache = core.lrucache.new({
    type = "plugin",
})

local schema = {
    type = "object",
    title = "work with route or service object",
    properties = {
        app_id_key = { type = "string", default = APP_ID_KEY },
        nonce_key = { type = "string", default = NONCE_KEY },
        from_key = { type = "string", default = FROM_KEY },
        timestamp_key = { type = "string", default = TIMESTAMP_KEY },
        token_key = {
            type = "string",
            title = "The name of the token",
            default = TOKEN_KEY
        },
        white_list = {
            type = "array",
            items = {
                type = "string",
                minLength = 1,
                maxLength = 256
            }
        }
    }
}

local consumer_schema = {
    type = "object",
    title = "work with consumer object",
    properties = {
        access_key = {type = "string", minLength = 1, maxLength = 256},
        secret_key = {type = "string", minLength = 1, maxLength = 256},
        algorithm = {
            type = "string",
            enum = { "md5", "sha1", "sha256" },
            default = "sha1"
        },
        expire = {
            type = "integer",
            title = "The expire second of the access key",
            default = 60,
            minimum = 1,
            maximum = 86400
        }
    },
    required = { "access_key", "secret_key" }
}

local _M = {
    version = 0.1,
    priority = 50,
    type = 'auth',
    name = plugin_name,
    schema = schema,
    consumer_schema = consumer_schema
}

local hmac_funcs = {
    ["md5"] = function(secret_key, message)
        return hmac:new(secret_key, hmac.ALGOS.MD5):final(message)
    end,
    ["sha1"] = function(secret_key, message)
        return hmac:new(secret_key, hmac.ALGOS.SHA1):final(message)
    end,
    ["sha256"] = function(secret_key, message)
        return hmac:new(secret_key, hmac.ALGOS.SHA256):final(message)
    end,
    ["sha512"] = function(secret_key, message)
        return hmac:new(secret_key, hmac.ALGOS.SHA512):final(message)
    end,
}


local function array_to_map(arr)
    local map = core.table.new(0, #arr)
    for _, v in ipairs(arr) do
        map[v] = true
    end

    return map
end


local function remove_headers(ctx, ...)
    local headers = { ... }
    if headers and #headers > 0 then
        for _, header in ipairs(headers) do
            core.log.info("remove_header: ", header)
            core.request.set_header(ctx, header, nil)
        end
    end
end


local create_consumer_cache
do
    local consumer_names = {}

    function create_consumer_cache(consumers)
        core.table.clear(consumer_names)

        for _, consumer in ipairs(consumers.nodes) do
            core.log.info("consumer node: ", core.json.delay_encode(consumer))
            consumer_names[consumer.auth_conf.access_key] = consumer
        end

        return consumer_names
    end

end -- do


function _M.check_schema(conf, schema_type)
    core.log.info("input conf: ", core.json.delay_encode(conf))

    if schema_type == core.schema.TYPE_CONSUMER then
        return core.schema.check(consumer_schema, conf)
    else
        return core.schema.check(schema, conf)
    end
end


local function get_consumer(access_key)
    if not access_key then
        return nil, "missing access key"
    end

    local consumer_conf = consumer.plugin(plugin_name)
    if not consumer_conf then
        return nil, "Missing related consumer"
    end

    local consumers = lrucache("consumers_key#" .. plugin_name, consumer_conf.conf_version,
            create_consumer_cache, consumer_conf)

    local consumer = consumers[access_key]
    if not consumer then
        return nil, "Invalid access key"
    end
    core.log.info("consumer: ", core.json.delay_encode(consumer))

    return consumer
end


local function get_conf_field(access_key, field_name)
    local consumer, err = get_consumer(access_key)
    if err then
        return false, err
    end

    return consumer.auth_conf[field_name]
end


local function do_nothing(v)
    return v
end

local function build_args_string(args,field_val)
    local canonical_string = ""
    if type(args) == "table" then
        local keys = {}
        local query_tab = {}

        for k, v in pairs(args) do
            core.table.insert(keys, k)
        end
        core.table.sort(keys)

        local encode_or_not = do_nothing
        if field_val then
            encode_or_not = escape_uri
        end

        for _, key in pairs(keys) do
            local param = args[key]
            -- when args without `=<value>`, value is treated as true.
            -- In order to be compatible with args lacking `=<value>`,
            -- we need to replace true with an empty string.
            if type(param) == "boolean" then
                param = ""
            end

            -- whether to encode the uri parameters
            if type(param) == "table" then
                local vals = {}
                for _, val in pairs(param) do
                    if type(val) == "boolean" then
                        val = ""
                    end
                    core.table.insert(vals, val)
                end
                core.table.sort(vals)

                for _, val in pairs(vals) do
                    core.table.insert(query_tab, encode_or_not(key) .. "=" .. encode_or_not(val))
                end
            else
                core.table.insert(query_tab, encode_or_not(key) .. "=" .. encode_or_not(param))
            end
        end
        canonical_string = core.table.concat(query_tab, "&")
    end
    return canonical_string
end

local function generate_signature(auth_conf, params)
    local query_string = params.query_string
    core.log.info("query_string: ", query_string)

    local algorithm = auth_conf["algorithm"]
    local secret_key = auth_conf["secret_key"]
    local hex = hmac_funcs[algorithm](secret_key, query_string)
    return ngx_encode_base64(hex .. query_string)
end

local function build_response_msg(code, msg, data)
    local res = {}
    res.code = code or 200
    res.msg = msg or "ok"
    if data then
        res.data = data
    end
    return res
end

local function validate(ctx, params)
    if not params.access_key or not params.nonce or not params.timestamp or not tonumber(params.timestamp) then
        return nil, build_response_msg(1003, "Missing important parameters")
    end

    local consumer, err = get_consumer(params.access_key)
    if err then
        return nil, build_response_msg(1004, err)
    end

    local conf = consumer.auth_conf

    core.log.info("clock_skew: ", conf.expire)
    if conf.expire and conf.expire > 0 then
        local time = params.timestamp

        local diff = abs(ngx_time() - time)
        if diff > conf.expire then
            return nil, build_response_msg(1004, "Token expired. Please check the client time")
        end
    end
    local request_signature   = params.token
    local generated_signature = generate_signature(conf, params)

    core.log.info("request_signature: ", request_signature,
            " generated_signature: ", generated_signature)

    if request_signature ~= generated_signature then
        return nil, build_response_msg(1004, "Authentication failure")
    end

    return consumer
end

-- 定义函数，解析查询字符串
local function parse_query_string(query_string)
    local result = {}

    -- 使用 '&' 将查询字符串分割成多个键值对
    for key, value in string.gmatch(query_string, "([^&=?]+)=([^&=?]+)") do
        result[key] = value
    end

    return result
end

-- 定义函数，支持返回包含或不包含 delimiter 的子串
local function substring_after(input_string, delimiter, include_delimiter)
    -- 找到子串的位置
    local start_pos, end_pos = string.find(input_string, delimiter)

    -- 如果找到 delimiter
    if start_pos then
        if include_delimiter then
            -- 返回从 delimiter 开始的部分（包含 delimiter）
            return string.sub(input_string, start_pos)
        else
            -- 返回从 delimiter 之后的部分（不包含 delimiter）
            return string.sub(input_string, end_pos + 1)
        end
    else
        -- 如果没有找到 delimiter，返回整个字符串
        return input_string
    end
end

local function get_params(conf, ctx)
    local params = {}

    local token_key = conf.token_key or TOKEN_KEY
    local token = core.request.header(ctx, token_key)
    if not token then
        token = core.request.get_uri_args(ctx)[token_key]
    end
    if not token then
        return params, build_response_msg(1001, "Token missing")
    end

    local token_str   = ngx_decode_base64(token)
    if not token_str then
        return params, build_response_msg(1002, "Invalid token")
    end

    local app_id_key = conf.app_id_key or APP_ID_KEY
    local nonce_key = conf.nonce_key or NONCE_KEY
    local from_key = conf.from_key or FROM_KEY
    local timestamp_key = conf.timestamp_key or TIMESTAMP_KEY

    local query_string = substring_after(token_str, app_id_key, true)
    local token_map = parse_query_string(query_string)

    params.access_key = token_map[app_id_key]
    params.nonce = token_map[nonce_key]
    params.from = token_map[from_key]
    params.timestamp  = token_map[timestamp_key]
    params.token = token
    params.query_string = query_string

    core.log.info("params: ", core.json.delay_encode(params))

    return params
end

local function checkWhiteList(conf)
    if conf.white_list and #conf.white_list >= 1 then
        for i, v in ipairs(conf.white_list) do
            local uploadUri = ngx.re.match(ngx.var.uri, v .. "/?", 'joi')
            if uploadUri ~= nil then
                return true
            end
        end
    end
    return false
end


function _M.rewrite(conf, ctx)
    -- check white list
    if checkWhiteList(conf) then
        core.log.info("hit fs-sign whiteList")
    else
        local params, param_err = get_params(conf, ctx)
        if param_err then
            core.response.add_header("Content-Type", "application/json")
            return 403, param_err
        end
        local validated_consumer, err = validate(ctx, params)
        if not validated_consumer then
            core.log.warn("client request can't be validated: ", core.json.delay_encode(err))
            core.response.add_header("Content-Type", "application/json")
            return 403, err
        end

        local consumer_conf = consumer.plugin(plugin_name)
        consumer.attach_consumer(ctx, validated_consumer, consumer_conf)
        core.log.info("hit fs-sign rewrite")
    end
end


return _M