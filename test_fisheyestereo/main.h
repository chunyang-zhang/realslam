#pragma once

#include <opencv2/opencv.hpp>
#include <stereotgv/stereotgv.h>

#if _WIN64
#define LIB_PATH "D:/dev/lib64/"
#define CV_LIB_PATH "D:/dev/lib64/"
#else
#define LIB_PATH "D:/dev/staticlib32/"
#endif

#ifdef _DEBUG
#define LIB_EXT "d.lib"
#else
#define LIB_EXT ".lib"
#endif

#define CUDA_LIB_PATH "C:/Program Files/NVIDIA GPU Computing Toolkit/CUDA/v10.1/lib/x64/"
#pragma comment(lib, CUDA_LIB_PATH "cudart.lib")

#define CV_VER_NUM CVAUX_STR(CV_MAJOR_VERSION) CVAUX_STR(CV_MINOR_VERSION) CVAUX_STR(CV_SUBMINOR_VERSION)
#pragma comment(lib, LIB_PATH "opencv_core" CV_VER_NUM LIB_EXT)
#pragma comment(lib, LIB_PATH "opencv_highgui" CV_VER_NUM LIB_EXT)
#pragma comment(lib, LIB_PATH "opencv_videoio" CV_VER_NUM LIB_EXT)
#pragma comment(lib, LIB_PATH "opencv_imgproc" CV_VER_NUM LIB_EXT)
#pragma comment(lib, LIB_PATH "opencv_calib3d" CV_VER_NUM LIB_EXT)
#pragma comment(lib, LIB_PATH "opencv_xfeatures2d" CV_VER_NUM LIB_EXT)
#pragma comment(lib, LIB_PATH "opencv_optflow" CV_VER_NUM LIB_EXT)
#pragma comment(lib, LIB_PATH "opencv_imgcodecs" CV_VER_NUM LIB_EXT)
#pragma comment(lib, LIB_PATH "opencv_features2d" CV_VER_NUM LIB_EXT)
#pragma comment(lib, LIB_PATH "opencv_tracking" CV_VER_NUM LIB_EXT)
#pragma comment(lib, LIB_PATH "opencv_flann" CV_VER_NUM LIB_EXT)
#pragma comment(lib, LIB_PATH "opencv_cudafeatures2d" CV_VER_NUM LIB_EXT)
#pragma comment(lib, LIB_PATH "opencv_cudaimgproc" CV_VER_NUM LIB_EXT)
#pragma comment(lib, LIB_PATH "opencv_video" CV_VER_NUM LIB_EXT)

int test_FaroData();
int test_BlenderData();
int test_IcraAddedAccuratePixels();
void showDepthJet(std::string windowName, cv::Mat image, float maxDepth, bool shouldWait);
void saveDepthJet(std::string fileName, cv::Mat image, float maxDepth);
int test_TwoImagesRealsense();