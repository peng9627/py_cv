#include <opencv2/opencv.hpp>
#include <opencv2/wechat_qrcode.hpp>
#include <iostream>
#include <filesystem> // 引入 C++17 文件系统库

// 为了代码简洁，使用命名空间
namespace fs = std::filesystem;

int main(int argc, char **argv) {
    if (argc < 2) {
        std::cerr << "Usage: " << argv[0] << " <image_path>" << std::endl;
        return -1;
    }

    // 1. 【关键修改】根据可执行文件路径，构造模型的绝对路径
    fs::path exe_path(argv[0]);
    fs::path exe_dir = exe_path.parent_path();
    fs::path model_dir = exe_dir / "models"; // 已修正为 "models"

    std::string detect_prototxt = (model_dir / "detect.prototxt").string();
    std::string detect_caffemodel = (model_dir / "detect.caffemodel").string();
    std::string sr_prototxt = (model_dir / "sr.prototxt").string();
    std::string sr_caffemodel = (model_dir / "sr.caffemodel").string();

    // 检查模型文件是否存在，如果不存在则报错退出，方便调试
    if (!fs::exists(detect_prototxt) || !fs::exists(detect_caffemodel) || !fs::exists(sr_prototxt) || !fs::exists(sr_caffemodel)) {
        std::cerr << "Error: Model files not found in " << model_dir << std::endl;
        std::cerr << "Searched for: " << std::endl;
        std::cerr << " - " << detect_prototxt << (fs::exists(detect_prototxt) ? " (found)" : " (not found)") << std::endl;
        std::cerr << " - " << detect_caffemodel << (fs::exists(detect_caffemodel) ? " (found)" : " (not found)") << std::endl;
        std::cerr << " - " << sr_prototxt << (fs::exists(sr_prototxt) ? " (found)" : " (not found)") << std::endl;
        std::cerr << " - " << sr_caffemodel << (fs::exists(sr_caffemodel) ? " (found)" : " (not found)") << std::endl;
        return -1;
    }

    // 2. 初始化 WeChatQRCode 检测器
    cv::Ptr<cv::wechat_qrcode::WeChatQRCode> detector;
    try {
        detector = cv::makePtr<cv::wechat_qrcode::WeChatQRCode>(
            detect_prototxt,
            detect_caffemodel,
            sr_prototxt,
            sr_caffemodel
        );
    } catch (const cv::Exception& e) {
        std::cerr << "Error initializing WeChatQRCode detector: " << e.what() << std::endl;
        return -1;
    }


    // 3. 读取图片
    cv::Mat img = cv::imread(argv[1], cv::IMREAD_COLOR | cv::IMREAD_IGNORE_ORIENTATION);
    if (img.empty()) {
        std::cerr << "Error: Could not read image at " << argv[1] << std::endl;
        return -1;
    }

    // 4. 识别
    std::vector<cv::Mat> points;
    auto res = detector->detectAndDecode(img, points);
    if (res.empty()) {
        // 如果初次识别失败，尝试放大图片后再次识别
        cv::Mat dst;
        cv::resize(img, dst, cv::Size(), 2.0, 2.0, cv::INTER_LINEAR);
        res = detector->detectAndDecode(dst, points);
    }

    // 5. 标准输出结果（供 Python 捕获）
    for (const auto &s: res) {
        std::cout << s << std::endl;
    }

    return 0;
}
