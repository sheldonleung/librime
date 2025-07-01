param(
    [string]$plugin_name_arg
)

if (-not $plugin_name_arg) {
    Write-Host "Usage: $(Split-Path -Leaf $MyInvocation.MyCommand.Path) <plugin-name>"
    exit 1
}

# 处理插件名称
$plugin_name = $plugin_name_arg.Replace('_', '-')
if ($plugin_name.StartsWith("rime-")) {
    $plugin_name = $plugin_name.Substring(5)
}

$plugin_dir = "plugins\$plugin_name"
$plugin_module = $plugin_name.Replace('-', '_')

Write-Host "plugin_name: rime-$plugin_name"
Write-Host "plugin_dir: $plugin_dir"
Write-Host "plugin_module: $plugin_module"

# 创建目录
New-Item -ItemType Directory -Path $plugin_dir -Force | Out-Null

# 创建 CMakeLists.txt
@"
project(rime-$plugin_name)
cmake_minimum_required(VERSION 3.10)

aux_source_directory(src ${plugin_module}_src)

add_library(rime-$plugin_name-objs OBJECT `${${plugin_module}_src})
if(BUILD_SHARED_LIBS)
  set_target_properties(rime-$plugin_name-objs
    PROPERTIES
    POSITION_INDEPENDENT_CODE ON)
endif()

set(plugin_name rime-$plugin_name PARENT_SCOPE)
set(plugin_objs `$<TARGET_OBJECTS:rime-$plugin_name-objs> PARENT_SCOPE)
set(plugin_deps `${rime_library} PARENT_SCOPE)
set(plugin_modules "$plugin_module" PARENT_SCOPE)
"@ | Out-File -FilePath "$plugin_dir\CMakeLists.txt" -Encoding utf8

# 创建源代码目录
$src_dir = "$plugin_dir\src"
New-Item -ItemType Directory -Path $src_dir -Force | Out-Null

# 创建模块源文件
@"
#include <rime/component.h>
#include <rime/registry.h>
#include <rime_api.h>

#include "todo_processor.h"

using namespace rime;

static void rime_${plugin_module}_initialize() {
  Registry &r = Registry::instance();
  r.Register("todo_processor", new Component<TodoProcessor>);
}

static void rime_${plugin_module}_finalize() {
}

RIME_REGISTER_MODULE($plugin_module)
"@ | Out-File -FilePath "$src_dir\${plugin_module}_module.cc" -Encoding utf8

# 创建头文件
@"
#include <rime/common.h>
#include <rime/context.h>
#include <rime/engine.h>
#include <rime/processor.h>

using namespace rime;

class TodoProcessor : public Processor {
 public:
  explicit TodoProcessor(const Ticket& ticket)
    : Processor(ticket) {
    Context* context = engine_->context();
    update_connection_ = context->update_notifier()
      .connect([this](Context* ctx) { OnUpdate(ctx); });
  }

  virtual ~TodoProcessor() {
    update_connection_.disconnect();
  }

  ProcessResult ProcessKeyEvent(const KeyEvent& key_event) override {
    return kNoop;
  }

 private:
  void OnUpdate(Context* ctx) {}

  connection update_connection_;
};
"@ | Out-File -FilePath "$src_dir\todo_processor.h" -Encoding utf8
