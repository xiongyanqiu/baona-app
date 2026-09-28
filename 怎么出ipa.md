# 包娜 App（Flutter 原生）· 怎么把 ipa 编出来

这个 App 全部是**原生 Flutter 代码**（不是网页套壳），界面照手机端网页做的，连你电脑端那套接口（9000）拿数据。

- 项目位置：`C:\Users\xilisi\AppData\Local\nvyou-desktop\ios-flutter`
- 代码：`lib\` 里 9 个文件（main 主界面 / chat 聊天 / shop 商城 / game 飞行棋 / sheets 设置·控制器·搜索 / us 我们·相册·记忆 / api 接口层 / theme 外观 / notify 通知）
- 已经配好的：`ios\Runner\Info.plist` 放行了局域网明文(http)、权限说明、锁竖屏、名字叫「包娜」

---

## 路线 A：GitHub 自动编（推荐，不用开虚拟机）

GitHub 免费送 macOS 机器，编出来的就是未签名 ipa。

1. 打开 https://github.com/new
   - Repository name 填 `baona-app`
   - 选 **Private**（私有）
   - 不要勾 Add a README
   - 点绿色按钮 **Create repository**
2. 打开 https://github.com/settings/tokens → **Generate new token (classic)**
   - Note 随便写 `baona`
   - Expiration 选 **No expiration**
   - 勾 **repo** 那一大项（勾了它会自动带上下面几条）
   - 拉到底点 **Generate token** → 把 `ghp_` 开头那串**复制下来**（只显示一次）
3. 把这两样给我（仓库地址 + token），我直接推上去并触发编译
4. 编好后我下载下来放到你电脑上，再出个二维码页面，手机扫码就能装

自己动手的话（不想给我 token）：
- 装 GitHub Desktop → File → Add local repository → 选 `ios-flutter` → Publish repository（勾 Private）
- 推上去后进仓库页面 → 上方 **Actions** → 左边点「编 ipa（未签名）」→ 右边 **Run workflow** → 绿色按钮
- 跑完（约 5~8 分钟）点进那次运行 → 页面最下面 **Artifacts** → 下载 `baona-ipa` → 解压得到 `BaonaApp-unsigned.ipa`

## 路线 B：macOS 虚拟机本地编（★已经做成一条命令）

代码**不用 GitHub、不用共享文件夹**了。电脑上有个「传文件小服务」，虚拟机直接从局域网里拿代码、编完再把 ipa 传回来。

**电脑这边（只做一次）**

1. 双击 `D:\baona-phone\vm-kit\开传文件服务.bat`
   - 第一次会弹防火墙窗口 → 点 **允许访问**
   - 窗口里会打印一行命令，长这样：`curl -s http://192.168.31.120:9333/go.sh | bash`
2. 这个黑窗口**别关**（关了虚拟机就拿不到东西了）

**虚拟机这边**

3. 打开「终端」，把上面那行命令原样粘进去回车

然后它自己干完这一串（会刷很多行，正常）：
装 Flutter（自动走清华镜像，快）→ 从你电脑拿代码 → `flutter pub get` → 编译（第一次 10~25 分钟）→ 打成 `BaonaApp-unsigned.ipa` → **自动传回你电脑**，落在
`D:\baona-phone\vm-kit\ipa\BaonaApp-unsigned.ipa`

**唯一要你提前备好的两个东西**（脚本会检查，缺了会明确告诉你敲哪条命令）：

- **Xcode**：App Store 搜 Xcode 装（十几 G），装完在终端敲 `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`
- **CocoaPods**：`brew install cocoapods`（要先装 Homebrew：https://brew.sh/zh-cn/）

> 注意：`--no-codesign` 编出来的是 `Runner.app`，**不是 ipa**。苹果的 ipa 其实就是一个 zip，里面必须叫 `Payload/Runner.app`。脚本已经替你把这一步做了。

**想让我全程替你干**：macOS 装好后开一下 SSH —— 系统设置 → 通用 → 共享 → 打开「远程登录」，然后把它下面显示的那串地址（`ssh 用户名@192.168.x.x`）发我。之后装 Flutter、拿代码、编包、把 ipa 取回电脑全是我来，你只等结果。（虚拟机里那个图形界面我点不到——我没有鼠标，但只要能 SSH 进去就够了。）


## 后台通知（已做，自签也能弹）

自签 App 没有 APNs 推送权限，所以走了另一条路：**本地通知 + 后台音频保活**。

- App 退到后台时循环播一段 1 秒的「静音」，iOS 就不会冻住它 → 和电脑端的长连接还活着
- 她的消息一到，手机就弹一条通知（带声音、带红点角标），点一下进 App
- 通知里只有她的话（工具标记、「看桌上」这类指令会被洗掉，不会弹到你眼前）
- 设置抽屉里有开关：「通知（她发消息弹出来）」
- 代价：后台常驻会多耗一点电；你要是想省电，把 App 从后台划掉就不弹了（回到 App 再补）

## 装到手机（自签）

- App 里不带任何证书/描述文件（纯裸包），签名全在你手机端的工具里做。
- 免费证书 7 天掉签，掉了重新签一次就行（App 里的登录状态/设置都在本地存着，重签不会丢）。
- App 第一次打开：
  1. 「电脑端地址」填 `http://192.168.31.120:9000`（在家里）；在外面填蒲公英那个 `http://172.16.3.209:9000`
  2. 点「测试连接」看通不通
  3. 下一步填手机端口令，进去
- 电脑端的桌宠必须开着，手机和电脑在同一个 Wi-Fi。

## 已知限制（硬件/系统限制，不是没做）

- **掉签**：免费证书 7 天掉一次，掉了用手机端工具重签（App 里的登录状态/设置存本地，重签不丢）。不做自动更新。
- **相册密码**、商城买东西、飞行棋、控制器这些都走电脑端同一套接口，跟网页版同一个数据。
