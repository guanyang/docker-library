# Higress REST-to-MCP 配置生成器

请帮我创建一个 Higress 的 REST-to-MCP 配置，将 REST API 转换为 MCP 工具。

## 配置格式

配置应遵循以下格式：

```yaml
server:
  name: rest-api-server
  config:
    apiKey: 您的API密钥
tools:
  - name: tool-name
    description: "详细描述这个工具的功能"
    args:
      - name: arg1
        description: "参数1的描述"
        type: string # 可选类型: string, number, integer, boolean, array, object
        required: true
        position: path # 可选位置: query, path, header, cookie, body
      - name: arg2
        description: "参数2的描述"
        type: integer
        required: false
        default: 10
        position: query
      - name: arg3
        description: "参数3的描述"
        type: array
        items:
          type: string
        position: body
      - name: arg4
        description: "参数4的描述"
        type: object
        properties:
          subfield1:
            type: string
          subfield2:
            type: number
        # 未指定position，将根据argsToJsonBody/argsToUrlParam/argsToFormBody处理
    requestTemplate:
      url: "https://api.example.com/endpoint"
      method: POST
      # 以下四个选项互斥，只能选择其中一种
      argsToUrlParam: true # 将参数添加到URL查询参数
      # 或者
      # argsToJsonBody: true  # 将参数作为JSON对象发送到请求体
      # 或者
      # argsToFormBody: true  # 将参数以表单编码发送到请求体
      # 或者
      # body: |  # 手动构建请求体
      #   {
      #     "param1": "{{.args.arg1}}",
      #     "param2": {{.args.arg2}},
      #     "complex": {{toJson .args.arg4}}
      #   }
      headers:
        - key: x-api-key
          value: "{{.config.apiKey}}"
    responseTemplate:
      # 以下三个选项互斥，只能选择其中一种
      body: |
        # 结果
        {{- range $index, $item := .items }}
        ## 项目 {{add $index 1}}
        - **名称**: {{ $item.name }}
        - **值**: {{ $item.value }}
        {{- end }}
      # 或者
      # prependBody: |
      #   # API响应说明
      #
      #   以下是原始JSON响应，字段含义如下：
      #   - field1: 字段1的含义
      #   - field2: 字段2的含义
      #
      #   原始JSON响应：
      #
      # appendBody: |
      #
      #   您可以使用这些数据来...
```

# 模板语法

模板使用 GJSON Template 语法 (https://github.com/higress-group/gjson_template)，该语法结合了 Go 模板和 GJSON 路径语法进行 JSON 处理。模板引擎支持：

- 基本点表示法访问字段：{{.fieldName}}
- 用于复杂查询的 gjson 函数：{{gjson “users.#(active==true)#.name”}}
- 所有 Sprig 模板函数（类似 Helm）：{{add}}、{{upper}}、{{lower}}、{{date}} 等
- 控制结构：{{if}}、{{range}}、{{with}} 等
- 变量赋值：{{$var := .value}}

对于复杂的 JSON 响应，请考虑使用 GJSON 强大的过滤和查询能力来提取和格式化最相关的信息。

# 请根据以上信息生成一个完整的配置，包括：

1. 具有描述性名称和适当的服务器配置
2. 定义所有必要的参数，并提供清晰的描述和适当的类型、必填/默认值
3. 选择合适的参数传递方式（argsToUrlParam、argsToJsonBody、argsToFormBody 或自定义 body）
4. 创建将 API 响应转换为适合 AI 消费的可读格式的 responseTemplate
5. 将最终的完整配置输出到 mcp 目录，文件名称为：mcp-name.yaml