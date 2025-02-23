# Solana MEV 套利机器人
基于 Rust 开发的高性能 Solana MEV 套利机器人，支持 Jupiter 聚合器和 Jito Bundle。
小白教程通道[小白教程](https://rust-mev-bot.solboxs.com/)
## 前言
- 当前利润怎么样？目前我demo钱包应该是6台机器，每天2-5sol左右，[每日利润，也得看行情](https://www.circular.bot/address/F1gnxS6Csq8pyApuogH2R6z5TqShwu3o7DMTm5WUphJ7)
- 由于用机器人换sol和wsol可能会换不成功，建议大家去jup换wsol[Jupiter链接](https://jup.ag/)，定期补充gas，gas不足会导致不出单
- 本人免责声明，请大家先小金额测试，测试没有问题了再大金额使用，代码逻辑里是不会导致大家资金损失，但是以防万一，营收自负
- 本人保证不会收集任何用户相关的信息，你可以选择用抓包软件等安全工具扫描，如果发现有收集信息，请立即停止使用，并联系作者
- 请妥善保管好自己的私钥，由于是开源软件，如果私钥泄露，请立即停止使用，并联系作者 邮箱：yscxyjd@gmail.com
- 此bot收费比例为你的净利润的10%，如果赚不到钱，请不要使用，请不要使用，请不要使用！
- 小费规则：(毛利润-GasFee-jito小费)*0.1
- 各位的支持与推广就是我的动力，作者会后续持续更新，并教大家如何赚取最大利润，当前观察钱包就是跑的下方的demo配置，大家可以自行修改调整
- [作者钱包监控地址](https://solscan.io/account/F1gnxS6Csq8pyApuogH2R6z5TqShwu3o7DMTm5WUphJ7)
- [小费收益](https://solscan.io/account/BUp6bo7x5UG3Xq8KSrnFwGbuzFJHsJcQ5vMnb9LwR7G4)
- [所有使用bot用户的每日盈利情况-Dune](https://dune.com/yscxy/rust-mev-bot-dashboard)
- [Discard](https://discord.gg/rCBZy4ZKZD)
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
- CPU 核心越高，频率越高越好，建议频率选择3.x以上，不要选择比较旧的cpu平台，可能某些编译后的指令，在旧的cpu上不支持，导致运行失败
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
wget https://sourceforge.net/projects/rust-mev-bot/files/rust-mev-bot-1.0.6.zip
```
解压
```bash
unzip rust-mev-bot-1.0.6.zip
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

## 详细教程
 [详细教程链接 ](https://rust-mev-bot.solboxs.com/)

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

## 安全建议

- 使用独立的套利钱包
- 定期备份配置文件
- 不要在公共环境暴露私钥
- 谨慎设置交易参数

## 免责声明

本软件仅供学习研究使用。使用者需自行承担因使用本软件而产生的所有风险和责任。作者不对因使用本软件造成的任何损失负责。 
