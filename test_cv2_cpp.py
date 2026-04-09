import subprocess

def scan_qrcode_cmd(image_path):
    # 调用编译好的 C++ 程序
    result = subprocess.run(
        ["./release/wechat_scanner", image_path],
        capture_output=True,
        text=True
    )

    if result.returncode == 0:
        # 获取标准输出并按行分割（支持一张图多个二维码）
        codes = result.stdout.strip().split('\n')
        return [c for c in codes if c]
    return []

# 使用示例
print(scan_qrcode_cmd("/Users/yi/Downloads/c6733316-d9ab-4f1f-aebb-5eca61db643e_000002.jpg"))
