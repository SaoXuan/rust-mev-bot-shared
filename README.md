# Solana MEV 套利机器人
基于 Rust 开发的高性能 Solana MEV 套利机器人，支持 Jupiter 聚合器和 Jito Bundle。
## 前言
- 由于用机器人换sol和wsol可能会换不成功，建议大家去jup换wsol[Jupiter链接](https://jup.ag/)，定期补充gas，gas不足会导致不出单
- 本人免责声明，请大家先小金额测试，测试没有问题了再大金额使用，代码逻辑里是不会导致大家资金损失，但是以防万一，营收自负
- 本人保证不会收集任何用户相关的信息，你可以选择用抓包软件等安全工具扫描，如果发现有收集信息，请立即停止使用，并联系作者
- 请妥善保管好自己的私钥，由于是开源软件，如果私钥泄露，请立即停止使用，并联系作者 邮箱：yscxyjd@gmail.com
- 此bot收费比例为你的净利润的10%，如果赚不到钱，请不要使用，请不要使用，请不要使用！
- 小费规则：(毛利润-GasFee-jito小费)*0.1
- 各位的支持与推广就是我的动力，作者会后续持续更新，并教大家如何赚取最大利润，当前观察钱包就是跑的下方的demo配置，大家可以自行修改调整
- [作者钱包监控地址](https://solscan.io/account/F1gnxS6Csq8pyApuogH2R6z5TqShwu3o7DMTm5WUphJ7)
- [小费收益](https://solscan.io/account/BUp6bo7x5UG3Xq8KSrnFwGbuzFJHsJcQ5vMnb9LwR7G4)
- [群友制作dune-daily](https://dune.com/queries/4632156/7715285/2c559022-b479-4614-926b-ae7d67dfe39f)
- [群友制作dune-pre-day](https://dune.com/queries/4646483/7737654/5a560eb5-e9d9-4f1c-808a-3f38d0fe6c02)
## 主要功能

- 自动化套利交易
- 多jito引擎节点并行处理
- 高性能交易执行
- 实时错误监控
- 单引擎交易整体速度<10ms
- 多IP支持
- 多节点支持
## 环境要求
- Ubuntu 22.04
- 2G内存
- 100M带宽
- CPU 核心越高，频率越高越好，建议频率选择3.x以上，不要选择比较旧的cpu平台，可能某些编译后的指令，在旧的cpu上不支持，导致运行失败，demo
- RPC & Grpc 节点选择

## VPS 购买：
- [hostkey便宜实惠](https://hostkey.com/vps/) 
- [NodeStop ](https://billing.nodestop.io/store/bare-metal)
- [CloudFanatic ](https://cloudfanatic.net/)
- [Sauceservers ](https://sauceservers.com/)
- [Teraswitch ](https://teraswitch.com/)
- [Vultr ](https://www.vultr.com/)
- [RackNerd ](https://www.racknerd.com/)

## RPC &Grpc 购买
- [Helius: Provide RPC/Yellowstone. ](https://www.helius.dev/)
- [Quicknode: Provide RPC/Jup API. ](https://www.quicknode.com/?via=cetipo)
- [Shyft: Provide RPC/Jup API. ](https://shyft.to/)
- [KawaiiLabs: Provide RPC/Jup API. ](https://discord.gg/kawaiilabs)


## 快速开始

1. 下载对应系统的发布版本
2. 准备配置文件 `config.yaml`
3. 运行程序开始套利
4. 你可以clone本仓库运行，或者使用下方的方式快速运行

## 运行方式
创建一个bot文件夹
```bash
mkdir bot
```
```bash
cd bot
```
Install wget：
```bash
sudo apt update
```
```bash
sudo apt install wget
```
install unzip
```bash
sudo apt install unzip
```
下载发布版本
```bash
wget https://sourceforge.net/projects/rust-mev-bot/files/rust-mev-bot-1.0.0.zip
```
解压
```bash
unzip rust-mev-bot-1.0.0.zip
```
更新版本
```bash
chmod +x upgrade.sh
```
```bash
./upgrade.sh
```

将config.yaml.example 重命名为config.yaml 并配置上相关参数
```bash
mv config.yaml.example config.yaml
```
赋予启动脚本权限
```bash
chmod +x run.sh
```
正常模式运行
```bash
./run.sh
```


调试模式运行（输出详细日志）：
```bash
./run.sh --debug
```
## 配置说明

配置文件 `config.yaml` 示例：
```yaml
# 排除的dex program ids，如果不想被交易，可以在这里配置上
jup_exclude_dex_program_ids:
  - "6EF8rrecthR5Dkzon8Nwu78hRvfCKubJ14M5uBEwF6P"
  - "MoonCVVNZFSYkqNXP6bxHLPL6QQJiMagDL3qcqUQTrG"
#jupiter的本地端口
jupiter_local_port: 18080
#是否禁用本地jupiter
jupiter_disable_local: false
#是否使用本地缓存，建议禁用
jupiter_use_local_cache: false
#jupiter的market模式，建议选择remote
jupiter_market_mode: "remote"
#jupiter的webserver线程数
jupiter_webserver: 2
#jup的更新线程数
jupiter_update: 2
#自动重启时间，设置为0不会重启，单位为分钟
auto_restart: 0
# grpc token，如果你得gprc有token验证，可以在这里配置上
yellowstone_grpc_token: ""
# 从birdeye api 加载代币，最大加载50个代币,需要自己配置key，可以去注册一个账号key免费https://bds.birdeye.so/
load_mints_from_birdeye_api_max_mints: 50
birdeye_api_key: ""
#你的私钥数组，系统启动后会在当前目录下生成一个PRIVATEKEY文件，里面是加密后的私钥，虽然做了加密，但是还是要小心，不要泄露，系统启动后会将此项配置删除，不在服务器上储存私钥
private_key: ""
#solana rpc url
rpc_url: "http://xxxx"
#jupiter api url
jupiter_api_url: "http://0.0.0.0:18080"
#yellowstone grpc url
yellowstone_grpc_url: "http://xxxx"
# Jito MEV-Block-Engine 节点配置列表，建议配置上多个节点，随机选择一个节点进行交易，这样的你的QPS会有提升，尽量选择几个距离你比较近的节点，当然全发也可以，目测日本较慢，会降低整体效率,如果想追求速度，那么jito的引擎只开本区域，你会起飞
jito_engine:
  - NL # 荷兰阿姆斯特丹节点
  - DE      # 德国法兰克福节点
  - NY      # 美国纽约节点
  - SLC     # 美国盐湖城节点
  - DE      # 德国法兰克福节点
  # - Tokyo   # 日本东京节点
#是否开启随机引擎，建议开启，随机引擎会随机选择一个节点进行交易，这样的你的QPS会有提升
random_engine: true
#jito配置UUID，没怎么测试，建议先不要用,使用多ip的方法，而不是配置uuid
jito_uuid: ""
#从url加载代币，可以从你的jup加载代币，你的jup加载了什么币，会拉到bot内。如果从其他地方拉取，需要和jup返回结构抱持一致，建议从jup加载代币
load_mints_form_url: "http://0.0.0.0:18080/tokens"
#从文件加载代币
intermediate_tokens_file: "test.json"
#从配置文件加载代币
intermediate_tokens:
  - "6AJcP7wuLwmRYLBNbi825wgguaPsWzPBEHcHndpRpump"
  # 排除的币种
not_support_tokens:
#最大代币数量，如果低于最大限制的60%会一直请求load_mints_form_url，直到达到目标才会运行起来，主要是为了链接jup 的时候jup还没加载好全部的代币
max_tokens_limit: 80
#最小利润阈值
min_profit_threshold: 4000
#最大tip限制，单位lamports，给jito的最大限制
max_tip_lamports: 100000000
#静态tip百分比，给jito的tip百分比
static_tip_percentage: 0.7501
#交易memo，可以不设置
memo: ""
#建议先从小的开始0.1-1s，设置很多不会影响性能，性能主要由线程和网络io决定
trade_range:
  - 100000000    # 0.1 SOL
  - 200000000    # 0.2 SOL
  - 300000000    # 0.3 SOL
  - 400000000    # 0.4 SOL
  - 500000000    # 0.5 SOL
  - 600000000    # 0.6 SOL
  - 700000000    # 0.7 SOL
  - 800000000    # 0.8 SOL
  - 900000000    # 0.9 SOL
  - 1000000000   # 1 SOL
#发送交易类型，建议选择Mixed，可选Rpc,Grpc,Mixed，选择Mixed可以让你的ip限制速率翻倍
rpc_type: Mixed
#blockhash rpc类型，建议选择Rpc，可选Grpc,Rpc，当前实现Grpc不是订阅的，等改成订阅的再选用Grpc
blockhash_rpc_type: Rpc

#是否开启block缓存，建议开启
blockhash_cache_enabled: true
#block缓存过期时间，单位ms，缓存1s没啥问题，降低下节点压力
blockhash_cache_ttl_ms: 1000
#性能相关，开启多少个线程,系统负载全靠这个控制
thread_count: 4
#每个线程里多少个网络IO，可以一个线程配2个左右，具体看性能，自行调试，作者也不知道多少是好的
max_concurrent: 4

#日志相关能力
log_rate_limit: false
#打印机会
log_opportunities: false
#打印交易执行
log_trade_execution: false
#是否开启单独钱包
enable_separate_wallet: true

#ip 配置信息，如果有多IP可以在这里配置，否则使用本机IP，建议配置上多IP，如果有请取消注释，并配置上
ip_addrs:
  - "xxxx"
#jup 调优
#是否只使用单跳，当前多跳还有待调整，建议现在只使用单跳
onlyDirectRoutes: true
#限制中间代币为顶级代币，建议开启，此参数也就是在多跳的时候有用，现在多跳没那么好使，先这样
restrict_intermediate_tokens: true
#是否预检交易大小，先暂时关闭，这个只对多跳有用，等待后续开发
check_transaction_size: false
#是否开启动态计算预算,建议开启
dynamic_compute_unit_limit: true
#计算预算百分比，设置这个值是因为，模拟后的cu可能偏大，可以设置百分比二次修改cu限制，近一步降低cu限制
cu_limit_percentage: 0.98
#计算预算，在开启动态预算的时候不生效
compute_unit_limit: 180000
# 排除的dex program ids，如果不想被交易，可以在这里配置上
jup_exclude_dex_program_ids:
  - "6EF8rrecthR5Dkzon8Nwu78hRvfCKubJ14M5uBEwF6P"
  - "MoonCVVNZFSYkqNXP6bxHLPL6QQJiMagDL3qcqUQTrG"
#jupiter的本地端口
jupiter_local_port: 18080
#是否禁用本地jupiter
jupiter_disable_local: false
#是否使用本地缓存，建议禁用
jupiter_use_local_cache: false
#jupiter的market模式，建议选择remote
jupiter_market_mode: "remote"
#jupiter的webserver线程数
jupiter_webserver: 2
#jup的更新线程数
jupiter_update: 2
#自动重启时间，设置为0不会重启，单位为分钟
auto_restart: 0
# grpc token，如果你得gprc有token验证，可以在这里配置上
yellowstone_grpc_token: ""
# 从birdeye api 加载代币，最大加载50个代币,需要自己配置key，可以去注册一个账号key免费https://bds.birdeye.so/
load_mints_from_birdeye_api_max_mints: 50
birdeye_api_key: ""
#你的私钥数组，系统启动后会在当前目录下生成一个PRIVATEKEY文件，里面是加密后的私钥，虽然做了加密，但是还是要小心，不要泄露，系统启动后会将此项配置删除，不在服务器上储存私钥
private_key: ""
#solana rpc url
rpc_url: "http://xxxx"
#jupiter api url
jupiter_api_url: "http://0.0.0.0:18080"
#yellowstone grpc url
yellowstone_grpc_url: "http://xxxx"
# Jito MEV-Block-Engine 节点配置列表，建议配置上多个节点，随机选择一个节点进行交易，这样的你的QPS会有提升，尽量选择几个距离你比较近的节点，当然全发也可以，目测日本较慢，会降低整体效率,如果想追求速度，那么jito的引擎只开本区域，你会起飞
jito_engine:
  - NL # 荷兰阿姆斯特丹节点
  - DE      # 德国法兰克福节点
  - NY      # 美国纽约节点
  - SLC     # 美国盐湖城节点
  # - Tokyo   # 日本东京节点
#是否开启随机引擎，建议开启，随机引擎会随机选择一个节点进行交易，这样的你的QPS会有提升
random_engine: true
#jito配置UUID，没怎么测试，建议先不要用,使用多ip的方法，而不是配置uuid
jito_uuid: ""
#从url加载代币，可以从你的jup加载代币，你的jup加载了什么币，会拉到bot内。如果从其他地方拉取，需要和jup返回结构抱持一致，建议从jup加载代币
load_mints_form_url: "http://0.0.0.0:18080/tokens"
#从文件加载代币
intermediate_tokens_file: "test.json"
#从配置文件加载代币
intermediate_tokens:
  - "6AJcP7wuLwmRYLBNbi825wgguaPsWzPBEHcHndpRpump"
  # 排除的币种
not_support_tokens:
#最大代币数量，如果低于最大限制的60%会一直请求load_mints_form_url，直到达到目标才会运行起来，主要是为了链接jup 的时候jup还没加载好全部的代币
max_tokens_limit: 80
#最小利润阈值
min_profit_threshold: 4000
#最大tip限制，单位lamports，给jito的最大限制
max_tip_lamports: 100000000
#静态tip百分比，给jito的tip百分比
static_tip_percentage: 0.7501
#交易memo，可以不设置
memo: ""
#建议先从小的开始0.1-1s，设置很多不会影响性能，性能主要由线程和网络io决定
trade_range:
  - 100000000    # 0.1 SOL
  - 200000000    # 0.2 SOL
  - 300000000    # 0.3 SOL
  - 400000000    # 0.4 SOL
  - 500000000    # 0.5 SOL
  - 600000000    # 0.6 SOL
  - 700000000    # 0.7 SOL
#发送交易类型，建议选择Mixed，可选Rpc,Grpc,Mixed，选择Mixed可以让你的ip限制速率翻倍
rpc_type: Mixed
#blockhash rpc类型，建议选择Rpc，可选Grpc,Rpc，当前实现Grpc不是订阅的，等改成订阅的再选用Grpc
blockhash_rpc_type: Rpc

#是否开启block缓存，建议开启
blockhash_cache_enabled: true
#block缓存过期时间，单位ms，缓存1s没啥问题，降低下节点压力
blockhash_cache_ttl_ms: 1000
#性能相关，开启多少个线程,系统负载全靠这个控制
thread_count: 8
#每个线程里多少个网络IO，可以一个线程配2个左右，具体看性能，自行调试，作者也不知道多少是好的
max_concurrent: 4

#日志相关能力
log_rate_limit: false
#打印机会
log_opportunities: false
#打印交易执行
log_trade_execution: false
#是否开启单独钱包
enable_separate_wallet: true

#ip 配置信息，如果有多IP可以在这里配置，否则使用本机IP，建议配置上多IP，如果有请取消注释，并配置上
ip_addrs:
  - "xxxx"
#jup 调优
#是否只使用单跳，当前多跳还有待调整，建议现在只使用单跳
onlyDirectRoutes: true
#限制中间代币为顶级代币，建议开启，此参数也就是在多跳的时候有用，现在多跳没那么好使，先这样
restrict_intermediate_tokens: true
#是否预检交易大小，先暂时关闭，这个只对多跳有用，等待后续开发
check_transaction_size: false
#是否开启动态计算预算,建议开启
dynamic_compute_unit_limit: true
#计算预算百分比，设置这个值是因为，模拟后的cu可能偏大，可以设置百分比二次修改cu限制，近一步降低cu限制
cu_limit_percentage: 0.98
#计算预算，在开启动态预算的时候不生效
compute_unit_limit: 180000

```



## 监控和日志

- 暂无输出，你可以选择screen运行，或者使用tmux

## 常见问题

1. 如何设置合适的小费比例？
   - 建议根据市场情况调整，通常在 75% 左右，给太多了，你也没利润

2. 计算单元限制如何选择？
   - 建议开启动态计算单元限制
   - 固定限制推荐设置为 1,800,000

3. 如何选择 RPC 类型？
   - Mixed: 同时使用 RPC 和 gRPC
   - Rpc: 仅使用 RPC
   - Grpc: 仅使用 gRPC

## 相关链接
- [Discard](https://discord.gg/PkYsuNpj)
## 安全建议

- 使用独立的套利钱包
- 定期备份配置文件
- 不要在公共环境暴露私钥
- 谨慎设置交易参数

## 免责声明

本软件仅供学习研究使用。使用者需自行承担因使用本软件而产生的所有风险和责任。作者不对因使用本软件造成的任何损失负责。 
