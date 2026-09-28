#!/bin/bash
# 在 macOS 虚拟机里双击/一条命令跑：编出「未签名 ipa」
# 用法：把这个文件放在 Flutter 工程根目录（和 pubspec.yaml 同一层），然后：
#   chmod +x build_ipa.sh && ./build_ipa.sh
set -e
cd "$(dirname "$0")"

echo "① 检查环境"
which flutter >/dev/null || { echo "没装 Flutter，先装 Flutter（macOS 版）"; exit 1; }
flutter --version | head -2

echo "② 拉依赖"
flutter pub get

echo "③ 编未签名 iOS 包（这一步要几分钟）"
flutter build ios --release --no-codesign

echo "④ 打包成 ipa（苹果的 ipa 就是个 zip，里面必须是 Payload/Runner.app）"
rm -rf build/ipa-tmp
mkdir -p build/ipa-tmp/Payload
cp -R build/ios/iphoneos/Runner.app build/ipa-tmp/Payload/
( cd build/ipa-tmp && zip -qry ../BaonaApp-unsigned.ipa Payload )

echo "⑤ 结果"
ls -lh build/BaonaApp-unsigned.ipa
echo ""
echo "搞定。把这个文件拖到 Windows 那边自签就行："
echo "  $(pwd)/build/BaonaApp-unsigned.ipa"
